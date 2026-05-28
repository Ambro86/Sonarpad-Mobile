import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import '../l10n/app_localizations.dart';
import '../models/document_item.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';
import '../services/document_library_service.dart';
import '../services/document_text_extractor.dart';
import '../tts/edge_tts_bridge.dart';
import '../utils/app_logger.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  final _scrollController = AutoScrollController();

  // Testo e chunks
  bool _loadingText = true;
  String _documentText = '';
  String? _loadError;
  List<String> _chunks = [];

  // TTS state
  bool _speaking = false;
  String? _ttsStatus;
  int _playingChunkIndex = -1;
  // (chunkKeys rimosso, usiamo scroll_to_index)
  late int _bookmarkIndex;

  bool _ttsPaused = false;
  String? _activeTtsEngine;
  StreamSubscription<bool>? _playingSub;

  static const int _maxChunkChars = 650;

  late DocumentItem _currentDoc;

  static const _ttsCommands = MethodChannel('sonarpad/tts_commands');
  static const _ttsEvents = EventChannel('sonarpad/tts_events');
  StreamSubscription? _ttsEventsSub;

  @override
  void initState() {
    super.initState();
    _currentDoc = widget.document;
    _bookmarkIndex = _currentDoc.bookmarkIndex;
    _playingSub = _audio.playingStream.listen((playing) {
      if (_speaking && _activeTtsEngine != 'system' && mounted) {
        setState(() => _ttsPaused = !playing);
      }
    });
    _flutterTts.setPauseHandler(() {
      if (mounted && _speaking) setState(() => _ttsPaused = true);
    });
    _flutterTts.setContinueHandler(() {
      if (mounted && _speaking) setState(() => _ttsPaused = false);
    });

    _ttsEventsSub = _ttsEvents.receiveBroadcastStream().listen((event) {
      if (event == 'toggle' && mounted) {
        _togglePlayPause();
      }
    });

    _extractText();
  }

  @override
  void dispose() {
    if (Platform.isIOS) {
      _ttsCommands.invokeMethod('clearMagicTap').catchError((_) {});
    }
    _ttsEventsSub?.cancel();
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
      final editedPath =
          await DocumentLibraryService().resolveEditedFilePath(_currentDoc);
      if (editedPath != null && await File(editedPath).exists()) {
        _documentText = await File(editedPath).readAsString();
      } else {
        final path =
            await DocumentLibraryService().resolveFilePath(_currentDoc);
        final result = await _extractor.extract(path: path, extension: ext);
        _documentText = result.text;
        _loadError = result.error;
      }

      if (_documentText.isNotEmpty) {
        _chunks = _tts.splitTextForStreaming(
          _documentText,
          maxChunkChars: _maxChunkChars,
        );
        // Le chiavi vengono gestite da AutoScrollTag
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
    if (index < 0 || index >= _chunks.length) return;
    _scrollController.scrollToIndex(
      index,
      preferPosition: AutoScrollPosition.begin,
      duration: const Duration(milliseconds: 350),
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
      _activeTtsEngine = engine;
      final startIndex = _bookmarkIndex < _chunks.length && _bookmarkIndex >= 0
          ? _bookmarkIndex
          : 0;

      if (engine == 'system') {
        if (Platform.isIOS) {
          try {
            await _ttsCommands.invokeMethod('setupMagicTap', _currentDoc.name);
          } catch (e) {
            dev.log('DocumentReaderScreen: Errore setupMagicTap $e');
          }
        }
        await _configureSystemTtsAudioSession();
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
        }
        await _flutterTts.stop();
      } else {
        final voice = await _voice();
        final controller = StreamController<(int, File)>();
        Object? generationError;

        // Generazione audio in background
        final generation = Future<void>(() async {
          for (var i = startIndex; i < _chunks.length; i++) {
            if (!mounted || !_speaking) {
              break; // Ferma la generazione se l'utente preme stop
            }
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

      if (Platform.isIOS && engine == 'system') {
        try {
          await _ttsCommands.invokeMethod('clearMagicTap');
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _playingChunkIndex = -1;
        _speaking = false;
        _ttsPaused = false;
        _activeTtsEngine = null;
        _ttsStatus = null;
      });
    } catch (e) {
      dev.log('DocumentReaderScreen TTS error: $e');
      await AppLogger.log('Errore avvio TTS: $e');
      if (!mounted) return;
      setState(() {
        _playingChunkIndex = -1;
        _ttsStatus = 'Errore sintesi vocale: $e';
        _activeTtsEngine = null;
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

  Future<void> _configureSystemTtsAudioSession() async {
    if (!Platform.isIOS) return;

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    await _flutterTts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      ],
      IosTextToSpeechAudioMode.defaultMode,
    );
    await session.setActive(true);
  }

  Future<void> _stopReading() async {
    await _saveAutomaticBookmarkFromPlayback();
    if (Platform.isIOS && _activeTtsEngine == 'system') {
      try {
        await _ttsCommands.invokeMethod('clearMagicTap');
      } catch (_) {}
    }
    // Aggiorna subito la UI per un feedback immediato
    setState(() {
      _speaking = false;
      _ttsPaused = false;
      _activeTtsEngine = null;
      _playingChunkIndex = -1;
      _ttsStatus = 'Lettura interrotta.';
    });
    await _audio.stop();
    await _flutterTts.stop();
  }

  Future<void> _saveAutomaticBookmarkFromPlayback() async {
    if (_playingChunkIndex < 0 || _playingChunkIndex >= _chunks.length) {
      return;
    }
    if (!await _settings.isAutoBookmarkEnabled()) {
      return;
    }
    await _saveBookmark(_playingChunkIndex, showSnack: false);
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
      final lib = DocumentLibraryService();
      final editedPath = await lib.saveEditedText(_currentDoc, newText);

      // 4. Aggiorna l'elemento DocumentItem
      final newDoc = DocumentItem(
        id: _currentDoc.id,
        name: _currentDoc.name,
        path: _currentDoc.path,
        extension: _currentDoc.extension,
        addedAt: _currentDoc.addedAt,
        bookmarkIndex: _bookmarkIndex,
        editedTextPath: editedPath,
        isTemporary: _currentDoc.isTemporary,
      );

      setState(() {
        _currentDoc = newDoc;
      });

      if (!_currentDoc.isTemporary) {
        await lib.load();
        await lib.update(newDoc);
      }
      dev.log(
          'DocumentReaderScreen: DocumentItem aggiornato con editedTextPath');

      if (!mounted) return;
      // Aggiorna stato: testo e chunk (la lettura riparte dall'inizio se necessario)
      setState(() {
        _documentText = newText;
        _chunks = _tts.splitTextForStreaming(
          _documentText,
          maxChunkChars: _maxChunkChars,
        );
        // Chiavi gestite da AutoScrollTag
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

  Future<void> _togglePlayPause() async {
    if (!_speaking) {
      await _startReading();
    } else if (_ttsPaused) {
      await _resumeReading();
    } else {
      await _pauseReading();
    }
  }

  Future<void> _pauseReading() async {
    if (!_speaking || _ttsPaused) return;
    if (mounted) setState(() => _ttsPaused = true);

    if (_activeTtsEngine == 'system') {
      await _flutterTts.pause();
    } else {
      await _audio.pause();
    }
  }

  Future<void> _resumeReading() async {
    if (!_speaking || !_ttsPaused) return;
    if (mounted) setState(() => _ttsPaused = false);

    if (_activeTtsEngine == 'system') {
      unawaited(
        _flutterTts.speak('').catchError((Object error) {
          dev.log('DocumentReaderScreen system TTS resume error: $error');
          return null;
        }),
      );
    } else {
      await _audio.play();
    }
  }

  void _scrollDocumentByPage(double direction) {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final distance = position.viewportDimension * 0.85 * direction;
    final target = (position.pixels + distance)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    if ((target - position.pixels).abs() < 1) {
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          direction > 0 ? 'Fine documento' : 'Inizio documento',
          Directionality.of(context),
        ).catchError((Object error) {
          dev.log('DocumentReaderScreen semantic announcement error: $error');
        }),
      );
      return;
    }

    unawaited(
      _scrollController
          .animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      )
          .catchError((Object error) {
        dev.log('DocumentReaderScreen semantic scroll error: $error');
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final doc = _currentDoc;
    final displayName = doc.displayName;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          displayName,
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
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Documento salvato nella libreria')),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _loadingText
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_ttsStatus != null) ...[
                          Text(_ttsStatus!),
                          const SizedBox(height: 12),
                        ],
                        FilledButton.icon(
                          onPressed: _togglePlayPause,
                          icon: Icon(!_speaking
                              ? Icons.volume_up
                              : (_ttsPaused ? Icons.play_arrow : Icons.pause)),
                          label: Text(!_speaking
                              ? 'Avvia lettura'
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
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Semantics(
                      label: 'Testo documento',
                      explicitChildNodes: true,
                      onScrollUp: () => _scrollDocumentByPage(1),
                      onScrollDown: () => _scrollDocumentByPage(-1),
                      child: CustomScrollView(
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
                                            displayName,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                          ),
                                          Text(
                                            doc.extension.toUpperCase() +
                                                (doc.editedTextPath != null
                                                    ? ' (Modificato in Sonarpad)'
                                                    : ''),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: doc.editedTextPath != null
                                                  ? Colors.orange.shade700
                                                  : null,
                                              fontWeight:
                                                  doc.editedTextPath != null
                                                      ? FontWeight.bold
                                                      : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Suggerimento modifica paragrafo (solo in lettura)
                                if (!_speaking && _chunks.isNotEmpty)
                                  Semantics(
                                    liveRegion: false,
                                    child: Text(
                                      l10n.documentReaderEditHint,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
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
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
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

      String hintText =
          canEdit ? 'Doppio tap per modificare questo paragrafo. ' : '';
      if (_bookmarkIndex > 0) {
        hintText +=
            'Fai flick verso il basso per rimuovere o andare al segnalibro esistente.';
      } else {
        hintText += 'Fai flick verso il basso per impostare un segnalibro.';
      }

      final Map<CustomSemanticsAction, VoidCallback> actions = {};
      if (_bookmarkIndex > 0) {
        actions[const CustomSemanticsAction(label: 'Rimuovi segnalibro')] =
            () => _removeBookmark();
        actions[const CustomSemanticsAction(label: 'Vai al segnalibro')] =
            () => _scrollToChunk(_bookmarkIndex);
      } else {
        actions[const CustomSemanticsAction(label: 'Imposta segnalibro')] =
            () => _setBookmark(i);
      }

      widgets.add(
        AutoScrollTag(
          key: ValueKey(i),
          controller: _scrollController,
          index: i,
          child: Semantics(
            container: true,
            hint: hintText,
            onTap: canEdit ? () => _editParagraph(i) : null,
            customSemanticsActions: actions,
            child: GestureDetector(
              excludeFromSemantics: true,
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
                        fontWeight:
                            isPlaying ? FontWeight.w600 : FontWeight.normal,
                        color:
                            isPlaying ? colorScheme.onPrimaryContainer : null,
                      ),
                    ),
                    if (isBookmarked && !isPlaying)
                      const Positioned(
                        top: 0,
                        right: 0,
                        child:
                            Icon(Icons.bookmark, color: Colors.red, size: 16),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Future<void> _setBookmark(int index) async {
    await _saveBookmark(index, showSnack: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Segnalibro impostato al paragrafo ${index + 1}.')),
      );
    }
  }

  Future<void> _saveBookmark(int index, {required bool showSnack}) async {
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

    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Segnalibro impostato al paragrafo ${index + 1}.')),
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
