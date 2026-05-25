import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../models/document_item.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';
import '../services/document_library_service.dart';
import '../services/document_text_extractor.dart';
import '../tts/edge_tts_bridge.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

  late DocumentItem _currentDoc;

  @override
  void initState() {
    super.initState();
    _currentDoc = widget.document;
    _bookmarkIndex = _currentDoc.bookmarkIndex;
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
    final ext = _currentDoc.extension.toLowerCase();
    try {
      final editedPath = await DocumentLibraryService().resolveEditedFilePath(_currentDoc);
      if (editedPath != null && await File(editedPath).exists()) {
        _documentText = await File(editedPath).readAsString();
      } else {
        final path = await DocumentLibraryService().resolveFilePath(_currentDoc);
        final result = await _extractor.extract(path: path, extension: ext);
        _documentText = result.text;
        _loadError = result.error;
      }

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
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _scrollToChunk(_bookmarkIndex);
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

  Future<void> _startReading() async {
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
      final engine = await _settings.loadTtsEngine();
      final startIndex = _bookmarkIndex < _chunks.length && _bookmarkIndex >= 0 ? _bookmarkIndex : 0;

      if (engine == 'system') {
        await _flutterTts.awaitSpeakCompletion(true);
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

        for (var i = startIndex; i < _chunks.length; i++) {
          if (!mounted || !_speaking) break;
          
          while (_ttsPaused) {
            await Future.delayed(const Duration(milliseconds: 200));
            if (!mounted || !_speaking) break;
          }
          if (!mounted || !_speaking) break;

          setState(() {
            _playingChunkIndex = i;
          });
          _scrollToChunk(i);
          
          await _flutterTts.speak(_chunks[i]);
          
          if (_ttsPaused) {
            i--; // Ripete il chunk corrente quando si riprende dalla pausa
          }
        }
        await _flutterTts.stop();
      } else {
        final voice = await _voice();
        final controller = StreamController<(int, File)>();
        Object? generationError;

        // Generazione audio in background
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
      }

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
        _ttsStatus = 'Errore sintesi vocale: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore sintesi vocale: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _speaking = false);
      }
    }
  }

  final _flutterTts = FlutterTts();

  Future<void> _stopReading() async {
    // Aggiorna subito la UI per un feedback immediato
    setState(() {
      _speaking = false;
      _ttsPaused = false;
      _playingChunkIndex = -1;
      _ttsStatus = 'Lettura interrotta.';
    });
    await _audio.stop();
    await _flutterTts.stop();
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
    // Convertiamo eventuali \n o \r\n in doppi a capo per farli riconoscere dal TTS.
    final normalized = edited.replaceAll('\r\n', '\n');
    final finalEdited = normalized.replaceAll(RegExp(r'\n+'), '\n\n');
    final updatedChunks = List<String>.from(_chunks)..[index] = finalEdited;
    
    // Ricostruisce il testo separando i vecchi chunk correttamente
    final newText = updatedChunks.join('\n\n');

    // Salva su file
    try {
      final dir = await getApplicationDocumentsDirectory();
      final editedFileName = '${_currentDoc.id}_edited.txt';
      final file = File(p.join(dir.path, editedFileName));
      await file.writeAsString(newText);

      // 4. Aggiorna l'elemento DocumentItem
      final newDoc = DocumentItem(
        id: _currentDoc.id,
        name: _currentDoc.name,
        path: _currentDoc.path,
        extension: _currentDoc.extension,
        addedAt: _currentDoc.addedAt,
        bookmarkIndex: _bookmarkIndex,
        editedTextPath: file.path,
        isTemporary: _currentDoc.isTemporary,
      );

      setState(() {
        _currentDoc = newDoc;
      });

      if (!_currentDoc.isTemporary) {
        final lib = DocumentLibraryService();
        await lib.load();
        await lib.update(newDoc);
      }
      dev.log('DocumentReaderScreen: DocumentItem aggiornato con editedTextPath');

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
        const SnackBar(
          content: Text('Testo modificato e salvato nel documento corrente.'),
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
    final doc = _currentDoc;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          doc.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (doc.isTemporary)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Salva nella libreria',
              onPressed: () async {
                final newDoc = DocumentItem(
                  id: doc.id,
                  name: doc.name,
                  path: doc.path,
                  extension: doc.extension,
                  addedAt: doc.addedAt,
                  bookmarkIndex: doc.bookmarkIndex,
                  editedTextPath: doc.editedTextPath,
                  isTemporary: false,
                );
                final lib = DocumentLibraryService();
                await lib.load();
                await lib.add(newDoc);
                setState(() {
                  _currentDoc = newDoc;
                });
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Documento salvato nella libreria')),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Esporta / Condividi',
            onPressed: _exportDocument,
          ),
        ],
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
                                    doc.extension.toUpperCase() +
                                        (doc.editedTextPath != null ? ' (Modificato in Sonarpad)' : ''),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: doc.editedTextPath != null ? Colors.orange.shade700 : null,
                                      fontWeight: doc.editedTextPath != null ? FontWeight.bold : null,
                                    ),
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
                              _startReading();
                            } else if (_ttsPaused) {
                              setState(() => _ttsPaused = false);
                              _audio.play(); // No-op if system TTS
                            } else {
                              setState(() => _ttsPaused = true);
                              _audio.pause(); // No-op if system TTS
                              _flutterTts.stop(); // Interrompe il chunk corrente, il while() fermerà il loop
                            }
                          },
                          icon: Icon(!_speaking
                              ? Icons.volume_up
                              : (_ttsPaused
                                  ? Icons.play_arrow
                                  : Icons.pause)),
                          label: Text(!_speaking
                              ? 'Inizia lettura'
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

                        if (!_speaking && _documentText.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _exportDocument,
                            icon: const Icon(Icons.share),
                            label: const Text('Esporta documento'),
                          ),
                        ],

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
      
      String hintText = canEdit ? 'Doppio tap per modificare questo paragrafo. ' : '';
      if (_bookmarkIndex > 0) {
        hintText += 'Fai flick verso il basso per rimuovere o andare al segnalibro esistente.';
      } else {
        hintText += 'Fai flick verso il basso per impostare un segnalibro.';
      }

      final Map<CustomSemanticsAction, VoidCallback> actions = {};
      if (_bookmarkIndex > 0) {
        actions[const CustomSemanticsAction(label: 'Rimuovi segnalibro')] = () => _removeBookmark();
        actions[const CustomSemanticsAction(label: 'Vai al segnalibro')] = () => _scrollToChunk(_bookmarkIndex);
      } else {
        actions[const CustomSemanticsAction(label: 'Imposta segnalibro')] = () => _setBookmark(i);
      }

      widgets.add(
        Semantics(
          key: _chunkKeys[i],
          container: true,
          button: canEdit,
          hint: hintText,
          customSemanticsActions: actions,
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
      id: _currentDoc.id,
      name: _currentDoc.name,
      path: _currentDoc.path,
      extension: _currentDoc.extension,
      addedAt: _currentDoc.addedAt,
      bookmarkIndex: index,
      editedTextPath: _currentDoc.editedTextPath,
      isTemporary: _currentDoc.isTemporary,
    );
    
    setState(() {
      _currentDoc = newDoc;
    });

    if (!_currentDoc.isTemporary) {
      final lib = DocumentLibraryService();
      await lib.load();
      await lib.update(newDoc);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Segnalibro impostato al paragrafo ${index + 1}.')),
      );
    }
  }

  Future<void> _removeBookmark() async {
    setState(() => _bookmarkIndex = -1);
    
    final newDoc = DocumentItem(
      id: _currentDoc.id,
      name: _currentDoc.name,
      path: _currentDoc.path,
      extension: _currentDoc.extension,
      addedAt: _currentDoc.addedAt,
      bookmarkIndex: 0, // Reset to 0 (default)
      editedTextPath: _currentDoc.editedTextPath,
      isTemporary: _currentDoc.isTemporary,
    );
    
    setState(() {
      _currentDoc = newDoc;
    });

    if (!_currentDoc.isTemporary) {
      final lib = DocumentLibraryService();
      await lib.load();
      await lib.update(newDoc);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Segnalibro rimosso.')),
      );
    }
  }

  Future<void> _exportDocument() async {
    // Mostriamo sempre un dialogo per scegliere il formato
    String? format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Esporta documento'),
        content: const Text('In quale formato desideri esportare il documento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'txt'),
            child: const Text('Testo (.txt)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'pdf'),
            child: const Text('PDF (.pdf)'),
          ),
        ],
      ),
    );

    if (format == null || !mounted) return;

    try {
      final appDir = await getTemporaryDirectory();
      final baseName = _currentDoc.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      
      if (format == 'txt') {
        final path = '${appDir.path}/${baseName}_export.txt';
        await File(path).writeAsString(_documentText);
        await Share.shareXFiles([XFile(path)], text: 'Documento esportato da Sonarpad');
      } else if (format == 'pdf') {
        final path = await _generatePdf(baseName, _documentText, appDir.path);
        await Share.shareXFiles([XFile(path)], text: 'Documento esportato da Sonarpad');
      }
    } catch (e) {
      dev.log('Errore durante l\'esportazione: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore esportazione: $e')),
        );
      }
    }
  }

  Future<String> _generatePdf(String baseName, String text, String outDir) async {
    final PdfDocument document = PdfDocument();
    final PdfPage page = document.pages.add();
    final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);
    
    final PdfTextElement element = PdfTextElement(
      text: text,
      font: font,
    );
    
    element.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
      format: PdfLayoutFormat(
        layoutType: PdfLayoutType.paginate,
      ),
    );

    final path = '$outDir/${baseName}_export.pdf';
    final List<int> bytes = await document.save();
    document.dispose();
    
    await File(path).writeAsBytes(bytes);
    return path;
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
