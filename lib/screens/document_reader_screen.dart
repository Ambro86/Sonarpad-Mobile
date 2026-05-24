import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/document_item.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';
import '../services/document_text_extractor.dart';
import '../tts/edge_tts_bridge.dart';

/// Schermata di lettura/ascolto di un documento della libreria.
///
/// - Estrae il testo (PDF, DOCX, EPUB, TXT, MD, HTML) via [DocumentTextExtractor].
/// - Divide il testo negli stessi blocchi del TTS e li mostra singolarmente.
/// - Il blocco in riproduzione viene evidenziato e la vista scorre automaticamente.
/// - Supporta flick/scroll iOS con [BouncingScrollPhysics].
class DocumentReaderScreen extends StatefulWidget {
  final DocumentItem document;

  const DocumentReaderScreen({super.key, required this.document});

  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen> {
  final _tts = EdgeTtsBridge();
  final _audio = AudioPlayerService();
  final _settings = AppSettingsService();
  final _extractor = DocumentTextExtractor();
  final _scrollController = ScrollController();

  // Testo e chunks
  bool _loadingText = true;
  String _documentText = '';
  String? _loadError;
  List<String> _chunks = [];
  final List<GlobalKey> _chunkKeys = [];

  // TTS state
  bool _speaking = false;
  int _playingChunkIndex = -1; // indice del chunk in riproduzione
  int _readyChunks = 0;
  int _totalChunks = 0;
  String? _ttsStatus;

  bool _isEditing = false;
  late final TextEditingController _editController;

  static const int _maxChunkChars = 650;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
    _extractText();
  }

