import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/news_article.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';
import '../services/news_service.dart';
import '../services/document_library_service.dart';
import '../services/html_reader_service.dart';
import '../services/voice_dictionary_service.dart';
import '../tts/edge_tts_bridge.dart';
import '../utils/app_logger.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/status_message.dart';

class NewsWebViewScreen extends StatefulWidget {
  const NewsWebViewScreen(
      {super.key,
      required this.article,
      required this.language,
      this.readSourceName});

  final NewsArticle article;
  final NewsLanguage language;
  final String? readSourceName;

  @override
  State<NewsWebViewScreen> createState() => _NewsWebViewScreenState();
}

class _NewsWebViewScreenState extends State<NewsWebViewScreen> {
  late final WebViewController _controller;
  final _audio = AudioPlayerService();
  final _settings = AppSettingsService();
  final _newsService = NewsService();
  final _tts = EdgeTtsBridge();
  final _flutterTts = FlutterTts();
  final _voiceDictionary = VoiceDictionaryService();

  bool _loading = true;
  String? _readerTitle;
  String? _readerText;
  // lunghezza testo HTTP; il WebView puo migliorarlo se < _httpShortThreshold
  int _readerHttpTextLength = 0;
  bool _readerPreparing = true;
  bool _speaking = false;
  bool _ttsPaused = false;
  int _readingToken = 0;
  StreamController<File>? _edgeFileController;
  String? _status;
  String? _resolvedArticleUrlForReader;
  String? _lastFinalReaderFetchUrl;

  // Soglia minima per accettare il testo HTTP come reader mode
  static const _httpMinLength = 150;
  // Soglia sotto la quale il WebView puo ancora sostituire il testo HTTP
  static const _httpShortThreshold = 600;

  static const _ttsCommands = MethodChannel('sonarpad/tts_commands');
  static const _ttsEvents = EventChannel('sonarpad/tts_events');
  StreamSubscription? _ttsEventsSub;

  Future<void> _togglePlayPause() async {
    if (!_speaking) return;
    if (_ttsPaused) {
      if (mounted) setState(() => _ttsPaused = false);
      unawaited(_flutterTts.speak('').catchError((_) => null));
      await _audio.play();
    } else {
      if (mounted) setState(() => _ttsPaused = true);
      await _flutterTts.pause();
      await _audio.pause();
    }
  }

