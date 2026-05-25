import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:uuid/uuid.dart';

import '../models/document_item.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';
import '../services/document_library_service.dart';
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

  // TTS state
  bool _speaking = false;
  String? _ttsStatus;
  int _playingChunkIndex = -1;
  final _chunkKeys = <GlobalKey>[];
  late int _bookmarkIndex;

  bool _ttsPaused = false;
  StreamSubscription<bool>? _playingSub;

  static const int _maxChunkChars = 650;

  @override
  void initState() {
    super.initState();
    _bookmarkIndex = widget.document.bookmarkIndex;
    _playingSub = _audio.playingStream.listen((playing) {
      if (_speaking && mounted) {
        setState(() => _ttsPaused = !playing);
      }
    });
    _extractText();
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _audio.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Estrazione testo
  // ---------------------------------------------------------------------------

  Future<void> _extractText() async {
    final ext = widget.document.extension.toLowerCase();
    try {
      final path = await DocumentLibraryService().resolveFilePath(widget.document);
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
      if (mounted) {
        setState(() => _loadingText = false);
        if (_bookmarkIndex > 0 && _bookmarkIndex < _chunks.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToChunk(_bookmarkIndex);
          });
        }
      }
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
    return 'it-IT-IsabellaNeural';
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
      _ttsPaused = false;
      _playingChunkIndex = -1;
      _ttsStatus = null;
    });

    try {
      final voice = await _voice();
      final controller = StreamController<(int, File)>();
      Object? generationError;

      // Generazione audio in background
      final startIndex = _bookmarkIndex < _chunks.length ? _bookmarkIndex : 0;
      final generation = Future<void>(() async {
        for (var i = startIndex; i < _chunks.length; i++) {
          if (!mounted || !_speaking) break; // Ferma la generazione se l'utente preme stop
          final file = await _tts.speakToFile(text: _chunks[i], voice: voice);
          controller.add((i, file));
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
        });
        _scrollToChunk(index);
        await _audio.playFilesSequentially([file]);
      }

      await generation;
      if (generationError != null) throw Exception(generationError);

      if (!mounted) return;
      setState(() {
        _playingChunkIndex = -1;
        _speaking = false;
        _ttsPaused = false;
        _ttsStatus = null;
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
    // Aggiorna subito la UI per un feedback immediato
    setState(() {
      _speaking = false;
      _ttsPaused = false;
      _playingChunkIndex = -1;
      _ttsStatus = 'Lettura interrotta.';
    });
    await _audio.stop();
  }

  // ---------------------------------------------------------------------------
  // Modifica paragrafo singolo
  // ---------------------------------------------------------------------------

  /// Apre un dialog per modificare solo il paragrafo [index].
  /// Dopo la conferma, aggiorna il chunk in memoria e salva immediatamente
  /// su file senza uscire dalla modalità di lettura.
  Future<void> _editParagraph(int index) async {
    if (index < 0 || index >= _chunks.length) return;

    final controller = TextEditingController(text: _chunks[index]);
    final edited = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Modifica paragrafo'),
          content: SizedBox(
            width: double.maxFinite,
            child: Semantics(
              label: 'Campo di testo per la modifica del paragrafo',
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.multiline,
                maxLines: 12,
                minLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Modifica il testo del paragrafo',
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Applica e salva'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (edited == null || !mounted) return;

    // L'utente vuole che un invio (\n) spezzi il paragrafo.
    // Convertiamo eventuali \n singoli in \n\n per farli riconoscere dal TTS.
    final finalEdited = edited.replaceAll(RegExp(r'\n+'), '\n\n');
    final updatedChunks = List<String>.from(_chunks)..[index] = finalEdited;
    
    // Ricostruisce il testo separando i vecchi chunk correttamente
    final newText = updatedChunks.join('\n\n');

    // Salva su file
    try {
      final ext = widget.document.extension.toLowerCase();
      // Risolviamo il percorso assoluto per evitare errori di salvataggio
      final absolutePath = await DocumentLibraryService().resolveFilePath(widget.document);
      String savePath = absolutePath;
      bool isNewFile = false;
      DocumentItem? newDocItem;

      if (ext != 'txt' && ext != 'md') {
        final originalFile = File(savePath);
        final dir = originalFile.parent.path;
        final nameWithoutExt =
            widget.document.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        final newFileName = '$nameWithoutExt (Modificato).txt';
        savePath = '$dir/$newFileName';
        isNewFile = true;
        
        newDocItem = DocumentItem(
          id: const Uuid().v4(),
          name: newFileName,
          path: newFileName,
          extension: 'txt',
          addedAt: DateTime.now(),
        );
      }

      dev.log('DocumentReaderScreen: Salvataggio documento in corso su: $savePath');
      await File(savePath).writeAsString(newText);
      
      if (isNewFile && newDocItem != null) {
        final lib = DocumentLibraryService();
        await lib.load();
        await lib.add(newDocItem);
        dev.log('DocumentReaderScreen: Nuovo file salvato e aggiunto alla libreria come TXT');
      }

      if (!mounted) return;
      // Aggiorna stato: testo e chunk (la lettura riparte dall'inizio se necessario)
      setState(() {
        _documentText = newText;
        _chunks = _tts.splitTextForStreaming(
          _documentText,
          maxChunkChars: _maxChunkChars,
        );
        _chunkKeys
          ..clear()
          ..addAll(List.generate(_chunks.length, (_) => GlobalKey()));
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNewFile
              ? 'Salvato come nuovo file di testo nella libreria.'
              : 'Paragrafo salvato.'),
        ),
      );
    } catch (e) {
      dev.log('DocumentReaderScreen: Errore fatale durante il salvataggio: $e');
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
                cacheExtent:
                    4000, // Precarica i blocchi successivi per VoiceOver
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
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
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

                        if (_ttsStatus != null) ...[
                          Text(_ttsStatus!),
                          const SizedBox(height: 12),
                        ],

                        // --- Pulsanti TTS ---
                        FilledButton.icon(
                          onPressed: () {
                            if (!_speaking) {
                              _readWithEdgeTts();
                            } else if (_ttsPaused) {
                              setState(() => _ttsPaused = false);
                              _audio.play();
                            } else {
                              setState(() => _ttsPaused = true);
                              _audio.pause();
                            }
                          },
                          icon: Icon(!_speaking
                              ? Icons.volume_up
                              : (_ttsPaused
                                  ? Icons.play_arrow
                                  : Icons.pause)),
                          label: Text(!_speaking
                              ? 'Leggi con Edge TTS'
                              : (_ttsPaused
                                  ? 'Riprendi lettura'
                                  : 'Pausa lettura')),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _speaking ? _stopReading : null,
                          icon: const Icon(Icons.stop),
                          label: const Text('Interrompi lettura'),
                        ),

                        const SizedBox(height: 8),
                        // Suggerimento modifica paragrafo (solo in lettura)
                        if (!_speaking && _chunks.isNotEmpty)
                          Semantics(
                            liveRegion: false,
                            child: Text(
                              'Tocca un paragrafo per modificarlo.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
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
                        else if (_documentText.isEmpty &&
                            _loadError == null)
                          Text(
                            'Nessun testo disponibile per questo documento.',
                            style: theme.textTheme.bodyMedium,
                          ),
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
      final isBookmarked = i == _bookmarkIndex;
      // Durante la lettura TTS il tap è disabilitato per non interferire.
      final canEdit = !_speaking;
      widgets.add(
        Semantics(
          key: _chunkKeys[i],
          container: true,
          button: canEdit,
          hint: canEdit 
              ? 'Doppio tap per modificare questo paragrafo. Fai flick verso il basso per aggiungere un segnalibro.' 
              : 'Fai flick verso il basso per aggiungere un segnalibro.',
          customSemanticsActions: {
            const CustomSemanticsAction(label: 'Imposta segnalibro'): () => _setBookmark(i),
          },
          child: GestureDetector(
            onTap: canEdit ? () => _editParagraph(i) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    : (isBookmarked
                        ? Border.all(
                            color: Colors.red.withAlpha(128),
                            width: 1.5,
                          )
                        : null),
              ),
              child: Stack(
                children: [
                  Text(
                    _chunks[i],
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
                      color: isPlaying ? colorScheme.onPrimaryContainer : null,
                    ),
                  ),
                  if (isBookmarked && !isPlaying)
                    const Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(Icons.bookmark, color: Colors.red, size: 16),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Future<void> _setBookmark(int index) async {
    setState(() => _bookmarkIndex = index);
    
    final newDoc = DocumentItem(
      id: widget.document.id,
      name: widget.document.name,
      path: widget.document.path,
      extension: widget.document.extension,
      addedAt: widget.document.addedAt,
      bookmarkIndex: index,
    );
    final lib = DocumentLibraryService();
    await lib.load();
    await lib.update(newDoc);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Segnalibro impostato al paragrafo ${index + 1}.')),
      );
    }
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
