package com.example.sonarpad_mobile_starter

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.media3.common.*
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.*
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

/** Android-only Rai bridge. No proprietary Rai code or tokens are embedded. */
@UnstableApi
class RaiAndroidPlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var context: Context
    private lateinit var commands: MethodChannel
    private lateinit var events: EventChannel
    private var sink: EventChannel.EventSink? = null
    private var player: ExoPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var surface: PlayerView? = null
    private val surfaces = mutableListOf<PlayerView>()
    private var preferAD = true
    private var videoEnabled = false
    private var selecting = false
    private var bufferingSince = 0L
    private var stallReported = false
    private val position = object : Runnable {
        override fun run() {
            val current = player ?: return
            emit("position", mapOf("positionMs" to current.currentPosition.coerceAtLeast(0),
                "durationMs" to current.duration.coerceAtLeast(0)))
            if (current.playWhenReady && current.playbackState == Player.STATE_BUFFERING) {
                if (bufferingSince == 0L) bufferingSince = android.os.SystemClock.elapsedRealtime()
                if (!stallReported && android.os.SystemClock.elapsedRealtime() - bufferingSince >= 12000) {
                    stallReported = true
                    emit("stalled", emptyMap())
                }
            } else { bufferingSince = 0; stallReported = false }
            handler.postDelayed(this, 1000)
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        commands = MethodChannel(binding.binaryMessenger, "sonarpad/rai_player")
        events = EventChannel(binding.binaryMessenger, "sonarpad/rai_player_events")
        commands.setMethodCallHandler(this)
        events.setStreamHandler(this)
        binding.platformViewRegistry.registerViewFactory("sonarpad/rai_android_player_view",
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                    val view = PlayerView(context).apply {
                        useController = false
                        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
                    }
                    surface?.player = null
                    surfaces.add(view)
                    surface = view
                    view.player = player
                    return object : PlatformView {
                        override fun getView(): View = view
                        override fun dispose() {
                            view.player = null
                            surfaces.remove(view)
                            if (surface === view) {
                                surface = surfaces.lastOrNull()
                                surface?.player = player
                            }
                        }
                    }
                }
            })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        release()
        commands.setMethodCallHandler(null)
        events.setStreamHandler(null)
        sink = null
        surface = null
        surfaces.clear()
    }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "open" -> open(call)
                "play" -> player?.play()
                "pause" -> player?.pause()
                "stop", "dispose" -> release()
                "setVolume" -> player?.volume = (call.arguments as Number).toFloat().coerceIn(0f, 1f)
                "setVideoEnabled" -> { videoEnabled = call.arguments == true; selectTracks() }
                "setPreferAudioDescription" -> { preferAD = call.arguments == true; selectTracks() }
                else -> { result.notImplemented(); return }
            }
            result.success(null)
        } catch (error: Exception) {
            if (call.method == "open") release()
            // Do not leak signed URLs or request headers in errors.
            result.error("rai_android_player", error.javaClass.simpleName, null)
        }
    }

    private fun open(call: MethodCall) {
        val url = requireNotNull(call.argument<String>("url"))
        val scheme = android.net.Uri.parse(url).scheme
        require(scheme == "https" || scheme == "http")
        release()
        preferAD = call.argument<Boolean>("preferAudioDescription") ?: true
        videoEnabled = call.argument<Boolean>("videoEnabled") ?: false
        val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
        // One HTTP session handles the master, variants, keys and segments.
        val client = OkHttpClient.Builder().cookieJar(RaiCookieJar())
            .connectTimeout(15, TimeUnit.SECONDS).readTimeout(20, TimeUnit.SECONDS)
            .followRedirects(true).build()
        val dataSource = OkHttpDataSource.Factory(client).setDefaultRequestProperties(headers)
        val created = ExoPlayer.Builder(context)
            .setMediaSourceFactory(DefaultMediaSourceFactory(dataSource)).build()
        player = created
        // Audio focus and CPU lifetime belong to the existing foreground service.
        created.setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(), false)
        created.volume = (call.argument<Number>("volume")?.toFloat() ?: 1f).coerceIn(0f, 1f)
        created.addListener(object : Player.Listener {
            override fun onEvents(source: Player, changed: Player.Events) {
                if (player !== created) return
                emit("state", mapOf("playing" to source.isPlaying,
                    "buffering" to (source.playbackState == Player.STATE_BUFFERING),
                    "positionMs" to source.currentPosition.coerceAtLeast(0),
                    "durationMs" to source.duration.coerceAtLeast(0), "reason" to "media3"))
            }
            override fun onTracksChanged(tracks: Tracks) { if (player === created) selectTracks() }
            override fun onPlayerError(error: PlaybackException) {
                if (player !== created) return
                var cause: Throwable? = error
                var status: Int? = null
                while (cause != null) {
                    if (cause is androidx.media3.datasource.HttpDataSource.InvalidResponseCodeException) status = cause.responseCode
                    cause = cause.cause
                }
                emit("error", mapOf("domain" to "Media3", "code" to error.errorCode,
                    "message" to (error.errorCodeName + (status?.let { " HTTP $it" } ?: ""))))
            }
        })
        selectTracks()
        surface?.player = created
        created.setMediaItem(MediaItem.fromUri(url))
        created.prepare()
        created.play()
        handler.post(position)
    }

    private fun selectTracks() {
        val current = player ?: return
        if (selecting) return
        selecting = true
        try {
            val builder = current.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_VIDEO, !videoEnabled)
                .setPreferredAudioLanguages("it", "ita")
                .setPreferredAudioRoleFlags(if (preferAD) C.ROLE_FLAG_DESCRIBES_VIDEO else 0)
                .clearOverridesOfType(C.TRACK_TYPE_AUDIO)
            var best: Pair<Tracks.Group, Int>? = null
            var score = Int.MIN_VALUE
            val descriptions = mutableListOf<Map<String, Any>>()
            for (group in current.currentTracks.groups) {
                if (group.type != C.TRACK_TYPE_AUDIO) continue
                for (index in 0 until group.length) {
                    if (!group.isTrackSupported(index)) continue
                    val format = group.getTrackFormat(index)
                    val language = format.language.orEmpty().lowercase()
                    val label = format.label.orEmpty()
                    val ad = RaiTrackPolicy.isDescription(language, label, format.roleFlags and C.ROLE_FLAG_DESCRIBES_VIDEO != 0)
                    val rank = RaiTrackPolicy.score(language, ad, preferAD)
                    descriptions.add(mapOf("name" to label, "locale" to language, "isAudioDescription" to ad))
                    if (rank > score) { score = rank; best = Pair(group, index) }
                }
            }
            best?.let { (group, index) -> builder.setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, index)) }
            val parameters = builder.build()
            if (parameters != current.trackSelectionParameters) current.trackSelectionParameters = parameters
            best?.let { (group, index) ->
                val format = group.getTrackFormat(index)
                emit("audio_tracks", mapOf("preferAudioDescription" to preferAD,
                    "selected" to format.label.orEmpty(), "selectedLocale" to format.language.orEmpty(),
                    "selectedIsAudioDescription" to RaiTrackPolicy.isDescription(format.language.orEmpty(), format.label.orEmpty(),
                        format.roleFlags and C.ROLE_FLAG_DESCRIBES_VIDEO != 0), "tracks" to descriptions))
            }
        } finally { selecting = false }
    }
    private fun emit(type: String, values: Map<String, Any?>) { sink?.success(values + ("type" to type)) }
    private fun release() {
        handler.removeCallbacks(position)
        val previous = player
        player = null
        surface?.player = null
        previous?.release()
        bufferingSince = 0
        stallReported = false
    }
}

internal object RaiTrackPolicy {
    fun isDescription(language: String, label: String, role: Boolean): Boolean =
        role || language.equals("des", true) || label.lowercase().contains("audiodescri")
    fun score(language: String, description: Boolean, preferDescription: Boolean): Int {
        val italian = language.lowercase().let { it == "ita" || it == "it" || it.startsWith("it-") }
        return (if (description == preferDescription) 100 else 0) + (if (italian) 10 else 0)
    }
}

/** Session-scoped cookies, matched by origin/path using OkHttp's cookie rules. */
internal class RaiCookieJar : CookieJar {
    private val cookies = mutableListOf<Cookie>()
    @Synchronized override fun saveFromResponse(url: HttpUrl, incoming: List<Cookie>) {
        for (cookie in incoming) {
            cookies.removeAll { it.name == cookie.name && it.domain == cookie.domain && it.path == cookie.path }
            cookies.add(cookie)
        }
    }
    @Synchronized override fun loadForRequest(url: HttpUrl): List<Cookie> {
        cookies.removeAll { it.expiresAt <= System.currentTimeMillis() }
        return cookies.filter { it.matches(url) }
    }
}
