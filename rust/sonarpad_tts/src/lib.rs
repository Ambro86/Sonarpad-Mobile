use chrono::Local;
use futures_util::{SinkExt, StreamExt};
use rand::Rng;
use sha2::{Digest, Sha256};
use std::ffi::{CStr, CString};
use std::fs;
use std::panic;
use std::sync::Once;
use std::os::raw::c_char;
use std::time::Duration;
use tokio_tungstenite::{
    connect_async,
    tungstenite::client::IntoClientRequest,
    tungstenite::http::HeaderValue,
    tungstenite::protocol::Message,
};
use url::Url;
use uuid::Uuid;

const TRUSTED_CLIENT_TOKEN: &str = "6A5AA1D4EAFF4E9FB37E23D68491D6F4";
const WSS_URL_BASE: &str = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1";

static RUSTLS_PROVIDER_INIT: Once = Once::new();

fn install_rustls_crypto_provider() {
    RUSTLS_PROVIDER_INIT.call_once(|| {
        let _ = rustls::crypto::ring::default_provider().install_default();
    });
}

#[no_mangle]
pub extern "C" fn sonarpad_edge_tts_to_file(
    text: *const c_char,
    voice: *const c_char,
    output_path: *const c_char,
) -> *mut c_char {
    let result = panic::catch_unwind(|| {
        install_rustls_crypto_provider();
        let text = cstr_to_string(text)?;
        let voice = cstr_to_string(voice)?;
        let output_path = cstr_to_string(output_path)?;
        debug_log(&output_path, &format!("start voice={voice} text_len={}", text.chars().count()));

        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(|e| format!("creazione runtime Tokio fallita: {e}"))?;

        let audio = rt.block_on(download_audio(&text, &voice, &output_path))?;
        debug_log(&output_path, &format!("audio_bytes={}", audio.len()));
        if audio.is_empty() {
            return Err("Edge TTS ha restituito audio vuoto".to_string());
        }
        fs::write(&output_path, audio).map_err(|e| format!("scrittura file audio fallita: {e}"))?;
        Ok::<String, String>(format!("ok:{output_path}"))
    });

    match result {
        Ok(Ok(ok)) => string_to_ptr(ok),
        Ok(Err(err)) => string_to_ptr(format!("error:{err}")),
        Err(payload) => {
            let msg = if let Some(s) = payload.downcast_ref::<&str>() {
                (*s).to_string()
            } else if let Some(s) = payload.downcast_ref::<String>() {
                s.clone()
            } else {
                "panic Rust sconosciuto".to_string()
            };
            string_to_ptr(format!("error:panic Rust Edge TTS: {msg}"))
        }
    }
}

#[no_mangle]
pub extern "C" fn sonarpad_string_free(value: *mut c_char) {
    if value.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(value);
    }
}

fn cstr_to_string(ptr: *const c_char) -> Result<String, String> {
    if ptr.is_null() {
        return Err("puntatore nullo".to_string());
    }
    unsafe { CStr::from_ptr(ptr) }
        .to_str()
        .map(|s| s.to_string())
        .map_err(|e| e.to_string())
}

fn string_to_ptr(value: String) -> *mut c_char {
    CString::new(value).unwrap_or_else(|_| CString::new("error:stringa non valida").unwrap()).into_raw()
}