  @override
  void dispose() {
    _audio.dispose();
    _scrollController.dispose();
    _editController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Estrazione testo
  // ---------------------------------------------------------------------------

  Future<void> _extractText() async {
    final ext = widget.document.extension.toLowerCase();
    final path = widget.document.path;
    try {
      final result = await _extractor.extract(path: path, extension: ext);
      _documentText = result.text;
      _loadError = result.error;
      if (_documentText.isNotEmpty) {
        _chunks = _tts.splitTextForStreaming(
          _documentText,
          maxChunkChars: _maxChunkChars,
        );
        _chunkKeys
          ..clear()
          ..addAll(List.generate(_chunks.length, (_) => GlobalKey()));
      }
    } catch (e) {
      dev.log('DocumentReaderScreen: errore estrazione: $e');
      _loadError = 'Errore apertura file: $e';
    } finally {
      if (mounted) setState(() => _loadingText = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Scroll automatico al chunk corrente
  // ---------------------------------------------------------------------------

  void _scrollToChunk(int index) {
    if (index < 0 || index >= _chunkKeys.length) return;
    final key = _chunkKeys[index];
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.3, // mostra il chunk a ~30% dall'alto
    );
  }

  // ---------------------------------------------------------------------------
  // TTS
  // ---------------------------------------------------------------------------

  Future<String> _voice() async {
    final configured = await _settings.loadTtsVoice();
    if (configured.trim().isNotEmpty) return configured;
    return 'it-IT-ElsaNeural';
  }

  Future<void> _readWithEdgeTts() async {
    if (_chunks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun testo da leggere.')),
      );
      return;
    }

    setState(() {
      _speaking = true;
      _playingChunkIndex = -1;
      _readyChunks = 0;
      _totalChunks = _chunks.length;
      _ttsStatus = 'Preparo lettura Edge TTS a blocchi...';
    });

    try {
      final voice = await _voice();
      final controller = StreamController<(int, File)>();
      Object? generationError;

      // Generazione audio in background
      final generation = Future<void>(() async {
        for (var i = 0; i < _chunks.length; i++) {
          final file =
              await _tts.speakToFile(text: _chunks[i], voice: voice);
          controller.add((i, file));
          if (!mounted) return;
          setState(() {
            _readyChunks = i + 1;
            _ttsStatus =
                'Blocco ${i + 1} di ${_chunks.length} pronto. Lettura in corso...';
          });
        }
        await controller.close();
      }).catchError((e) async {
        generationError = e;
        await controller.close();
      });

      // Riproduzione con avanzamento cursore
      await for (final (index, file) in controller.stream) {
        if (!mounted || !_speaking) break;
        // Aggiorna chunk evidenziato e scrolla
        setState(() {
          _playingChunkIndex = index;
          _ttsStatus = 'Lettura blocco ${index + 1} di $_totalChunks...';
        });
        _scrollToChunk(index);
        await _audio.playFilesSequentially([file]);
      }

      await generation;
      if (generationError != null) throw Exception(generationError);

      if (!mounted) return;
      setState(() {
        _playingChunkIndex = -1;
        _ttsStatus = 'Lettura terminata.';
      });
    } catch (e) {
      dev.log('DocumentReaderScreen TTS error: $e');
      if (!mounted) return;
      setState(() {
        _playingChunkIndex = -1;
        _ttsStatus = 'Errore Edge TTS: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore Edge TTS: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _speaking = false);
      }
    }
  }

  Future<void> _stopReading() async {
    await _audio.stop();
    if (!mounted) return;
    setState(() {
      _speaking = false;
      _playingChunkIndex = -1;
      _ttsStatus = 'Lettura interrotta.';
    });
  }

  // ---------------------------------------------------------------------------
  // Modifica
  // ---------------------------------------------------------------------------

  Future<void> _saveDocument() async {
    final text = _editController.text;
    try {
      final ext = widget.document.extension.toLowerCase();
      String savePath = widget.document.path;
      bool isNewFile = false;

      if (ext != 'txt' && ext != 'md') {
        final originalFile = File(savePath);
        final dir = originalFile.parent.path;
        final nameWithoutExt = widget.document.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        savePath = '$dir/$nameWithoutExt (Modificato).txt';
        isNewFile = true;
      }

      final file = File(savePath);
      await file.writeAsString(text);

      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _documentText = text;
        if (_documentText.isNotEmpty) {
          _chunks = _tts.splitTextForStreaming(
            _documentText,
            maxChunkChars: _maxChunkChars,
          );
          _chunkKeys
            ..clear()
            ..addAll(List.generate(_chunks.length, (_) => GlobalKey()));
        } else {
          _chunks = [];
          _chunkKeys.clear();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNewFile
              ? 'Salvato come nuovo documento di testo nella libreria.'
              : 'Documento salvato con successo.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final doc = widget.document;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          doc.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: _loadingText
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                controller: _scrollController,
                // BouncingScrollPhysics → flick naturale su iPhone
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // --- Intestazione ---
                        Row(
                          children: [
                            _ExtBadge(ext: doc.extension),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    doc.extension.toUpperCase(),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        if (_isEditing) ...[
                          TextField(
                            controller: _editController,
                            maxLines: null,
                            autofocus: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _saveDocument,
                                  icon: const Icon(Icons.save),
                                  label: Text(l10n.save),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => setState(() => _isEditing = false),
                                  icon: const Icon(Icons.cancel),
                                  label: Text(l10n.cancel),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // --- Status TTS ---
                          Semantics(
                            liveRegion: true,
                            child: Text(_ttsStatus ?? 'Pronto.'),
                          ),
                          if (_totalChunks > 0) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _totalChunks > 0
                                  ? _readyChunks / _totalChunks
                                  : 0,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Blocchi audio pronti: $_readyChunks / $_totalChunks',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 12),

                          // --- Pulsanti TTS ---
                          FilledButton.icon(
                            onPressed: _speaking ? null : _readWithEdgeTts,
                            icon: const Icon(Icons.volume_up),
                            label: Text(
                              _speaking
                                  ? 'Lettura in corso...'
                                  : 'Leggi con Edge TTS',
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _speaking ? null : () {
                              _editController.text = _documentText;
                              setState(() => _isEditing = true);
                            },
                            icon: const Icon(Icons.edit),
                            label: Text(l10n.edit),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _speaking ? _stopReading : null,
                            icon: const Icon(Icons.stop),
                            label: const Text('Interrompi lettura'),
                          ),

                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 8),

                          // --- Corpo documento ---
                          if (_loadError != null)
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _loadError!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.secondary,
                                ),
                              ),
                            )
                          else if (_chunks.isNotEmpty)
                            ..._buildChunkWidgets(theme, colorScheme)
                          else if (_documentText.isEmpty && _loadError == null)
                            Text(
                              'Nessun testo disponibile per questo documento.',
                              style: theme.textTheme.bodyMedium,
                            ),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Costruisce la lista di widget per i blocchi di testo.
  /// Il blocco in riproduzione viene evidenziato.
  List<Widget> _buildChunkWidgets(ThemeData theme, ColorScheme colorScheme) {
    final widgets = <Widget>[];
    for (var i = 0; i < _chunks.length; i++) {
      final isPlaying = i == _playingChunkIndex;
      widgets.add(
        Semantics(
          key: _chunkKeys[i],
          container: true,
          liveRegion: isPlaying,
          label: isPlaying ? 'In lettura ' : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isPlaying
                  ? colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isPlaying
                  ? Border.all(
                      color: colorScheme.primary.withAlpha(128),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Text(
              _chunks[i],
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight:
                    isPlaying ? FontWeight.w600 : FontWeight.normal,
                color: isPlaying
                    ? colorScheme.onPrimaryContainer
                    : null,
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}

// ---------------------------------------------------------------------------
// Badge estensione
// ---------------------------------------------------------------------------

class _ExtBadge extends StatelessWidget {
  final String ext;
  const _ExtBadge({required this.ext});

  Color _color() {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Colors.red.shade700;
      case 'epub':
        return Colors.green.shade700;
      case 'docx':
      case 'doc':
        return Colors.blue.shade700;
      case 'txt':
      case 'md':
        return Colors.grey.shade600;
      default:
        return Colors.purple.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: _color(),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        ext.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