  Future<void> _saveArticle() async {
    if (_readerText == null) return;
    try {
      final safeName =
          widget.article.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final titleSafe = '$safeName.txt';
      final service = DocumentLibraryService();
      await service.load();
      final content = '${widget.article.title}\n\n$_readerText';
      final doc = await service.createTextDocument(
        name: titleSafe,
        content: content,
      );
      await service.add(doc);

      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context).articleSavedSuccess),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving article: $e');
    }
  }

  Future<void> _shareArticle() async {
    try {
      // ignore: deprecated_member_use
      await Share.share(widget.article.link, subject: widget.article.title);
    } catch (e) {
      debugPrint('Error sharing article: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(AppLogger.log(
      'News: apertura articolo title="${widget.article.title}" '
      'url=${widget.article.link}',
    ));
    unawaited(_newsService.addReadArticle(
      widget.language,
      widget.readSourceName ?? widget.article.source,
      widget.article,
    ));
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            unawaited(AppLogger.log('News WebView: caricamento avviato url=$url'));
            if (_isHttpArticleUrl(url) && !_isGoogleNewsUrl(url)) {
              unawaited(_loadReaderArticleFromFinalUrl(url));
            }
            if (mounted) {
              setState(() {
                _loading = true;
              });
            }
          },
          onPageFinished: (url) {
            unawaited(AppLogger.log('News WebView: caricamento completato url=$url'));
            if (mounted) setState(() => _loading = false);
            unawaited(_acceptCookieConsentIfPresent());
            unawaited(_loadReaderArticleFromFinalUrl(url));
            unawaited(_neutralizeEmbeddedSiteMedia(url));
            unawaited(_loadVisibleReaderArticleFromWebView());
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_shouldBlockEmbeddedMediaNavigation(request.url)) {
              unawaited(AppLogger.log(
                'News WebView: navigazione bloccata per contenuto media '
                'url=${request.url}',
              ));
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            unawaited(AppLogger.log(
              'News WebView: errore caricamento '
              'code=${error.errorCode} description="${error.description}"',
            ));
            if (mounted) {
              setState(() {
                _loading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.article.link));
    unawaited(_loadReaderArticle());

    _ttsEventsSub = _ttsEvents.receiveBroadcastStream().listen((event) {
      if (event == 'toggle' && mounted) {
        _togglePlayPause();
      }
    });
    _flutterTts.setPauseHandler(() {
      if (mounted && _speaking) setState(() => _ttsPaused = true);
    });
    _flutterTts.setContinueHandler(() {
      if (mounted && _speaking) setState(() => _ttsPaused = false);
    });
  }

  Future<void> _acceptCookieConsentIfPresent() async {
    Future<bool> run() async {
      final result = await _controller.runJavaScriptReturningResult(r'''
        (function () {
          var acceptTexts = [
            'accetta tutto',
            'accetta',
            'accetto',
            'acconsento',
            'consenti tutto',
            'consenti',
            'accept all',
            'accept',
            'agree',
            'i agree',
            'allow all',
            'allow',
            'accepter',
            "j'accepte",
            'tout accepter',
            'accepter tout',
            'autoriser',
            'autoriser tout',
            'aceptar',
            'aceptar todo',
            'acepto',
            'estoy de acuerdo',
            'permitir',
            'permitir todo'
          ];
          var rejectTexts = [
            'rifiuta',
            'gestisci',
            'opzioni',
            'reject',
            'decline',
            'manage',
            'preferences',
            'options',
            'refuser',
            'refuser tout',
            'gérer',
            'préférences',
            'parametres',
            'paramètres',
            'rechazar',
            'rechazar todo',
            'gestionar',
            'opciones'
          ];

          function normalizedText(element) {
            return ((element.innerText || element.textContent || element.value || element.getAttribute('aria-label') || '')
              .toLowerCase()
              .replace(/\s+/g, ' ')
              .trim());
          }

          function isVisible(element) {
            var style = window.getComputedStyle(element);
            var rect = element.getBoundingClientRect();
            return style.display !== 'none' &&
              style.visibility !== 'hidden' &&
              rect.width > 0 &&
              rect.height > 0;
          }

          function shouldClick(text) {
            if (!text) return false;
            for (var i = 0; i < rejectTexts.length; i++) {
              if (text.indexOf(rejectTexts[i]) !== -1) return false;
            }
            for (var j = 0; j < acceptTexts.length; j++) {
              if (text === acceptTexts[j] || text.indexOf(acceptTexts[j]) !== -1) return true;
            }
            return false;
          }

          var selectors = [
            'button',
            'input[type="button"]',
            'input[type="submit"]',
            '[role="button"]',
            'a'
          ];
          var elements = document.querySelectorAll(selectors.join(','));
          for (var k = 0; k < elements.length; k++) {
            var element = elements[k];
            if (!isVisible(element)) continue;
            var text = normalizedText(element);
            if (!shouldClick(text)) continue;
            element.click();
            return true;
          }
          return false;
        })();
      ''');
      return result == true || result.toString() == 'true';
    }

    try {
      final firstClicked = await run();
      unawaited(AppLogger.log(
        'News cookie: primo tentativo consenso clicked=$firstClicked',
      ));
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      final secondClicked = await run();
      unawaited(AppLogger.log(
        'News cookie: secondo tentativo consenso clicked=$secondClicked',
      ));
    } catch (e) {
      unawaited(AppLogger.log('News cookie: gestione consenso fallita: $e'));
    }
  }

  Future<void> _neutralizeEmbeddedSiteMedia(String pageUrl) async {
    // Protezione mirata per la WebView dei siti di notizie: il lettore di
    // Sonarpad resta quello dell'app, mentre player audio/video del sito
    // vengono fermati o nascosti per non interferire con VoiceOver e iOS.
    for (final delay in const [0, 800, 2000, 4000]) {
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
        if (!mounted) return;
      }
      try {
        final encodedPageUrl = jsonEncode(pageUrl);
        await _controller.runJavaScript('''
          (function () {
            var pageUrl = $encodedPageUrl.toLowerCase();
            var isTorinoCronaca = pageUrl.indexOf('torinocronaca.it') !== -1;
            var removed = 0;

            function textOf(el) {
              return String(
                (el.innerText || el.textContent || el.value ||
                 el.getAttribute('aria-label') || el.getAttribute('title') || '')
              ).toLowerCase().replace(/\\s+/g, ' ').trim();
            }

            function attrText(el) {
              var values = [
                el.id || '',
                el.className || '',
                el.getAttribute('href') || '',
                el.getAttribute('src') || '',
                el.getAttribute('data-src') || '',
                el.getAttribute('data-url') || '',
                el.getAttribute('aria-label') || '',
                el.getAttribute('title') || ''
              ];
              return values.join(' ').toLowerCase();
            }

            function hide(el) {
              if (!el || !el.parentNode) return;
              try {
                if (typeof el.pause === 'function') el.pause();
                if (el.removeAttribute) {
                  el.removeAttribute('src');
                  el.removeAttribute('autoplay');
                  el.removeAttribute('controls');
                }
                if (typeof el.load === 'function') el.load();
              } catch (e) {}
              try {
                el.setAttribute('aria-hidden', 'true');
                el.style.display = 'none';
                el.remove();
                removed += 1;
              } catch (e) {}
            }

            var media = document.querySelectorAll('audio, video, source, track');
            for (var i = 0; i < media.length; i++) hide(media[i]);

            var embedded = document.querySelectorAll('iframe, embed, object');
            for (var j = 0; j < embedded.length; j++) {
              var blob = attrText(embedded[j]);
              if (blob.indexOf('player') !== -1 ||
                  blob.indexOf('audio') !== -1 ||
                  blob.indexOf('video') !== -1 ||
                  blob.indexOf('youtube') !== -1 ||
                  blob.indexOf('dailymotion') !== -1 ||
                  blob.indexOf('jwplayer') !== -1 ||
                  blob.indexOf('soundcloud') !== -1 ||
                  blob.indexOf('spotify') !== -1) {
                hide(embedded[j]);
              }
            }

            // Torino Cronaca inserisce un proprio pulsante "Ascolta l'articolo"
            // che apre un player del sito/iOS. Lo togliamo solo lì, senza toccare
            // i pulsanti Flutter di Sonarpad.
            if (isTorinoCronaca) {
              var candidates = document.querySelectorAll(
                'button, a, [role="button"], div, section, aside'
              );
              for (var k = 0; k < candidates.length; k++) {
                var el = candidates[k];
                var text = textOf(el);
                var attrs = attrText(el);
                var looksLikeListen =
                  text.indexOf('ascolta') !== -1 ||
                  text.indexOf('leggi articolo') !== -1 ||
                  text.indexOf("leggi l'articolo") !== -1 ||
                  attrs.indexOf('ascolta') !== -1 ||
                  attrs.indexOf('listen') !== -1 ||
                  attrs.indexOf('audio') !== -1 ||
                  attrs.indexOf('player') !== -1 ||
                  attrs.indexOf('podcast') !== -1;
                if (looksLikeListen) hide(el);
              }
            }

            return removed;
          })();
        ''');
      } catch (e) {
        unawaited(AppLogger.log(
          'News WebView: rimozione contenuti media fallita: $e',
        ));
      }
    }
  }

  bool _shouldBlockEmbeddedMediaNavigation(String requestUrl) {
    final url = requestUrl.toLowerCase();
    if (url.contains('multiplayer.it')) return false;
    final mediaFragments = [
      'player',
      '/audio',
      'audio=',
      'listen',
      'ascolta',
      'podcast',
      'jwplayer',
      'soundcloud',
      'spotify',
      'youtube.com/embed',
      'dailymotion.com/embed',
      'mediaset.it/player',
    ];
    if (mediaFragments.any(url.contains)) return true;
    return RegExp(r'\.(mp3|m4a|aac|wav|ogg|m3u8|mpd)(\?|$)').hasMatch(url);
  }

  @override
  void dispose() {
    _readingToken += 1;
    final edgeController = _edgeFileController;
    _edgeFileController = null;
    if (edgeController != null && !edgeController.isClosed) {
      unawaited(edgeController.close());
    }
    if (Platform.isIOS) {
      _ttsCommands.invokeMethod('clearMagicTap').catchError((_) {});
    }
    _ttsEventsSub?.cancel();
    _audio.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<String> _voice() async {
    final configured = await _settings.loadTtsVoice();
    if (configured.trim().isNotEmpty) return configured;
    return 'it-IT-IsabellaNeural';
  }

  bool _isGoogleNewsUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    return uri.host.toLowerCase() == 'news.google.com';
  }

  bool _isHttpArticleUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
  }

  bool _sameNormalizedUrl(String a, String b) {
    final au = Uri.tryParse(a.trim());
    final bu = Uri.tryParse(b.trim());
    if (au == null || bu == null) return a.trim() == b.trim();
    return au.removeFragment().toString() == bu.removeFragment().toString();
  }

  NewsArticle _articleForReaderUrl(String url) {
    return NewsArticle(
      id: widget.article.id,
      title: widget.article.title,
      link: url,
      summary: widget.article.summary,
      source: widget.article.source,
      publishedAt: widget.article.publishedAt,
    );
  }

  Future<NewsArticleContent> _fetchReaderContent({String? url}) {
    final article = url == null ? widget.article : _articleForReaderUrl(url);
    return _newsService.fetchArticleContent(article, language: widget.language);
  }

  Future<void> _loadReaderArticleFromFinalUrl(String url) async {
    final finalUrl = url.trim();
    if (!_isHttpArticleUrl(finalUrl) || _isGoogleNewsUrl(finalUrl)) return;
    if (_sameNormalizedUrl(finalUrl, widget.article.link)) return;
    if (_lastFinalReaderFetchUrl != null &&
        _sameNormalizedUrl(_lastFinalReaderFetchUrl!, finalUrl)) {
      return;
    }

    final currentLen = _readerText?.trim().length ?? 0;
    if (currentLen >= _httpShortThreshold) return;

    _lastFinalReaderFetchUrl = finalUrl;
    _resolvedArticleUrlForReader = finalUrl;
    unawaited(AppLogger.log(
      'News reader final URL HTTP: estrazione avviata url=$finalUrl',
    ));
    if (mounted && _readerText == null) {
      setState(() => _readerPreparing = true);
    }

    try {
      final content = await _fetchReaderContent(url: finalUrl);
      if (!mounted) return;
      final text = _cleanVisibleText(content.text);
      final existingLen = _readerText?.trim().length ?? 0;
      unawaited(AppLogger.log(
        'News reader final URL HTTP: estrazione completata ' 
        'length=${text.length} existingLength=$existingLen url=$finalUrl',
      ));
      if (text.length >= _httpMinLength && text.length > existingLen) {
        setState(() {
          _readerTitle = widget.article.title;
          _readerText = text;
          _readerHttpTextLength = text.length;
          _readerPreparing = false;
        });
        unawaited(AppLogger.log(
          'News reader final URL HTTP: testo accettato length=${text.length}',
        ));
        return;
      }
    } catch (e) {
      unawaited(AppLogger.log(
        'News reader final URL HTTP: estrazione fallita url=$finalUrl: $e',
      ));
    }

    if (mounted && _readerText == null) {
      setState(() => _readerPreparing = false);
    }
  }

  Future<void> _loadReaderArticle() async {
    unawaited(AppLogger.log('News reader HTTP: estrazione avviata'));
    try {
      final content = await _fetchReaderContent();
      if (!mounted) return;
      final text = content.text.trim();
      unawaited(AppLogger.log(
        'News reader HTTP: estrazione completata length=${text.length}',
      ));
      if (text.length < _httpMinLength) {
        unawaited(AppLogger.log(
          'News reader HTTP: testo troppo corto, resta WebView '
          'length=${text.length}',
        ));
      }
      setState(() {
        if (text.length >= _httpMinLength) {
          _readerTitle = widget.article.title;
          _readerText = text;
          _readerHttpTextLength = text.length;
        }
        _readerPreparing = false;
      });
    } catch (e) {
      debugPrint('Sonarpad reader: rhttp reader failed: $e');
      unawaited(AppLogger.log('News reader HTTP: estrazione fallita: $e'));
      if (!mounted) return;
      setState(() => _readerPreparing = false);
    }
  }

  Future<void> _loadVisibleReaderArticleFromWebView() async {
    for (int i = 0; i < 4; i++) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      // Salta solo se il testo HTTP è già lungo (non parziale)
      final httpLen = _readerHttpTextLength;
      if (_readerText != null && httpLen >= _httpShortThreshold) {
        unawaited(AppLogger.log(
          'News reader WebView: skip tentativo ${i + 1}, '
          'testo HTTP già buono length=$httpLen',
        ));
        return;
      }

      try {
        unawaited(AppLogger.log(
          'News reader WebView: estrazione visibile tentativo ${i + 1}',
        ));
        final text = await _extractVisibleArticleText();
        if (!mounted) return;

        unawaited(AppLogger.log(
          'News reader WebView: tentativo ${i + 1} length=${text.length}',
        ));
        // Sostituisce il testo HTTP se il WebView trova qualcosa di più lungo
        if (text.length >= 400 && text.length > httpLen) {
          setState(() {
            _readerTitle = widget.article.title;
            _readerText = text;
            _readerHttpTextLength = text.length;
            _readerPreparing = false;
          });
          unawaited(AppLogger.log(
            'News reader WebView: testo accettato tentativo ${i + 1} '
            'length=${text.length} (sostituisce HTTP len=$httpLen)',
          ));
          return;
        }
      } catch (e) {
        debugPrint('Sonarpad reader: visible WebView extraction failed: $e');
        unawaited(AppLogger.log(
          'News reader WebView: estrazione fallita tentativo ${i + 1}: $e',
        ));
      }
    }

    // Fallback if it fails after all retries
    if (mounted && _readerText == null) {
      unawaited(AppLogger.log(
        'News reader WebView: nessun testo valido dopo 4 tentativi, '
        'mostro WebView',
      ));
      setState(() => _readerPreparing = false);
    }
  }

  Future<String> _extractVisibleArticleText() async {
    final result = await _controller.runJavaScriptReturningResult(
      r'''
        (function() {
          function asText(value) {
            if (!value) return '';
            if (typeof value === 'string') return value;
            if (Array.isArray(value)) return value.map(asText).join('\n\n');
            if (typeof value === 'object') return asText(value.text || value.value || value.name || '');
            return String(value);
          }
          function isArticleType(type) {
            if (!type) return true;
            if (Array.isArray(type)) return type.some(isArticleType);
            var t = String(type).toLowerCase();
            return t.indexOf('article') >= 0 ||
                   t.indexOf('newsarticle') >= 0 ||
                   t.indexOf('blogposting') >= 0 ||
                   t.indexOf('reportage') >= 0;
          }
          function walk(value, out) {
            if (!value) return;
            if (Array.isArray(value)) {
              value.forEach(function(item) { walk(item, out); });
              return;
            }
            if (typeof value === 'object') {
              out.push(value);
              if (value['@graph']) walk(value['@graph'], out);
              if (value.mainEntity) walk(value.mainEntity, out);
            }
          }
          var scripts = document.querySelectorAll('script[type*="ld+json"]');
          for (var s = 0; s < scripts.length; s++) {
            try {
              var raw = scripts[s].textContent || scripts[s].innerText || '';
              if (!raw.trim()) continue;
              var decoded = JSON.parse(raw);
              var nodes = [];
              walk(decoded, nodes);
              var best = '';
              for (var i = 0; i < nodes.length; i++) {
                var node = nodes[i];
                if (!isArticleType(node['@type'])) continue;
                var candidate = asText(node.articleBody || node.text || node.description || '').trim();
                if (candidate.length > best.length) best = candidate;
              }
              if (best.length >= 300) return best;
            } catch (e) {}
          }
          var el = document.querySelector('article') ||
                   document.querySelector('main') ||
                   document.querySelector('[role="main"]') ||
                   document.querySelector('[role="article"]') ||
                   document.body;
          return el ? el.innerText : '';
        })()
      ''',
    );
    return _cleanVisibleText(_stringFromJavaScriptResult(result));
  }

  Future<String?> _extractReaderArticleText() async {
    final content = await _fetchReaderContent(
      url: _resolvedArticleUrlForReader,
    );
    final text = _cleanVisibleText(content.text);
    return text.length >= 400 ? text : null;
  }

  String _stringFromJavaScriptResult(Object? result) {
    if (result == null) return '';
    final value = result.toString().trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      try {
        final decoded = jsonDecode(value);
        return decoded is String ? decoded : value;
      } catch (e) {
        debugPrint('Sonarpad TTS: JavaScript text decode failed: $e');
      }
    }
    return value;
  }

  String _cleanVisibleText(String value) {
    final seen = <String>{};
    final cleanedValue = HtmlReaderService.cleanText(value)
        .replaceAll('\u00a0', ' ')
        .replaceAll('\r', '\n');
    final lines = cleanedValue
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where(_isReadableArticleLine)
        .where((line) => seen.add(line))
        .toList();
    return _trimArticleText(lines).join('\n\n').trim();
  }

  bool _isReadableArticleLine(String line) {
    final lower = line.toLowerCase();
    if (line.length < 18) return false;
    if (_looksLikeUrl(line)) return false;
    if (!_hasReadableWords(line)) return false;
    if (_isMostlySymbols(line)) return false;
    if (_isNavigationOrChrome(lower)) return false;
    return true;
  }

  bool _looksLikeUrl(String line) {
    final lower = line.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.') ||
        lower.contains('://') ||
        lower.contains('@') && !lower.contains(' ');
  }

  bool _hasReadableWords(String line) {
    final words = line
        .split(' ')
        .where((word) =>
            word.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '').length >= 3)
        .length;
    return words >= 4;
  }

  bool _isMostlySymbols(String line) {
    final letters =
        RegExp(r'\p{L}', unicode: true).allMatches(line).length.toDouble();
    if (letters == 0) return true;
    return letters / line.length < 0.45;
  }

  bool _isNavigationOrChrome(String lower) {
    const blockedFragments = [
      'accedi',
      'accesso',
      'account',
      'acquista',
      'advertising',
      'aggiorna le impostazioni',
      'abbonati',
      'abbonamento',
      'ascolta il podcast',
      'banner',
      'chiudi',
      'clicca qui',
      'condividi',
      'consenso',
      'cookie',
      'copyright',
      'download',
      'edizione',
      'gestisci preferenze',
      'home page',
      'informativa privacy',
      'iscriviti',
      'leggi anche',
      'login',
      'newsletter',
      'notifiche',
      'pubblicita',
      'pubblicità',
      'registrati',
      'riproduci',
      'scopri di piu',
      'scopri di più',
      'seguici',
      'share',
      'sitemap',
      'sostieni',
      'termini e condizioni',
      'tutti i diritti riservati',
    ];
    return blockedFragments.any(lower.contains);
  }

  List<String> _trimArticleText(List<String> lines) {
    final titleWords = _meaningfulTitleWords(widget.article.title);
    final firstArticleLine = lines.indexWhere(
      (line) => _lineLooksLikeArticleStart(line, titleWords),
    );
    final trimmedStart =
        firstArticleLine > 0 ? lines.sublist(firstArticleLine) : lines;
    final footerIndex = trimmedStart.indexWhere(
      (line) => _looksLikeArticleFooter(line.toLowerCase()),
    );
    return footerIndex > 0
        ? trimmedStart.sublist(0, footerIndex)
        : trimmedStart;
  }

  Set<String> _meaningfulTitleWords(String title) {
    return title
        .toLowerCase()
        .split(RegExp(r'[^a-zàèéìòù0-9]+'))
        .where((word) => word.length >= 4)
        .toSet();
  }

  bool _lineLooksLikeArticleStart(String line, Set<String> titleWords) {
    if (titleWords.isEmpty) return true;
    final words = line
        .toLowerCase()
        .split(RegExp(r'[^a-zàèéìòù0-9]+'))
        .where((word) => word.length >= 4)
        .toSet();
    return words.intersection(titleWords).length >= 2;
  }

  bool _looksLikeArticleFooter(String lower) {
    const footerFragments = [
      'altri articoli',
      'articoli correlati',
      'leggi i commenti',
      'potrebbe interessarti',
      'raccomandato da',
      'riproduzione riservata',
      'ti potrebbe interessare',
    ];
    return footerFragments.any(lower.contains);
  }

  Future<String> _textForReading(AppLocalizations l10n) async {
    final readerText = _readerText;
    if (readerText != null && readerText.length >= 200) {
      unawaited(AppLogger.log(
        'News TTS: uso testo reader già pronto length=${readerText.length}',
      ));
      return _visibleReaderTextForSpeech(readerText);
    }

    setState(() => _status = l10n.extractingReaderArticleText);
    try {
      final extractedReaderText = await _extractReaderArticleText();
      if (extractedReaderText != null) {
        unawaited(AppLogger.log(
          'News TTS: uso estrazione HTTP pulita '
          'length=${extractedReaderText.length}',
        ));
        return extractedReaderText;
      }
      unawaited(AppLogger.log(
        'News TTS: estrazione HTTP pulita non valida',
      ));
    } catch (e) {
      debugPrint('Sonarpad TTS: rhttp reader extraction failed: $e');
      unawaited(AppLogger.log('News TTS: estrazione HTTP fallita: $e'));
    }

    setState(() => _status = l10n.extractingVisibleArticleText);
    try {
      final visibleText = await _extractVisibleArticleText();
      unawaited(AppLogger.log(
        'News TTS: estrazione visibile WebView length=${visibleText.length}',
      ));
      if (visibleText.length >= 400) {
        unawaited(AppLogger.log('News TTS: uso testo visibile WebView'));
        return visibleText;
      }
    } catch (e) {
      unawaited(AppLogger.log(
        'News TTS: estrazione visibile WebView fallita: $e',
      ));
    }

    setState(() => _status = l10n.loadingArticle);
    try {
      final content = await _newsService.fetchArticleContent(widget.article,
          language: widget.language);
      final text = content.text.trim();
      unawaited(AppLogger.log(
        'News TTS: fallback HTTP articolo length=${text.length}',
      ));
      if (text.length >= 200) return text;
    } catch (e) {
      debugPrint('Sonarpad TTS: article HTTP extraction failed: $e');
      unawaited(AppLogger.log('News TTS: fallback HTTP fallito: $e'));
    }

    final fallback =
        '${widget.article.title}. ${widget.article.summary}'.trim();
    unawaited(AppLogger.log(
      'News TTS: uso fallback titolo/riassunto length=${fallback.length}',
    ));
    if (fallback.isEmpty) throw Exception(l10n.noTextToRead);
    return fallback;
  }

  String _visibleReaderTextForSpeech(String readerText) {
    final title = (_readerTitle ?? widget.article.title).trim();
    final paragraphs = _dropLeadingDuplicateTitle(
      title,
      _ReaderArticleView.readerParagraphs(readerText),
    );
    return [
      if (title.isNotEmpty) title,
      ..._dedupeConsecutiveParagraphs(paragraphs),
    ].join('\n\n').trim();
  }

  String _newsTtsDebugSnippet(String value, {int maxChars = 180}) {
    final compact = value
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (compact.length <= maxChars) return compact;
    return compact.substring(compact.length - maxChars);
  }

  Future<void> _logNewsTtsChunkPlan({
    required int readingToken,
    required String engine,
    required String voice,
    required String textForChunks,
    required List<String> chunks,
  }) async {
    await AppLogger.log(
      'News Edge TTS debug [$readingToken]: piano lettura veloce ' 
      'engine=$engine voice=$voice title="${widget.article.title}" ' 
      'url=${widget.article.link} textLength=${textForChunks.length} ' 
      'textHash=${textForChunks.hashCode} chunks=${chunks.length} ' 
      'lastText="${_newsTtsDebugSnippet(textForChunks)}"',
    );
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      await AppLogger.log(
        'News Edge TTS debug [$readingToken]: chunk ${i + 1}/${chunks.length} ' 
        'len=${chunk.length} hash=${chunk.hashCode} ' 
        'tail="${_newsTtsDebugSnippet(chunk, maxChars: 140)}"',
      );
    }
  }

  Future<void> _readArticle() async {
    final l10n = AppLocalizations.of(context);
    await _audio.stop();
    await _flutterTts.stop();
    final readingToken = ++_readingToken;

    setState(() {
      _speaking = true;
      _ttsPaused = false;
      _status = null;
    });

    try {
      final text = await _textForReading(l10n);
      final voice = await _voice();
      final engine = await _settings.loadTtsEngine();
      final dictionaryEntries = await _voiceDictionary.loadEntries();
      final textForChunks = _sanitizeNewsTextForEdge(text);
      final chunks = _tts.splitTextForStreaming(textForChunks, maxChunkChars: 650);
      await _logNewsTtsChunkPlan(
        readingToken: readingToken,
        engine: engine,
        voice: voice,
        textForChunks: textForChunks,
        chunks: chunks,
      );
      debugPrint(
        'Sonarpad TTS: web article read requested '
        'title="${widget.article.title}" voice=$voice '
        'textLength=${textForChunks.length} chunks=${chunks.length}',
      );
      if (chunks.isEmpty) throw Exception(l10n.noTextToRead);

      if (engine == 'system') {
        if (Platform.isIOS) {
          try {
            await _ttsCommands.invokeMethod(
                'setupMagicTap', widget.article.title);
          } catch (e) {
            debugPrint('Errore setupMagicTap $e');
          }
        }
        await _flutterTts.awaitSpeakCompletion(true);
        if (Platform.isIOS) {
          await _flutterTts.setSharedInstance(true);
          await _flutterTts.autoStopSharedSession(false);
        }
        final speed = await _settings.loadTtsSpeed();
        final pitch = await _settings.loadTtsPitch();
        await _flutterTts.setSpeechRate(speed * 0.5);
        await _flutterTts.setPitch(pitch);

        final sysLang = await _settings.loadSystemTtsLanguage();
        final sysVoice = await _settings.loadSystemTtsVoice();

        if (sysVoice != null) {
          await _flutterTts.setVoice({"name": sysVoice, "locale": sysLang});
        } else {
          await _flutterTts.setLanguage(sysLang);
        }

        for (var i = 0; i < chunks.length; i++) {
          if (!mounted || !_speaking || readingToken != _readingToken) break;
          while (_ttsPaused) {
            if (!mounted || !_speaking || readingToken != _readingToken) break;
            await Future.delayed(const Duration(milliseconds: 100));
          }
          if (!mounted || !_speaking || readingToken != _readingToken) break;
          final textToSpeak =
              _voiceDictionary.applyToText(chunks[i], dictionaryEntries);
          await _flutterTts.speak(textToSpeak);
        }

        if (mounted) {
          _status = null;
        }
      } else {
        final controller = StreamController<File>();
        _edgeFileController = controller;
        var generationDone = false;
        Object? generationError;
        var generatedCount = 0;
        var queuedCount = 0;
        var playedCount = 0;
        final queuedFilePaths = <String>{};

        await AppLogger.log(
          'News Edge TTS debug [$readingToken]: avvio ramo Edge veloce, '
          'controller=${identityHashCode(controller)}',
        );

        final generation = Future<void>(() async {
          for (var i = 0; i < chunks.length; i++) {
            if (!mounted || !_speaking || readingToken != _readingToken) {
              await AppLogger.log(
                'News Edge TTS debug [$readingToken]: generazione interrotta '
                'prima del chunk ${i + 1}; mounted=$mounted speaking=$_speaking '
                'currentToken=$_readingToken',
              );
              break;
            }
            final textToSpeak =
                _voiceDictionary.applyToText(chunks[i], dictionaryEntries).trim();
            if (textToSpeak.isEmpty) {
              await AppLogger.log(
                'News Edge TTS debug [$readingToken]: chunk ${i + 1}/${chunks.length} '
                'saltato perché vuoto dopo dizionario',
              );
              continue;
            }
            await AppLogger.log(
              'News Edge TTS debug [$readingToken]: sintesi chunk ${i + 1}/${chunks.length} '
              'len=${textToSpeak.length} hash=${textToSpeak.hashCode} '
              'tail="${_newsTtsDebugSnippet(textToSpeak, maxChars: 140)}"',
            );
            final file =
                await _tts.speakToFile(text: textToSpeak, voice: voice);
            generatedCount += 1;
            final size = await file.length();
            debugPrint(
              'Sonarpad TTS: web chunk ${i + 1}/${chunks.length} ready '
              'path=${file.path} size=$size',
            );
            await AppLogger.log(
              'News Edge TTS debug [$readingToken]: file pronto '
              'chunk=${i + 1}/${chunks.length} generated=$generatedCount '
              'path=${file.path} size=$size',
            );
            if (!controller.isClosed &&
                mounted &&
                _speaking &&
                readingToken == _readingToken) {
              if (!queuedFilePaths.add(file.path)) {
                await AppLogger.log(
                  'News Edge TTS debug [$readingToken]: DUPLICATO BLOCCATO '
                  'path già accodato ${file.path}',
                );
                continue;
              }
              queuedCount += 1;
              controller.add(file);
              await AppLogger.log(
                'News Edge TTS debug [$readingToken]: file accodato allo stream '
                'chunk=${i + 1}/${chunks.length} queued=$queuedCount '
                'path=${file.path}',
              );
            } else {
              await AppLogger.log(
                'News Edge TTS debug [$readingToken]: file NON accodato '
                'controllerClosed=${controller.isClosed} mounted=$mounted '
                'speaking=$_speaking currentToken=$_readingToken',
              );
            }
          }
          generationDone = true;
          await AppLogger.log(
            'News Edge TTS debug [$readingToken]: generazione completata '
            'generated=$generatedCount queued=$queuedCount',
          );
          if (!controller.isClosed) await controller.close();
        }).catchError((e) async {
          generationError = e;
          generationDone = true;
          await AppLogger.log(
            'News Edge TTS debug [$readingToken]: ERRORE generazione $e',
          );
          if (!controller.isClosed) await controller.close();
        });

        await AppLogger.log(
          'News Edge TTS debug [$readingToken]: riproduzione veloce a chunk singoli, '
          'resetAfterCompletion=false',
        );
        await for (final file in controller.stream) {
          while (_ttsPaused) {
            if (!mounted || !_speaking || readingToken != _readingToken) break;
            await Future.delayed(const Duration(milliseconds: 100));
          }
          if (!mounted || !_speaking || readingToken != _readingToken) break;
          playedCount += 1;
          await AppLogger.log(
            'News Edge TTS debug [$readingToken]: riproduzione chunk START '
            'played=$playedCount queued=$queuedCount path=${file.path}',
          );
          await _audio.playFilesSequentially(
            [file],
            title: widget.article.title,
            resetAfterCompletion: false,
            onChunkStarted: (index, startedFile) {
              unawaited(AppLogger.log(
                'News Edge TTS debug [$readingToken]: AudioPlayer onChunkStarted '
                'index=${index + 1} path=${startedFile.path}',
              ));
            },
          );
          await AppLogger.log(
            'News Edge TTS debug [$readingToken]: riproduzione chunk END '
            'played=$playedCount path=${file.path}',
          );
        }

        await generation;
        if (_edgeFileController == controller) {
          _edgeFileController = null;
        }
        if (readingToken != _readingToken) return;
        if (generationError != null) throw Exception(generationError);

        await AppLogger.log(
          'News Edge TTS debug [$readingToken]: lettura Edge conclusa '
          'generationDone=$generationDone generated=$generatedCount '
          'queued=$queuedCount played=$playedCount',
        );

        if (!mounted) return;
        if (!generationDone) {
          setState(() => _status = l10n.readingStopped);
        }
      }
    } catch (e) {
      debugPrint('Sonarpad TTS: web article reading error=$e');
      unawaited(AppLogger.log(
        'News Edge TTS debug [$readingToken]: ERRORE lettura $e',
      ));
      if (!mounted) return;
      if (readingToken != _readingToken) return;
      setState(() => _status = l10n.edgeTtsError(e));
            showStatusMessage(context, l10n.edgeTtsError(e));
    } finally {
      unawaited(AppLogger.log(
        'News Edge TTS debug [$readingToken]: finally '
        'mounted=$mounted currentToken=$_readingToken speaking=$_speaking',
      ));
      if (mounted && readingToken == _readingToken) {
        setState(() => _speaking = false);
      }
    }
  }

  Future<void> _stopReading() async {
    if (!_speaking) return;
    final previousToken = _readingToken;
    _readingToken += 1;
    unawaited(AppLogger.log(
      'News Edge TTS debug [$previousToken]: stop richiesto, '
      'nuovoToken=$_readingToken',
    ));
    final edgeController = _edgeFileController;
    _edgeFileController = null;
    final stopAudio = _audio.stop();
    final stopTts = _flutterTts.stop();
    if (edgeController != null && !edgeController.isClosed) {
      await edgeController.close();
    }
    await stopAudio;
    await stopTts;
    if (!mounted) return;
    setState(() {
      _speaking = false;
      _status = AppLocalizations.of(context).readingStopped;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.article),
        actions: [
          IconButton(
            onPressed: _saveArticle,
            icon: const Icon(Icons.save),
            tooltip: l10n.saveArticle,
          ),
          IconButton(
            onPressed: _shareArticle,
            icon: const Icon(Icons.share),
            tooltip: l10n.shareArticle,
          ),
          IconButton(
            onPressed: _speaking ? null : _readArticle,
            icon: const Icon(Icons.volume_up),
            tooltip: l10n.readWithEdgeTts,
          ),
          IconButton(
            onPressed: _speaking ? _stopReading : null,
            icon: const Icon(Icons.stop),
            tooltip: l10n.stopReading,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(l10n),
      bottomNavigationBar: _status == null
          ? null
          : BottomAppBar(
              child: Semantics(
                liveRegion: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_status!),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final readerText = _readerText;
    if (readerText != null && readerText.isNotEmpty) {
      return _ReaderArticleView(
        title: _readerTitle ?? widget.article.title,
        text: readerText,
      );
    }

    if (_readerPreparing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(semanticsLabel: l10n.loadingArticle),
            const SizedBox(height: 12),
            Text(l10n.loadingArticle),
          ],
        ),
      );
    }

    return WebViewWidget(controller: _controller);
  }
}