async fn download_audio(text: &str, voice: &str, output_path: &str) -> Result<Vec<u8>, String> {
    let request_id = Uuid::new_v4().simple().to_string();
    let sec_ms_gec = generate_sec_ms_gec();
    let sec_ms_gec_version = "1-132.0.2917.39";
    let url_str = format!(
        "{}?TrustedClientToken={}&ConnectionId={}&Sec-MS-GEC={}&Sec-MS-GEC-Version={}",
        WSS_URL_BASE, TRUSTED_CLIENT_TOKEN, request_id, sec_ms_gec, sec_ms_gec_version
    );
    debug_log(output_path, "preparo URL websocket Edge TTS");
    let url = Url::parse(&url_str).map_err(|e| format!("URL websocket non valido: {e}"))?;
    let mut request = url.as_str().into_client_request().map_err(|e| e.to_string())?;
    let headers = request.headers_mut();
    headers.insert("Pragma", HeaderValue::from_static("no-cache"));
    headers.insert("Cache-Control", HeaderValue::from_static("no-cache"));
    headers.insert("Origin", HeaderValue::from_static("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold"));
    headers.insert("User-Agent", HeaderValue::from_static("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1 Edg/132.0.0.0"));
    headers.insert("Accept-Language", HeaderValue::from_static("it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7"));
    let cookie = format!("muid={};", generate_muid());
    headers.insert("Cookie", HeaderValue::from_str(&cookie).map_err(|e| e.to_string())?);

    debug_log(output_path, "connessione websocket...");
    let (ws_stream, _) = tokio::time::timeout(Duration::from_secs(20), connect_async(request))
        .await
        .map_err(|_| "WebSocket connect timeout".to_string())?
        .map_err(|e| format!("connessione websocket fallita: {e}"))?;
    debug_log(output_path, "websocket connesso");
    let (mut write, mut read) = ws_stream.split();

    let config_msg = format!(
        "X-Timestamp:{}\r\nContent-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{{\"context\":{{\"synthesis\":{{\"audio\":{{\"metadataoptions\":{{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"}},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}}}}}",
        get_date_string()
    );
    write.send(Message::Text(config_msg.into())).await.map_err(|e| format!("invio speech.config fallito: {e}"))?;
    debug_log(output_path, "speech.config inviato");

    let ssml = mkssml(text, voice);
    let ssml_msg = format!(
        "X-RequestId:{}\r\nContent-Type:application/ssml+xml\r\nX-Timestamp:{}Z\r\nPath:ssml\r\n\r\n{}",
        request_id,
        get_date_string(),
        ssml
    );
    write.send(Message::Text(ssml_msg.into())).await.map_err(|e| format!("invio SSML fallito: {e}"))?;
    debug_log(output_path, "SSML inviato");

    let mut audio_data = Vec::new();
    while let Some(msg) = read.next().await {
        let msg = msg.map_err(|e| format!("lettura messaggio websocket fallita: {e}"))?;
        match msg {
            Message::Text(text) if text.contains("Path:turn.end") => break,
            Message::Binary(data) => {
                if let Some(audio) = parse_edge_binary_audio_payload(&data)? {
                    audio_data.extend_from_slice(&audio);
                }
            }
            Message::Close(_) => break,
            _ => {}
        }
    }
    debug_log(output_path, &format!("fine ricezione: {} bytes", audio_data.len()));
    Ok(audio_data)
}

fn debug_log(output_path: &str, line: &str) {
    let log_path = format!("{output_path}.log.txt");
    let _ = fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_path)
        .and_then(|mut f| {
            use std::io::Write;
            writeln!(f, "{} | {}", Local::now().format("%Y-%m-%d %H:%M:%S"), line)
        });
}

fn generate_sec_ms_gec() -> String {
    let win_epoch = 11644473600i64;
    let ticks = Local::now().timestamp() + win_epoch;
    let ticks = (ticks - (ticks % 300)) * 10_000_000;
    let str_to_hash = format!("{}{}", ticks, TRUSTED_CLIENT_TOKEN);
    let mut hasher = Sha256::new();
    hasher.update(str_to_hash);
    hex::encode(hasher.finalize()).to_uppercase()
}

fn generate_muid() -> String {
    let mut rng = rand::thread_rng();
    let mut bytes = [0u8; 16];
    rng.fill(&mut bytes);
    hex::encode(bytes).to_uppercase()
}

fn get_date_string() -> String {
    Local::now().format("%a %b %d %Y %H:%M:%S GMT+0000 (Coordinated Universal Time)").to_string()
}

fn mkssml(text: &str, voice: &str) -> String {
    let lang_parts: Vec<&str> = voice.split('-').collect();
    let lang = if lang_parts.len() >= 2 { format!("{}-{}", lang_parts[0], lang_parts[1]) } else { "it-IT".to_string() };
    let text = escape_xml(&sanitize_text(text));
    format!(
        "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='{lang}'><voice name='{voice}'><prosody pitch='+0Hz' rate='+0%' volume='+0%'>{text}</prosody></voice></speak>"
    )
}

fn sanitize_text(text: &str) -> String {
    text.chars()
        .map(|ch| if ch.is_control() { ' ' } else { ch })
        .collect::<String>()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

fn escape_xml(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}

fn parse_edge_binary_audio_payload(data: &[u8]) -> Result<Option<Vec<u8>>, String> {
    if data.len() < 2 {
        return Err("Edge WS: binary frame senza lunghezza header".to_string());
    }
    let be_len = u16::from_be_bytes([data[0], data[1]]) as usize;
    let le_len = u16::from_le_bytes([data[0], data[1]]) as usize;
    let header_len = if be_len > 0 && data.len() >= be_len + 2 {
        be_len
    } else if le_len > 0 && data.len() >= le_len + 2 {
        le_len
    } else {
        return Err("Edge WS: lunghezza header non valida".to_string());
    };
    let header_text = String::from_utf8_lossy(&data[2..2 + header_len]);
    let payload = &data[2 + header_len..];
    let is_audio = header_text.lines().any(|line| line.trim().eq_ignore_ascii_case("Path:audio"));
    if !is_audio {
        return Ok(None);
    }
    if payload.is_empty() {
        return Ok(None);
    }
    Ok(Some(payload.to_vec()))
}
