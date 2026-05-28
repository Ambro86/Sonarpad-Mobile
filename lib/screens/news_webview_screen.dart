import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/news_article.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';
import '../services/news_service.dart';
import '../tts/edge_tts_bridge.dart';

class NewsWebViewScreen extends StatefulWidget {
  const NewsWebViewScreen({super.key, required this.article});

  final NewsArticle article;

  @override
  State<NewsWebViewScreen> createState() => _NewsWebViewScreenState();
}

class _NewsWebViewScreenState extends State<NewsWebViewScreen> {
  late final WebViewController _controller;
  final _audio = AudioPlayerService();
  final _newsService = NewsService();
  final _settings = AppSettingsService();
  final _tts = EdgeTtsBridge();
  bool _loading = true;
  bool _readerPreparing = true;
  bool _speaking = false;
  String? _readerTitle;
  String? _readerText;
  String? _status;
  int _readyChunks = 0;
  int _totalChunks = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
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
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  Future<String> _voice() async {
    final configured = await _settings.loadTtsVoice();
    if (configured.trim().isNotEmpty) return configured;
    return 'it-IT-IsabellaNeural';
  }

  Future<void> _loadReaderArticle() async {
    try {
      final content = await _newsService.fetchArticleContent(widget.article);
      if (!mounted) return;
      final text = content.text.trim();
      setState(() {
        if (text.length >= 200) {
          _readerTitle = widget.article.title;
          _readerText = text;
        }
        _readerPreparing = false;
      });
    } catch (e) {
      debugPrint('Sonarpad reader: rhttp reader failed: $e');
      if (!mounted) return;
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
    final content = await _newsService.fetchArticleContent(widget.article);
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
    if (readerText != null && readerText.length >= 200) return readerText;

    setState(() => _status = l10n.extractingReaderArticleText);
    try {
      final extractedReaderText = await _extractReaderArticleText();
      if (extractedReaderText != null) return extractedReaderText;
    } catch (e) {
      debugPrint('Sonarpad TTS: rhttp reader extraction failed: $e');
    }

    setState(() => _status = l10n.extractingVisibleArticleText);
    final visibleText = await _extractVisibleArticleText();
    if (visibleText.length >= 400) return visibleText;

    setState(() => _status = l10n.loadingArticle);
    try {
      final content = await _newsService.fetchArticleContent(widget.article);
      if (content.text.trim().length >= 200) return content.text.trim();
    } catch (e) {
      debugPrint('Sonarpad TTS: article HTTP extraction failed: $e');
    }

    final fallback =
        '${widget.article.title}. ${widget.article.summary}'.trim();
    if (fallback.isEmpty) throw Exception(l10n.noTextToRead);
    return fallback;
  }

  Future<void> _readArticle() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _speaking = true;
      _readyChunks = 0;
      _totalChunks = 0;
      _status = l10n.preparingEdgeTts;
    });

    try {
      final text = await _textForReading(l10n);
      final voice = await _voice();
      final chunks = _tts.splitTextForStreaming(text, maxChunkChars: 650);
      _totalChunks = chunks.length;
      debugPrint(
        'Sonarpad TTS: web article read requested '
        'title="${widget.article.title}" voice=$voice '
        'textLength=${text.length} chunks=${chunks.length}',
      );
      if (chunks.isEmpty) throw Exception(l10n.noTextToRead);

      final controller = StreamController<File>();
      var generationDone = false;
      Object? generationError;

      final generation = Future<void>(() async {
        for (var i = 0; i < chunks.length; i++) {
          final file = await _tts.speakToFile(text: chunks[i], voice: voice);
          final size = await file.length();
          debugPrint(
            'Sonarpad TTS: web chunk ${i + 1}/${chunks.length} ready '
            'path=${file.path} size=$size',
          );
          controller.add(file);
          if (!mounted) return;
          setState(() {
            _readyChunks = i + 1;
          });
        }
        generationDone = true;
        await controller.close();
      }).catchError((e) async {
        generationError = e;
        generationDone = true;
        await controller.close();
      });

      var index = 0;
      await for (final file in controller.stream) {
        if (!mounted || !_speaking) break;
        final size = await file.length();
        setState(
          () => _status = l10n.playingChunk(index + 1, _totalChunks, size),
        );
        await _audio.playFilesSequentially([file]);
        index++;
      }

      await generation;
      if (generationError != null) throw Exception(generationError);

      if (!mounted) return;
      setState(() {
        _status = generationDone
            ? l10n.readingFinished(
                _readyChunks,
                _totalChunks,
                _tts.lastLibraryPath ?? l10n.libraryNotSpecified,
              )
            : l10n.readingStopped;
      });
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
                    if (_totalChunks > 0) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _readyChunks / _totalChunks,
                      ),
                      const SizedBox(height: 4),
                      Text(l10n.audioChunksReady(_readyChunks, _totalChunks)),
                    ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$title\n\n',
              style: theme.textTheme.headlineSmall,
            ),
            TextSpan(
              text: text,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
