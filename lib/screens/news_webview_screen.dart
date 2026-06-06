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
import '../services/voice_dictionary_service.dart';
import '../tts/edge_tts_bridge.dart';
import '../utils/app_logger.dart';
import 'package:flutter_tts/flutter_tts.dart';

class NewsWebViewScreen extends StatefulWidget {
  const NewsWebViewScreen(
      {super.key, required this.article, required this.language});

  final NewsArticle article;
  final NewsLanguage language;

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
  bool _readerPreparing = true;
  bool _speaking = false;
  bool _ttsPaused = false;
  String? _status;

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
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            unawaited(AppLogger.log('News WebView: caricamento avviato url=$url'));
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
            _controller.runJavaScript('''
              var videos = document.querySelectorAll("video");
              for (var i = 0; i < videos.length; i++) {
                videos[i].pause();
                videos[i].remove();
              }
              var iframes = document.querySelectorAll("iframe");
              for (var i = 0; i < iframes.length; i++) {
                var src = iframes[i].src || "";
                if (src.includes("video") || src.includes("player") || src.includes("youtube") || src.includes("mediaset.it/player") || src.includes("dailymotion")) {
                  iframes[i].remove();
                }
              }
            ''').catchError((e) {
              unawaited(AppLogger.log(
                'News WebView: rimozione contenuti media fallita: $e',
              ));
            });
            unawaited(_loadVisibleReaderArticleFromWebView());
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            if ((url.contains('player') && !url.contains('multiplayer.it')) ||
                url.contains('video') ||
                url.contains('youtube.com/embed') ||
                url.contains('mediaset.it/player') ||
                url.contains('dailymotion.com/embed')) {
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

  @override
  void dispose() {
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

  Future<void> _loadReaderArticle() async {
    unawaited(AppLogger.log('News reader HTTP: estrazione avviata'));
    try {
      final content = await _newsService.fetchArticleContent(widget.article,
          language: widget.language);
      if (!mounted) return;
      final text = content.text.trim();
      unawaited(AppLogger.log(
        'News reader HTTP: estrazione completata length=${text.length}',
      ));
      if (text.length < 200) {
        unawaited(AppLogger.log(
          'News reader HTTP: testo troppo corto, resta WebView '
          'length=${text.length}',
        ));
      }
      setState(() {
        if (text.length >= 200) {
          _readerTitle = widget.article.title;
          _readerText = text;
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
      if (_readerText != null) {
        unawaited(AppLogger.log(
          'News reader WebView: skip tentativo ${i + 1}, testo già presente',
        ));
        return;
      }

      try {
        unawaited(AppLogger.log(
          'News reader WebView: estrazione visibile tentativo ${i + 1}',
        ));
        final text = await _extractVisibleArticleText();
        if (!mounted || _readerText != null) return;

        unawaited(AppLogger.log(
          'News reader WebView: tentativo ${i + 1} length=${text.length}',
        ));
        if (text.length >= 400) {
          setState(() {
            _readerTitle = widget.article.title;
            _readerText = text;
            _readerPreparing = false;
          });
          unawaited(AppLogger.log(
            'News reader WebView: testo accettato tentativo ${i + 1}',
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
      'document.body ? document.body.innerText : ""',
    );
    return _cleanVisibleText(_stringFromJavaScriptResult(result));
  }

  Future<String?> _extractReaderArticleText() async {
    final content = await _newsService.fetchArticleContent(widget.article,
        language: widget.language);
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
    final lines = value
        .replaceAll('\u00a0', ' ')
        .replaceAll('\r', '\n')
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
      ...paragraphs,
    ].join('\n\n').trim();
  }

  Future<void> _readArticle() async {
    final l10n = AppLocalizations.of(context);
    await _audio.stop();
    await _flutterTts.stop();

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
      final chunks = _tts.splitTextForStreaming(text, maxChunkChars: 650);
      unawaited(AppLogger.log(
        'News TTS: lettura avviata engine=$engine voice=$voice '
        'textLength=${text.length} chunks=${chunks.length}',
      ));
      debugPrint(
        'Sonarpad TTS: web article read requested '
        'title="${widget.article.title}" voice=$voice '
        'textLength=${text.length} chunks=${chunks.length}',
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
          if (!mounted || !_speaking) break;
          while (_ttsPaused) {
            if (!mounted || !_speaking) break;
            await Future.delayed(const Duration(milliseconds: 100));
          }
          if (!mounted || !_speaking) break;
          final textToSpeak =
              _voiceDictionary.applyToText(chunks[i], dictionaryEntries);
          await _flutterTts.speak(textToSpeak);
        }

        if (mounted) {
          _status = null;
        }
      } else {
        final controller = StreamController<File>();
        var generationDone = false;
        Object? generationError;

        final generation = Future<void>(() async {
          for (var i = 0; i < chunks.length; i++) {
            final textToSpeak =
                _voiceDictionary.applyToText(chunks[i], dictionaryEntries);
            final file =
                await _tts.speakToFile(text: textToSpeak, voice: voice);
            final size = await file.length();
            debugPrint(
              'Sonarpad TTS: web chunk ${i + 1}/${chunks.length} ready '
              'path=${file.path} size=$size',
            );
            controller.add(file);
          }
          generationDone = true;
          await controller.close();
        }).catchError((e) async {
          generationError = e;
          generationDone = true;
          await controller.close();
        });

        await for (final file in controller.stream) {
          while (_ttsPaused) {
            if (!mounted || !_speaking) break;
            await Future.delayed(const Duration(milliseconds: 100));
          }
          if (!mounted || !_speaking) break;
          await _audio.playFilesSequentially([file]);
        }

        await generation;
        if (generationError != null) throw Exception(generationError);

        if (!mounted) return;
        if (!generationDone) {
          setState(() => _status = l10n.readingStopped);
        }
      }
    } catch (e) {
      debugPrint('Sonarpad TTS: web article reading error=$e');
      if (!mounted) return;
      setState(() => _status = l10n.edgeTtsError(e));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.edgeTtsError(e))),
      );
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _stopReading() async {
    await _audio.stop();
    await _flutterTts.stop();
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