class _ReaderArticleView extends StatelessWidget {
  const _ReaderArticleView({
    required this.title,
    required this.text,
  });

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final paragraphs =
        _dropLeadingDuplicateTitle(title, readerParagraphs(text));

    return Semantics(
      label: l10n.articleTextSemantics,
      explicitChildNodes: true,
      child: CustomScrollView(
        scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SelectableText(
                  title,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                ...paragraphs.map(
                  (p) => Semantics(
                    container: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SelectableText(
                        p,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static List<String> readerParagraphs(String value) {
    final sourceParagraphs = value
        .replaceAll('\r', '\n')
        .split(RegExp(r'\n{1,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);

    final result = <String>[];
    for (final paragraph in sourceParagraphs) {
      result.addAll(_splitLongParagraph(paragraph));
    }
    return result;
  }

  static List<String> _splitLongParagraph(String paragraph) {
    const maxLength = 650;
    if (paragraph.length <= maxLength) return [paragraph];

    final parts = <String>[];
    final sentences = paragraph
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.isNotEmpty);

    var current = '';
    for (final sentence in sentences) {
      if (current.isEmpty) {
        current = sentence;
      } else if (current.length + sentence.length + 1 <= maxLength) {
        current = '$current $sentence';
      } else {
        parts.add(current);
        current = sentence;
      }
    }

    if (current.isNotEmpty) parts.add(current);
    return parts;
  }
}

List<String> _dropLeadingDuplicateTitle(
  String title,
  List<String> paragraphs,
) {
  if (title.trim().isEmpty || paragraphs.isEmpty) return paragraphs;
  if (!_sameNewsText(title, paragraphs.first)) return paragraphs;
  return paragraphs.skip(1).toList();
}

String _sanitizeNewsTextForEdge(String text) {
  final cleanedText = HtmlReaderService.cleanText(text)
      .replaceAll('\u00a0', ' ')
      .replaceAll('\u200b', '')
      .replaceAll('\u200c', '')
      .replaceAll('\u200d', '')
      .replaceAll('\ufeff', '')
      .replaceAll('\u2028', '\n')
      .replaceAll('\u2029', '\n')
      .replaceAll('\r', '\n');
  final paragraphs = cleanedText
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  return _ensureTerminalPunctuation(
    _dedupeConsecutiveParagraphs(paragraphs).join('\n\n').trim(),
  );
}

List<String> _dedupeConsecutiveParagraphs(List<String> paragraphs) {
  final result = <String>[];
  String? previous;
  for (final paragraph in paragraphs) {
    final normalized = _normalizeNewsText(paragraph);
    if (normalized.isEmpty || normalized == previous) continue;
    result.add(paragraph);
    previous = normalized;
  }
  return result;
}

String _ensureTerminalPunctuation(String text) {
  if (text.isEmpty) return text;
  const terminalPunctuation = '.!?';
  final last = text[text.length - 1];
  return terminalPunctuation.contains(last) ? text : '$text.';
}

bool _sameNewsText(String a, String b) =>
    _normalizeNewsText(a) == _normalizeNewsText(b);

String _normalizeNewsText(String value) {
  var normalized = value.toLowerCase().trim();
  const trailingPunctuation = '.,:;!?“”"‘’';
  while (normalized.isNotEmpty &&
      trailingPunctuation.contains(normalized[normalized.length - 1])) {
    normalized = normalized.substring(0, normalized.length - 1).trimRight();
  }
  final buffer = StringBuffer();
  var lastWasSpace = false;
  for (final rune in normalized.runes) {
    final char = String.fromCharCode(rune);
    final isSpace = char.trim().isEmpty;
    if (isSpace) {
      if (!lastWasSpace) buffer.write(' ');
    } else {
      buffer.write(char);
    }
    lastWasSpace = isSpace;
  }
  return buffer.toString().trim();
}
