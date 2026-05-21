import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/news_article.dart';
import '../services/audio_player_service.dart';
import '../services/news_service.dart';
import '../tts/edge_tts_bridge.dart';

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
  final _audio = AudioPlayerService();
  bool _speaking = false;
  String? _status;
  int _readyChunks = 0;
  int _totalChunks = 0;

  String get _voice => widget.language == NewsLanguage.italian
      ? 'it-IT-ElsaNeural'
      : 'en-US-JennyNeural';

  Future<void> _readWithEdgeTtsStreaming() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _speaking = true;
      _readyChunks = 0;
      _totalChunks = 0;
      _status = l10n.preparingEdgeTts;
    });

    try {
      final text = '${widget.article.title}. ${widget.article.summary}';
      final chunks = _tts.splitTextForStreaming(text, maxChunkChars: 650);
      _totalChunks = chunks.length;
      if (chunks.isEmpty) throw Exception(l10n.noTextToRead);

      // Coda semplice: appena il primo blocco è pronto parte la riproduzione,
      // mentre gli altri blocchi vengono generati in sequenza.
      final queue = <File>[];
      final controller = StreamController<File>();
      var generationDone = false;
      Object? generationError;

      final generation = Future<void>(() async {
        for (var i = 0; i < chunks.length; i++) {
          final file = await _tts.speakToFile(text: chunks[i], voice: _voice);
          queue.add(file);
          controller.add(file);
          if (!mounted) return;
          setState(() {
            _readyChunks = i + 1;
            _status = l10n.chunkCreated(i + 1, chunks.length);
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
            () => _status = l10n.playingChunk(index + 1, _totalChunks, size));
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
    final l10n = AppLocalizations.of(context);
    setState(() {
      _speaking = false;
      _status = l10n.readingStopped;
    });
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.article)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(article.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(l10n.source(article.source)),
          const SizedBox(height: 16),
          Text(article.summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          Semantics(
            liveRegion: true,
            child: Text(_status ?? l10n.readyStatus),
          ),
          if (_totalChunks > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _readyChunks / _totalChunks),
            const SizedBox(height: 8),
            Text(l10n.audioChunksReady(_readyChunks, _totalChunks)),
          ],
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
