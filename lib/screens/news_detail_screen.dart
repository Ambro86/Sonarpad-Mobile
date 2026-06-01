import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/news_article.dart';
import '../services/accessibility_feedback_service.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';
import '../services/news_service.dart';
import '../services/voice_dictionary_service.dart';
import '../tts/edge_tts_bridge.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'news_webview_screen.dart';

class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;
  final NewsLanguage language;
  const NewsDetailScreen(
      {super.key, required this.article, required this.language});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  final _tts = EdgeTtsBridge();
  final _flutterTts = FlutterTts();
  final _audio = AudioPlayerService();
  final _settings = AppSettingsService();
  final _voiceDictionary = VoiceDictionaryService();
  bool _speaking = false;
  bool _ttsPaused = false;
  
  static const _ttsCommands = MethodChannel('sonarpad/tts_commands');
  static const _ttsEvents = EventChannel('sonarpad/tts_events');
  StreamSubscription? _ttsEventsSub;
  String? _status;
  int _readyChunks = 0;
  int _totalChunks = 0;

  Future<String> _voice() async {
    final configured = await _settings.loadTtsVoice();
    if (configured.trim().isNotEmpty) return configured;
    return widget.language == NewsLanguage.italian
        ? 'it-IT-IsabellaNeural'
        : 'en-US-JennyNeural';
  }

  Future<void> _stopReading() async {
    if (!_speaking) return;
    setState(() {
      _speaking = false;
      _ttsPaused = false;
      _status = null;
      _readyChunks = 0;
      _totalChunks = 0;
    });
    await _audio.stop();
    await _flutterTts.stop();
  }

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

  @override
  void initState() {
    super.initState();
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

  Future<void> _readWithEdgeTtsStreaming() async {
    final l10n = AppLocalizations.of(context);
    await _audio.stop();
    await _flutterTts.stop();

    setState(() {
      _speaking = true;
      _ttsPaused = false;
      _readyChunks = 0;
      _totalChunks = 0;
      _status = null;
    });

    try {
      final text = _articleTextForSpeech(widget.article);
      final voice = await _voice();
      final engine = await _settings.loadTtsEngine();
      final dictionaryEntries = await _voiceDictionary.loadEntries();
      final chunks = _tts.splitTextForStreaming(text, maxChunkChars: 650);
      _totalChunks = chunks.length;
      debugPrint(
        'Sonarpad TTS: read requested article="${widget.article.title}" '
        'voice=$voice textLength=${text.length} chunks=${chunks.length}',
      );
      if (chunks.isEmpty) throw Exception(l10n.noTextToRead);

      if (engine == 'system') {
        if (Platform.isIOS) {
          try {
            await _ttsCommands.invokeMethod('setupMagicTap', widget.article.title);
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
          _readyChunks = i + 1;
          final textToSpeak =
              _voiceDictionary.applyToText(chunks[i], dictionaryEntries);
          await _flutterTts.speak(textToSpeak);
        }

        if (mounted) {
          _status = null;
        }
      } else {
        // Coda semplice: appena il primo blocco è pronto parte la riproduzione,
        // mentre gli altri blocchi vengono generati in sequenza.
        final queue = <File>[];
        final controller = StreamController<File>();
        var generationDone = false;
        Object? generationError;

        final generation = Future<void>(() async {
          for (var i = 0; i < chunks.length; i++) {
            final textToSpeak =
                _voiceDictionary.applyToText(chunks[i], dictionaryEntries);
            final file = await _tts.speakToFile(text: textToSpeak, voice: voice);
            final size = await file.length();
            debugPrint(
              'Sonarpad TTS: chunk ${i + 1}/${chunks.length} ready '
              'path=${file.path} size=$size',
            );
            queue.add(file);
            controller.add(file);
            _readyChunks = i + 1;
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
          while (_ttsPaused) {
            if (!mounted || !_speaking) break;
            await Future.delayed(const Duration(milliseconds: 100));
          }
          if (!mounted || !_speaking) break;
          debugPrint(
            'Sonarpad TTS: playing chunk ${index + 1}/$_totalChunks '
            'path=${file.path}',
          );
          await _audio.playFilesSequentially([file]);
          index++;
        }

        await generation;
        if (generationError != null) throw Exception(generationError);

        if (!mounted) return;
        debugPrint(
          'Sonarpad TTS: reading finished ready=$_readyChunks total=$_totalChunks '
          'library=${_tts.lastLibraryPath}',
        );
        if (!generationDone) {
          setState(() => _status = l10n.readingStopped);
        }
      }
    } catch (e) {
      debugPrint('Sonarpad TTS: reading error=$e');
      if (!mounted) return;
      setState(() => _status = l10n.edgeTtsError(e));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.edgeTtsError(e))),
      );
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  // dispose() è stato spostato sopra

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final l10n = AppLocalizations.of(context);
    final summary = _dropLeadingDuplicateTitle(article.title, article.summary);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.article)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(article.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(l10n.source(article.source)),
          const SizedBox(height: 16),
          Text(l10n.articlePreview,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          Semantics(
            liveRegion: false,
            child: Text(_status ?? l10n.readyStatus),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _speaking ? null : _readWithEdgeTtsStreaming,
            icon: const Icon(Icons.volume_up),
            label:
                Text(_speaking ? l10n.readingInProgress : l10n.readWithEdgeTts),
          ),
          OutlinedButton.icon(
            onPressed: _speaking ? _stopReading : null,
            icon: const Icon(Icons.stop),
            label: Text(l10n.stopReading),
          ),
          OutlinedButton.icon(
            onPressed: () => AccessibilityFeedbackService.push(
              context,
              builder: (_) => NewsWebViewScreen(article: article, language: widget.language),
              routeName: 'news-webview',
            ),
            icon: const Icon(Icons.article),
            label: Text(l10n.readFullArticle),
          ),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(article.link),
                mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_browser),
            label: Text(l10n.openOriginalArticle),
          ),
        ],
      ),
    );
  }
}

String _articleTextForSpeech(NewsArticle article) {
  final title = article.title.trim();
  final summary = _dropLeadingDuplicateTitle(title, article.summary);
  return [title, summary]
      .where((part) => part.trim().isNotEmpty)
      .join('. ')
      .trim();
}

String _dropLeadingDuplicateTitle(String title, String text) {
  final trimmed = text.trim();
  if (title.trim().isEmpty || trimmed.isEmpty) return trimmed;
  final paragraphs = trimmed
      .replaceAll('\r', '\n')
      .split('\n')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (paragraphs.isEmpty || !_sameNewsText(title, paragraphs.first)) {
    return trimmed;
  }
  return paragraphs.skip(1).join('\n\n').trim();
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
