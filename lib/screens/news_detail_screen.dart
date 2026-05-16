import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/news_article.dart';
import '../services/audio_player_service.dart';
import '../services/news_service.dart';
import '../tts/edge_tts_bridge.dart';

class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;
  final NewsLanguage language;
  const NewsDetailScreen({super.key, required this.article, required this.language});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  final _tts = EdgeTtsBridge();
  final _audio = AudioPlayerService();
  bool _speaking = false;
  String _status = 'Pronto.';
  int _readyChunks = 0;
  int _totalChunks = 0;

  String get _voice => widget.language == NewsLanguage.italian ? 'it-IT-ElsaNeural' : 'en-US-JennyNeural';

  Future<void> _readWithEdgeTtsStreaming() async {
    setState(() {
      _speaking = true;
      _readyChunks = 0;
      _totalChunks = 0;
      _status = 'Preparo lettura Edge TTS a blocchi...';
    });

    try {
      final text = '${widget.article.title}. ${widget.article.summary}';
      final chunks = _tts.splitTextForStreaming(text, maxChunkChars: 650);
      _totalChunks = chunks.length;
      if (chunks.isEmpty) throw Exception('Nessun testo da leggere.');

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
            _status = 'Blocco ${i + 1} di ${chunks.length} creato. Lettura in corso...';
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
        setState(() => _status = 'Riproduco blocco ${index + 1} di $_totalChunks ($size byte)...');
        await _audio.playFilesSequentially([file]);
        index++;
      }

      await generation;
      if (generationError != null) throw Exception(generationError);

      if (!mounted) return;
      setState(() {
        _status = generationDone
            ? 'Lettura terminata. Blocchi creati: $_readyChunks/$_totalChunks. Libreria: ${_tts.lastLibraryPath ?? 'non indicata'}'
            : 'Lettura interrotta.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Errore Edge TTS: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore Edge TTS: $e')),
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
      _status = 'Lettura interrotta.';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Articolo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(article.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Fonte: ${article.source}'),
          const SizedBox(height: 16),
          Text(article.summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          Semantics(
            liveRegion: true,
            child: Text(_status),
          ),
          if (_totalChunks > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _readyChunks / _totalChunks),
            const SizedBox(height: 8),
            Text('Blocchi audio pronti: $_readyChunks / $_totalChunks'),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _speaking ? null : _readWithEdgeTtsStreaming,
            icon: const Icon(Icons.volume_up),
            label: Text(_speaking ? 'Lettura in corso...' : 'Leggi con Edge TTS'),
          ),
          OutlinedButton.icon(
            onPressed: _speaking ? _stopReading : null,
            icon: const Icon(Icons.stop),
            label: const Text('Interrompi lettura'),
          ),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(article.link), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Apri articolo originale'),
          ),
        ],
      ),
    );
  }
}
