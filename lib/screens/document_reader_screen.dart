import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:path_provider/path_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/document_item.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';
import '../services/document_library_service.dart';
import '../services/document_text_extractor.dart';
import '../services/voice_dictionary_service.dart';
import '../tts/edge_tts_bridge.dart';
import '../tts/pocket_tts_bridge.dart';
import '../utils/app_logger.dart';
import '../utils/document_unicode_normalizer.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/status_message.dart';

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
  final _pocketTts = PocketTtsBridge();
  final _settings = AppSettingsService();
  final _extractor = DocumentTextExtractor();
  final _voiceDictionary = VoiceDictionaryService();
  final _scrollController = AutoScrollController();

  // Testo e chunks
  bool _loadingText = true;
  String _documentText = '';
  String? _loadError;
  List<String> _chunks = [];
  List<DocumentTableOfContentsEntry> _documentIndex = [];
  String? _epubIndexSourcePath;
  bool _documentIndexLoading = false;

  // TTS state
  bool _speaking = false;
  int _readingToken = 0;
  int _documentSeekToken = 0;
  String? _ttsStatus;
  Timer? _readingSleepTimer;
  int _documentReadingSleepTimerMinutes =
      AppSettingsService.defaultDocumentReadingSleepTimerMinutes;
  int _playingChunkIndex = -1;
  StreamController<File>? _edgeFileController;
  // (chunkKeys rimosso, usiamo scroll_to_index)
  late int _bookmarkIndex;
  late bool _hasBookmark;
  List<int> _bookmarkIndexes = const <int>[];
  bool _multipleDocumentBookmarksEnabled = false;
  int _documentSliderStepPercent =
      AppSettingsService.defaultDocumentSliderStepPercent;

  bool _ttsPaused = false;
  String? _activeTtsEngine;
  bool _systemTtsResumeInProgress = false;
  StreamSubscription<bool>? _playingSub;

  static const int _maxChunkChars = 650;
  static const int _epubIndexCacheVersion = 1;

  late DocumentItem _currentDoc;

  static const _ttsCommands = MethodChannel('sonarpad/tts_commands');
  static const _ttsEvents = EventChannel('sonarpad/tts_events');
  StreamSubscription? _ttsEventsSub;

  @override
  void initState() {
    super.initState();
    _currentDoc = widget.document;
    _bookmarkIndex = _currentDoc.bookmarkIndex;
    _hasBookmark = _currentDoc.bookmarkIndex > 0;
    _bookmarkIndexes = _normalizeBookmarkIndexes(_currentDoc.bookmarkIndexes);
    _playingSub = _audio.playingStream.listen((playing) {
      if (_speaking && _activeTtsEngine != 'system' && mounted) {
        setState(() => _ttsPaused = !playing);
      }
    });
    _flutterTts.setPauseHandler(() {
      if (!mounted || !_speaking) return;
      setState(() => _ttsPaused = true);
      unawaited(_saveAutomaticBookmarkFromPlayback());
      if (Platform.isIOS && _activeTtsEngine == 'system') {
        unawaited(_setMagicTapPlaying(false));
      }
    });
    _flutterTts.setContinueHandler(() {
      if (!mounted || !_speaking) return;
      if (_activeTtsEngine == 'system') {
        unawaited(_resumeReading());
      } else {
        setState(() => _ttsPaused = false);
      }
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
    _cancelReadingSleepTimer();
    unawaited(_audio.stopAndDispose());
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Estrazione testo
  // ---------------------------------------------------------------------------

  Future<void> _extractText() async {
    final l10n = AppLocalizations.of(context);
    final ext = _currentDoc.extension.toLowerCase();
    String? originalPath;
    var usesEditedText = false;
    var includeEpubFootnotes = false;
    final multipleDocumentBookmarks =
        await _settings.multipleDocumentBookmarksEnabled();
    final documentSliderStepPercent =
        await _settings.loadDocumentSliderStepPercent();
    final documentReadingSleepTimerMinutes =
        await _settings.loadDocumentReadingSleepTimerMinutes();
    try {
      final editedPath =
          await DocumentLibraryService().resolveEditedFilePath(_currentDoc);
      if (editedPath != null && await File(editedPath).exists()) {
        usesEditedText = true;
        _documentText = normalizeDocumentUnicode(
          await File(editedPath).readAsString(),
        );
      } else {
        final path =
            await DocumentLibraryService().resolveFilePath(_currentDoc);
        originalPath = path;
        includeEpubFootnotes = ext == 'epub' &&
            await _settings.includeEpubFootnotesInText();
        final result = await _extractor.extract(
          path: path,
          extension: ext,
          includeEpubFootnotesInText: includeEpubFootnotes,
          footnoteLabel: l10n.documentFootnoteLabel,
        );
        _documentText = normalizeDocumentUnicode(result.text);
        _loadError = result.error;
      }

      if (_documentText.isNotEmpty) {
        _chunks = _splitDocumentTextForDisplay(
          _documentText,
          extension: ext,
          includeEpubFootnotesInText: includeEpubFootnotes,
          footnoteLabel: l10n.documentFootnoteLabel,
        );
        _multipleDocumentBookmarksEnabled = multipleDocumentBookmarks;
        _documentSliderStepPercent = documentSliderStepPercent;
        _documentReadingSleepTimerMinutes = documentReadingSleepTimerMinutes;
        _refreshBookmarkStateForCurrentMode();
        // Le chiavi vengono gestite da AutoScrollTag
      }

      if (ext == 'epub' &&
          !usesEditedText &&
          originalPath != null &&
          _chunks.isNotEmpty) {
        // Non calcoliamo qui l'indice EPUB: su alcuni libri grandi l'analisi
        // NCX/nav/ancore interne rallenta l'apertura. Salviamo solo il path e
        // carichiamo l'indice al tap sul pulsante Indice.
        _epubIndexSourcePath = originalPath;
      }
    } catch (e) {
      dev.log('DocumentReaderScreen: errore estrazione: $e');
      _loadError = l10n.fileOpenError(e);
    } finally {
      if (mounted) {
        setState(() => _loadingText = false);
        final shouldScrollToBookmark =
            _bookmarkIndex > 0 && _bookmarkIndex < _chunks.length;
        if (shouldScrollToBookmark) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _scrollToChunk(_bookmarkIndex);
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_resolveDisabledMultipleBookmarksIfNeeded());
          }
        });
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

  List<String> _splitTextForDocumentDisplay(String text) {
    final chunks = _tts.splitTextForStreaming(
      text,
      maxChunkChars: _maxChunkChars,
    );
    return _mergeOrphanPunctuationChunksForDisplay(chunks);
  }

  List<String> _mergeOrphanPunctuationParagraphsForDisplay(
    List<String> paragraphs,
  ) {
    if (paragraphs.isEmpty) return const <String>[];
    final result = <String>[];
    for (final paragraph in paragraphs) {
      final cleaned = paragraph.trim();
      if (cleaned.isEmpty) continue;
      if (_isOrphanPunctuationFragment(cleaned) && result.isNotEmpty) {
        result[result.length - 1] = _appendPunctuationFragmentForDisplay(
          result.last,
          cleaned,
        );
      } else {
        result.add(cleaned);
      }
    }
    return result;
  }

  List<String> _mergeOrphanPunctuationChunksForDisplay(List<String> chunks) {
    if (chunks.isEmpty) return const <String>[];
    final result = <String>[];
    for (final chunk in chunks) {
      final cleaned = chunk.trim();
      if (cleaned.isEmpty) continue;
      if (_isOrphanPunctuationFragment(cleaned) && result.isNotEmpty) {
        result[result.length - 1] = _appendPunctuationFragmentForDisplay(
          result.last,
          cleaned,
        );
      } else {
        result.add(cleaned);
      }
    }
    return result;
  }

  bool _isOrphanPunctuationFragment(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty || compact.length > 12) return false;

    // Evita chunk/paragrafi autonomi composti solo da chiusure o punteggiatura,
    // per esempio ")." o "]". Non include separatori come *** o ---.
    return RegExp(r'''^[\)\]\}»”’"'.,;:!?…]+$''').hasMatch(compact);
  }

  String _appendPunctuationFragmentForDisplay(
    String base,
    String fragment,
  ) {
    final cleanedBase = base.trimRight();
    final cleanedFragment = fragment.trimLeft();
    if (cleanedBase.isEmpty) return cleanedFragment;
    if (cleanedFragment.isEmpty) return cleanedBase;
    return '$cleanedBase$cleanedFragment';
  }

  List<String> _splitDocumentTextForDisplay(
    String text, {
    required String extension,
    required bool includeEpubFootnotesInText,
    required String footnoteLabel,
  }) {
    if (extension.toLowerCase() != 'epub' || !includeEpubFootnotesInText) {
      return _splitTextForDocumentDisplay(text);
    }

    return _splitEpubTextWithInlineFootnotesForDisplay(
      text,
      footnoteLabel: footnoteLabel,
    );
  }

  List<String> _splitEpubTextWithInlineFootnotesForDisplay(
    String text, {
    required String footnoteLabel,
  }) {
    final normalizedText = text.replaceAll('\r\n', '\n');
    final rawParagraphs = _mergeOrphanPunctuationParagraphsForDisplay(
      normalizedText
          .split(RegExp(r'\n{2,}'))
          .map(_cleanDocumentParagraphForDisplay)
          .where((paragraph) => paragraph.isNotEmpty)
          .toList(),
    );
    if (rawParagraphs.isEmpty) return const <String>[];

    final chunks = <String>[];
    var index = 0;
    while (index < rawParagraphs.length) {
      final paragraph = rawParagraphs[index];
      final paragraphNoteNumber =
          _epubFootnoteNumberFromParagraph(paragraph, footnoteLabel);

      // Se troviamo una nota orfana, la manteniamo dov'è: meglio non
      // rischiare di spostare una nota senza il suo paragrafo di riferimento.
      if (paragraphNoteNumber != null) {
        chunks.addAll(_splitTextForDocumentDisplay(paragraph));
        index++;
        continue;
      }

      final followingFootnotes = <String>[];
      var next = index + 1;
      while (next < rawParagraphs.length &&
          _epubFootnoteNumberFromParagraph(
                rawParagraphs[next],
                footnoteLabel,
              ) !=
              null) {
        followingFootnotes.add(rawParagraphs[next]);
        next++;
      }

      final paragraphChunks = _splitTextForDocumentDisplay(paragraph);
      if (paragraphChunks.isEmpty) {
        index = next;
        continue;
      }

      if (followingFootnotes.isEmpty) {
        chunks.addAll(paragraphChunks);
        index = next;
        continue;
      }

      chunks.addAll(_insertEpubFootnotesAfterReferenceChunks(
        paragraphChunks,
        followingFootnotes,
        footnoteLabel: footnoteLabel,
      ));
      index = next;
    }

    return chunks;
  }

  List<String> _insertEpubFootnotesAfterReferenceChunks(
    List<String> paragraphChunks,
    List<String> footnoteParagraphs, {
    required String footnoteLabel,
  }) {
    final footnotesByChunkIndex = <int, List<String>>{};
    var lastTargetIndex = 0;

    for (var noteOrder = 0; noteOrder < footnoteParagraphs.length; noteOrder++) {
      final footnote = footnoteParagraphs[noteOrder];
      final number = _epubFootnoteNumberFromParagraph(
            footnote,
            footnoteLabel,
          ) ??
          '';
      final targetIndex = _findChunkIndexForEpubFootnoteReference(
        paragraphChunks,
        number,
        startIndex: lastTargetIndex,
        fallbackOrder: noteOrder,
      );
      lastTargetIndex = targetIndex;
      footnotesByChunkIndex
          .putIfAbsent(targetIndex, () => <String>[])
          .add(footnote);
    }

    final result = <String>[];
    for (var i = 0; i < paragraphChunks.length; i++) {
      result.add(paragraphChunks[i]);
      final notes = footnotesByChunkIndex[i];
      if (notes == null) continue;
      for (final note in notes) {
        result.addAll(_splitTextForDocumentDisplay(note));
      }
    }
    return result;
  }

  int _findChunkIndexForEpubFootnoteReference(
    List<String> chunks,
    String number, {
    required int startIndex,
    required int fallbackOrder,
  }) {
    if (chunks.isEmpty) return 0;
    final safeStart = startIndex.clamp(0, chunks.length - 1).toInt();

    if (number.trim().isNotEmpty) {
      for (var i = safeStart; i < chunks.length; i++) {
        if (_chunkContainsEpubFootnoteReference(chunks[i], number)) return i;
      }
      for (var i = 0; i < safeStart; i++) {
        if (_chunkContainsEpubFootnoteReference(chunks[i], number)) return i;
      }
    }

    final fallback = safeStart + fallbackOrder;
    if (fallback >= chunks.length) return chunks.length - 1;
    return fallback;
  }

  bool _chunkContainsEpubFootnoteReference(String chunk, String number) {
    final trimmedNumber = number.trim();
    if (trimmedNumber.isEmpty) return false;
    if (_containsTokenWithDigitBoundaries(chunk, trimmedNumber)) return true;

    final superscript = _toSuperscriptDigits(trimmedNumber);
    if (superscript != trimmedNumber &&
        _containsTokenWithDigitBoundaries(chunk, superscript)) {
      return true;
    }
    return false;
  }

  bool _containsTokenWithDigitBoundaries(String text, String token) {
    if (token.isEmpty) return false;
    var start = 0;
    while (start < text.length) {
      final index = text.indexOf(token, start);
      if (index < 0) return false;
      final before = index == 0 ? null : text.codeUnitAt(index - 1);
      final afterIndex = index + token.length;
      final after = afterIndex >= text.length ? null : text.codeUnitAt(afterIndex);
      if (!_isAsciiDigit(before) && !_isAsciiDigit(after)) return true;
      start = index + token.length;
    }
    return false;
  }

  bool _isAsciiDigit(int? codeUnit) {
    if (codeUnit == null) return false;
    return codeUnit >= 48 && codeUnit <= 57;
  }

  String _toSuperscriptDigits(String value) {
    const superscriptDigits = {
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹',
    };
    final buffer = StringBuffer();
    for (final unit in value.split('')) {
      buffer.write(superscriptDigits[unit] ?? unit);
    }
    return buffer.toString();
  }

  String _cleanDocumentParagraphForDisplay(String paragraph) {
    return paragraph
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('...', '…')
        .trim();
  }

  String? _epubFootnoteNumberFromParagraph(
    String paragraph,
    String footnoteLabel,
  ) {
    final label = footnoteLabel.trim();
    if (label.isEmpty) return null;
    final cleaned = _cleanDocumentParagraphForDisplay(paragraph);
    final match = RegExp(
      '^${RegExp.escape(label)}(?:\\s+([^:：]+))?\\s*[:：]',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (match == null) return null;
    return (match.group(1) ?? '').trim();
  }

  List<int> _normalizeBookmarkIndexes(
    List<int> indexes, {
    int? fallbackIndex,
  }) {
    final normalized = <int>[];
    void addIndex(int value) {
      if (value < 0) return;
      if (_chunks.isNotEmpty && value >= _chunks.length) return;
      if (!normalized.contains(value)) normalized.add(value);
    }

    for (final index in indexes) {
      addIndex(index);
    }
    if (normalized.isEmpty && fallbackIndex != null) {
      addIndex(fallbackIndex);
    }
    return List<int>.unmodifiable(normalized);
  }

  int _validAutomaticBookmarkIndex(int index) {
    if (index < 0) return 0;
    if (_chunks.isNotEmpty && index >= _chunks.length) return 0;
    return index;
  }

  int _preferredMultipleBookmarkResumeIndex(
    List<int> manualBookmarks, {
    required int automaticIndex,
  }) {
    var preferredIndex = _validAutomaticBookmarkIndex(automaticIndex);
    for (final bookmarkIndex in manualBookmarks) {
      if (bookmarkIndex > preferredIndex) {
        preferredIndex = bookmarkIndex;
      }
    }
    return preferredIndex;
  }

  int _storedAutomaticBookmarkIndexForDocumentSave() {
    if (!_multipleDocumentBookmarksEnabled) return _bookmarkIndex;
    return _validAutomaticBookmarkIndex(_currentDoc.bookmarkIndex);
  }

  void _refreshBookmarkStateForCurrentMode() {
    final normalized = _normalizeBookmarkIndexes(_currentDoc.bookmarkIndexes);
    _bookmarkIndexes = normalized;

    if (_multipleDocumentBookmarksEnabled) {
      // Con i segnalibri multipli, bookmarkIndex resta salvato come punto
      // automatico di ripresa lettura. All'apertura, però, Sonarpad si
      // posiziona sul punto più avanzato tra ripresa automatica e segnalibri
      // manuali, senza aggiungere il punto automatico alla lista manuale.
      _bookmarkIndex = _preferredMultipleBookmarkResumeIndex(
        normalized,
        automaticIndex: _currentDoc.bookmarkIndex,
      );
      _hasBookmark = _bookmarkIndex > 0;
      return;
    }

    _bookmarkIndex = _currentDoc.bookmarkIndex;
    _hasBookmark = _currentDoc.bookmarkIndex > 0;
  }

  String get _goToBookmarkActionLabel =>
      AppLocalizations.of(context).documentGoToBookmarkAction;

  String get _bookmarkDialogTitle =>
      AppLocalizations.of(context).documentChooseBookmarkTitle;

  String get _deleteBookmarkActionLabel =>
      AppLocalizations.of(context).documentDeleteBookmarkAction;

  String get _keepBookmarkDialogTitle =>
      AppLocalizations.of(context).documentKeepBookmarkTitle;

  String get _keepBookmarkDialogMessage =>
      AppLocalizations.of(context).documentKeepBookmarkMessage;

  String _bookmarkChoiceLabel(int index, int order) {
    final paragraph = index + 1;
    final raw = (index >= 0 && index < _chunks.length) ? _chunks[index] : '';
    final preview = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final shortPreview = preview.length > 80 ? '${preview.substring(0, 80)}…' : preview;
    final l10n = AppLocalizations.of(context);
    if (shortPreview.isEmpty) {
      return l10n.documentBookmarkChoiceLabel(order, paragraph);
    }
    return l10n.documentBookmarkChoiceLabelWithPreview(
      order,
      paragraph,
      shortPreview,
    );
  }

  Future<void> _openBookmarkPicker() async {
    var bookmarks = _normalizeBookmarkIndexes(_bookmarkIndexes);
    if (bookmarks.isEmpty || !mounted) return;

    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) {
          return AlertDialog(
            title: Text(_bookmarkDialogTitle),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: bookmarks.length,
                itemBuilder: (context, index) {
                  final bookmarkIndex = bookmarks[index];
                  return Semantics(
                    customSemanticsActions: {
                      CustomSemanticsAction(label: _deleteBookmarkActionLabel):
                          () async {
                        await _deleteMultipleBookmark(bookmarkIndex);
                        bookmarks = _normalizeBookmarkIndexes(_bookmarkIndexes);
                        if (!dialogContext.mounted) return;
                        if (bookmarks.isEmpty) {
                          Navigator.pop(dialogContext);
                          return;
                        }
                        dialogSetState(() {});
                      },
                    },
                    child: ListTile(
                      leading: const Icon(Icons.bookmark),
                      title: Text(_bookmarkChoiceLabel(bookmarkIndex, index + 1)),
                      onTap: () => Navigator.pop(dialogContext, bookmarkIndex),
                      trailing: ExcludeSemantics(
                        child: IconButton(
                          tooltip: _deleteBookmarkActionLabel,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await _deleteMultipleBookmark(bookmarkIndex);
                            bookmarks = _normalizeBookmarkIndexes(_bookmarkIndexes);
                            if (!dialogContext.mounted) return;
                            if (bookmarks.isEmpty) {
                              Navigator.pop(dialogContext);
                              return;
                            }
                            dialogSetState(() {});
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(AppLocalizations.of(context).cancel),
              ),
            ],
          );
        },
      ),
    );

    if (selected == null || !mounted) return;
    _openChunkAt(selected);
  }

  Future<void> _resolveDisabledMultipleBookmarksIfNeeded() async {
    if (_multipleDocumentBookmarksEnabled || _chunks.isEmpty) return;
    final existing = _normalizeBookmarkIndexes(_currentDoc.bookmarkIndexes);
    if (existing.isEmpty) return;

    if (existing.length == 1) {
      await _saveSingleBookmark(existing.single, showSnack: false, clearMultiple: true);
      return;
    }

    final selected = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_keepBookmarkDialogTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_keepBookmarkDialogMessage),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: existing.length,
                  itemBuilder: (context, index) {
                    final bookmarkIndex = existing[index];
                    return ListTile(
                      leading: const Icon(Icons.bookmark),
                      title: Text(_bookmarkChoiceLabel(bookmarkIndex, index + 1)),
                      onTap: () => Navigator.pop(dialogContext, bookmarkIndex),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    await _saveSingleBookmark(selected, showSnack: false, clearMultiple: true);
    if (!mounted) return;
    _openChunkAt(selected);
  }

  Future<void> _openDocumentSearch() async {
    if (_chunks.isEmpty) return;
    final selectedIndex = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/documents/search'),
        builder: (_) => _DocumentSearchScreen(chunks: _chunks),
      ),
    );
    if (selectedIndex == null || !mounted) return;
    _openChunkAt(selectedIndex);
  }


  Future<void> _openDocumentIndex() async {
    if (_chunks.isEmpty || _documentIndexLoading) return;

    if (_documentIndex.isEmpty) {
      final sourcePath = _epubIndexSourcePath;
      if (sourcePath == null) return;
      await _loadEpubIndex(sourcePath);
      if (!mounted || _documentIndex.isEmpty) return;
    }

    final selectedIndex = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/documents/index'),
        builder: (_) => _DocumentIndexScreen(entries: _documentIndex),
      ),
    );
    if (selectedIndex == null || !mounted) return;
    _openChunkAt(selectedIndex);
  }

  Future<void> _loadEpubIndex(String sourcePath) async {
    final cachedEntries = await _readCachedEpubIndex(sourcePath);
    if (!mounted) return;
    if (cachedEntries != null) {
      setState(() {
        _documentIndex = cachedEntries;
      });
      return;
    }

    BuildContext? dialogContext;
    setState(() => _documentIndexLoading = true);

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogContext = ctx;
          return _DocumentIndexLoadingDialog(
            message: _documentIndexLoadingMessage(ctx),
          );
        },
      ),
    );

    try {
      // Lascia tempo a Flutter di mostrare il dialog prima dell'analisi EPUB.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final entries = await _extractor.extractEpubTableOfContents(
        path: sourcePath,
        chunks: _chunks,
      );
      if (!mounted) return;
      setState(() {
        _documentIndex = entries;
      });
      if (entries.isEmpty) {
        showStatusMessage(context, _documentIndexUnavailableMessage(context));
      } else {
        unawaited(_writeCachedEpubIndex(sourcePath, entries));
      }
    } catch (e, st) {
      dev.log(
        'DocumentReaderScreen: indice EPUB non disponibile',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        showStatusMessage(context, _documentIndexUnavailableMessage(context));
      }
    } finally {
      final activeDialogContext = dialogContext;
      if (activeDialogContext != null && activeDialogContext.mounted) {
        try {
          Navigator.of(activeDialogContext).pop();
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _documentIndexLoading = false);
      }
    }
  }

  Future<List<DocumentTableOfContentsEntry>?> _readCachedEpubIndex(
    String sourcePath,
  ) async {
    try {
      final cacheFile = await _epubIndexCacheFile(sourcePath);
      if (!await cacheFile.exists()) return null;
      final decoded = jsonDecode(await cacheFile.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['cacheVersion'] != _epubIndexCacheVersion) return null;
      if (decoded['chunksLength'] != _chunks.length) return null;
      if (decoded['documentTextLength'] != _documentText.length) return null;
      final rawEntries = decoded['entries'];
      if (rawEntries is! List) return null;

      final entries = <DocumentTableOfContentsEntry>[];
      for (final rawEntry in rawEntries) {
        if (rawEntry is! Map) continue;
        final title = rawEntry['title'];
        final chunkIndex = rawEntry['chunkIndex'];
        final level = rawEntry['level'];
        if (title is! String || chunkIndex is! num) continue;
        final normalizedIndex = chunkIndex.toInt();
        if (normalizedIndex < 0 || normalizedIndex >= _chunks.length) continue;
        entries.add(
          DocumentTableOfContentsEntry(
            title: title,
            chunkIndex: normalizedIndex,
            level: level is num ? level.toInt() : 0,
          ),
        );
      }
      return entries.isEmpty ? null : entries;
    } catch (e) {
      dev.log('DocumentReaderScreen: cache indice EPUB ignorata: $e');
      return null;
    }
  }

  Future<void> _writeCachedEpubIndex(
    String sourcePath,
    List<DocumentTableOfContentsEntry> entries,
  ) async {
    try {
      final cacheFile = await _epubIndexCacheFile(sourcePath);
      final payload = <String, dynamic>{
        'cacheVersion': _epubIndexCacheVersion,
        'chunksLength': _chunks.length,
        'documentTextLength': _documentText.length,
        'entries': entries
            .map(
              (entry) => <String, dynamic>{
                'title': entry.title,
                'chunkIndex': entry.chunkIndex,
                'level': entry.level,
              },
            )
            .toList(),
      };
      await cacheFile.writeAsString(jsonEncode(payload), flush: true);
    } catch (e) {
      dev.log('DocumentReaderScreen: impossibile salvare cache indice EPUB: $e');
    }
  }

  Future<File> _epubIndexCacheFile(String sourcePath) async {
    final sourceFile = File(sourcePath);
    final stat = await sourceFile.stat();
    final cacheKey = _stableCacheKey(
      [
        sourceFile.absolute.path,
        stat.size.toString(),
        stat.modified.millisecondsSinceEpoch.toString(),
        _documentText.length.toString(),
        _chunks.length.toString(),
        _maxChunkChars.toString(),
        _epubIndexCacheVersion.toString(),
      ].join('|'),
    );
    final supportDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${supportDir.path}/epub_index_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return File('${cacheDir.path}/$cacheKey.json');
  }

  String _stableCacheKey(String value) {
    const fnvPrime = 16777619;
    var hash = 2166136261;
    for (final unit in utf8.encode(value)) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _documentIndexLoadingMessage(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode.toLowerCase();
    switch (lang) {
      case 'fr':
        return 'Chargement de l’indice en cours... Veuillez patienter.';
      case 'es':
        return 'Cargando índice... Espera, por favor.';
      case 'pt':
        return 'A carregar índice... Aguarde.';
      case 'pl':
        return 'Ładowanie spisu treści... Proszę czekać.';
      case 'cs':
        return 'Načítání obsahu... Čekejte prosím.';
      case 'en':
        return 'Loading table of contents... Please wait.';
      case 'it':
      default:
        return 'Caricamento indice in corso... Attendere.';
    }
  }

  String _documentIndexUnavailableMessage(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode.toLowerCase();
    switch (lang) {
      case 'fr':
        return 'Indice non disponible pour cet EPUB.';
      case 'es':
        return 'Índice no disponible para este EPUB.';
      case 'pt':
        return 'Índice não disponível para este EPUB.';
      case 'pl':
        return 'Spis treści nie jest dostępny dla tego EPUB-a.';
      case 'cs':
        return 'Obsah není pro tento EPUB dostupný.';
      case 'en':
        return 'Table of contents not available for this EPUB.';
      case 'it':
      default:
        return 'Indice non disponibile per questo EPUB.';
    }
  }

  void _openChunkAt(int index) {
    if (index < 0 || index >= _chunks.length) return;
    setState(() {
      _playingChunkIndex = index;
    });
    _scrollToChunk(index);
  }

  // ---------------------------------------------------------------------------
  // TTS
  // ---------------------------------------------------------------------------

  Future<String> _voice() async {
    final configured = await _settings.loadTtsVoice();
    if (configured.trim().isNotEmpty) return configured;
    return 'it-IT-IsabellaNeural';
  }

  Future<void> _startReading({bool restartSleepTimer = true}) async {
    if (_chunks.isEmpty) {
            showStatusMessage(context, AppLocalizations.of(context).noTextToRead);
      return;
    }

    final readingToken = ++_readingToken;
    _speaking = true;
    _ttsPaused = false;
    _playingChunkIndex = -1;
    _ttsStatus = null;

    try {
      var engine = await _settings.loadTtsEngine();
      if (engine == 'pocket' && !await _pocketTts.isAvailable()) {
        await AppLogger.log(
          'Pocket TTS non disponibile o modello non scaricato: uso Edge TTS come fallback.',
        );
        engine = 'edge';
      }
      final pocketVoice = await _settings.loadPocketTtsVoice();
      final pocketLanguage = await _settings.loadPocketTtsLanguage();
      final ttsSpeed = await _settings.loadTtsSpeed();
      final ttsPitch = await _settings.loadTtsPitch();
      final dictionaryEntries = await _voiceDictionary.loadEntries();
      await AppLogger.log(
        'DocumentReader: TTS start engine=$engine pocketVoice=$pocketVoice '
        'pocketLanguage=$pocketLanguage speed=$ttsSpeed pitch=$ttsPitch '
        'doc="${_currentDoc.name}" chunks=${_chunks.length}',
      );
      _activeTtsEngine = engine;
      _startReadingSleepTimerIfNeeded(restart: restartSleepTimer);
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
          await _setMagicTapPlaying(true);
        }
        await _configureSystemTtsAudioSession();
        await _flutterTts.awaitSpeakCompletion(true);
        if (Platform.isIOS) {
          await _flutterTts.setSharedInstance(true);
          await _flutterTts.autoStopSharedSession(false);
        }
        await _flutterTts.setSpeechRate(ttsSpeed * 0.5);
        await _flutterTts.setPitch(ttsPitch);

        final sysLang = await _settings.loadSystemTtsLanguage();
        final sysVoice = await _settings.loadSystemTtsVoice();

        if (sysVoice != null) {
          await _flutterTts.setVoice({"name": sysVoice, "locale": sysLang});
        } else {
          await _flutterTts.setLanguage(sysLang);
        }

        for (var i = startIndex; i < _chunks.length; i++) {
          if (!mounted || !_speaking || readingToken != _readingToken) break;

          while (_ttsPaused) {
            await Future.delayed(const Duration(milliseconds: 100));
            if (!mounted || !_speaking || readingToken != _readingToken) break;
          }
          if (!mounted || !_speaking || readingToken != _readingToken) break;

          final textToSpeak =
              _voiceDictionary.applyToText(_chunks[i], dictionaryEntries);
          final speaking = _flutterTts.speak(textToSpeak);
          if (mounted) {
            setState(() {
              _playingChunkIndex = i;
            });
            _scrollToChunk(i);
          }
          await speaking;
        }
        await _flutterTts.stop();
      } else if (engine == 'pocket') {
        final controller = StreamController<File>();
        _edgeFileController = controller;
        Object? generationError;
        const initialBufferChunks = 1;

        final generation = Future<void>(() async {
          for (var i = startIndex; i < _chunks.length; i++) {
            if (!mounted || !_speaking || readingToken != _readingToken) {
              break; // Ferma la generazione se l'utente preme stop
            }
            final textToSpeak =
                _voiceDictionary.applyToText(_chunks[i], dictionaryEntries);
            await AppLogger.log(
              'Pocket TTS: document chunk start index=$i chars=${textToSpeak.length}',
            );
            final file = await _pocketTts.speakToFile(
              text: textToSpeak,
              voice: pocketVoice,
              language: pocketLanguage,
              speed: ttsSpeed,
              pitch: ttsPitch,
            );
            if (!controller.isClosed &&
                mounted &&
                _speaking &&
                readingToken == _readingToken) {
              await AppLogger.log('Pocket TTS: document chunk ready index=$i file=${file.path}');
              controller.add(file);
            }
          }
          if (!controller.isClosed) await controller.close();
        }).catchError((e) async {
          generationError = e;
          await AppLogger.log('Pocket TTS: document generation error=$e');
          if (!controller.isClosed) await controller.close();
        });

        if (mounted && _speaking) {
          await _audio.playFileStreamSequentially(
            controller.stream,
            sessionType: AudioSessionType.playback,
            title: _currentDoc.name,
            initialBufferCount: initialBufferChunks,
            isPaused: () => _ttsPaused,
            onChunkStarted: (index, file) {
              final chunkIndex = startIndex + index;
              if (mounted && readingToken == _readingToken) {
                unawaited(AppLogger.log('Pocket TTS: playback started chunkIndex=$chunkIndex')); 
                setState(() {
                  _playingChunkIndex = chunkIndex;
                });
                _scrollToChunk(chunkIndex);
              }
            },
          );
        }
        if (!controller.isClosed) await controller.close();
        await generation;
        if (_edgeFileController == controller) {
          _edgeFileController = null;
        }
        if (readingToken != _readingToken) return;
        if (generationError != null) throw Exception(generationError);
      } else {
        final voice = await _voice();
        final controller = StreamController<File>();
        _edgeFileController = controller;
        Object? generationError;
        const initialBufferChunks = 2;

        final generation = Future<void>(() async {
          for (var i = startIndex; i < _chunks.length; i++) {
            if (!mounted || !_speaking || readingToken != _readingToken) {
              break; // Ferma la generazione se l'utente preme stop
            }
            final textToSpeak =
                _voiceDictionary.applyToText(_chunks[i], dictionaryEntries);
            final file =
                await _tts.speakToFile(text: textToSpeak, voice: voice);
            if (!controller.isClosed &&
                mounted &&
                _speaking &&
                readingToken == _readingToken) {
              controller.add(file);
            }
          }
          if (!controller.isClosed) await controller.close();
        }).catchError((e) async {
          generationError = e;
          if (!controller.isClosed) await controller.close();
        });

        if (mounted && _speaking) {
          await _audio.playFileStreamSequentially(
            controller.stream,
            sessionType: AudioSessionType.playback,
            title: _currentDoc.name,
            initialBufferCount: initialBufferChunks,
            isPaused: () => _ttsPaused,
            onChunkStarted: (index, file) {
              final chunkIndex = startIndex + index;
              if (mounted && readingToken == _readingToken) {
                setState(() {
                  _playingChunkIndex = chunkIndex;
                });
                _scrollToChunk(chunkIndex);
              }
            },
          );
        }
        if (!controller.isClosed) await controller.close();
        await generation;
        if (_edgeFileController == controller) {
          _edgeFileController = null;
        }
        if (readingToken != _readingToken) return;
        if (generationError != null) throw Exception(generationError);
      }

      if (Platform.isIOS && engine == 'system') {
        try {
          await _ttsCommands.invokeMethod('clearMagicTap');
        } catch (_) {}
      }

      if (!mounted) return;
      if (readingToken != _readingToken) return;
      _cancelReadingSleepTimer();
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
      if (readingToken != _readingToken) return;
      setState(() {
        _playingChunkIndex = -1;
        _ttsStatus = '${AppLocalizations.of(context).ttsError}: $e';
        _activeTtsEngine = null;
      });
            showStatusMessage(context, '${AppLocalizations.of(context).ttsError}: $e');
    } finally {
      if (mounted && readingToken == _readingToken) {
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
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ],
      IosTextToSpeechAudioMode.defaultMode,
    );
    await session.setActive(true);
  }

  Future<void> _setMagicTapPlaying(bool playing) async {
    if (!Platform.isIOS) return;
    try {
      await _ttsCommands.invokeMethod('setMagicTapPlaying', playing);
    } catch (e) {
      dev.log('DocumentReaderScreen: errore setMagicTapPlaying $playing: $e');
    }
  }

  void _cancelReadingSleepTimer() {
    _readingSleepTimer?.cancel();
    _readingSleepTimer = null;
  }

  void _startReadingSleepTimerIfNeeded({required bool restart}) {
    if (!restart) return;
    _cancelReadingSleepTimer();
    final minutes = _documentReadingSleepTimerMinutes;
    if (minutes <= 0) return;
    _readingSleepTimer = Timer(Duration(minutes: minutes), () {
      _readingSleepTimer = null;
      unawaited(_stopReading(fromSleepTimer: true));
    });
  }

  int? _currentReadingBookmarkIndex() {
    final index = _playingChunkIndex >= 0
        ? _playingChunkIndex
        : _bookmarkIndex.clamp(0, _chunks.length - 1);
    if (index < 0 || index >= _chunks.length) return null;
    return index;
  }

  Future<void> _saveSleepTimerBookmarkFromPlayback() async {
    final index = _currentReadingBookmarkIndex();
    if (index == null) return;
    await _saveAutomaticBookmark(index);
  }

  Future<void> _stopReading({bool fromSleepTimer = false}) async {
    _readingToken += 1;
    if (!fromSleepTimer) {
      _cancelReadingSleepTimer();
    }
    final l10n = AppLocalizations.of(context);
    final statusMessage = fromSleepTimer
        ? l10n.documentReadingSleepTimerStopped
        : l10n.readingStopped;
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
      _ttsPaused = false;
      _ttsStatus = statusMessage;
    });
    if (fromSleepTimer) {
      await _saveSleepTimerBookmarkFromPlayback();
    } else {
      await _saveAutomaticBookmarkFromPlayback();
    }
    if (Platform.isIOS && _activeTtsEngine == 'system') {
      try {
        await _ttsCommands.invokeMethod('clearMagicTap');
      } catch (_) {}
    }
    // Aggiorna subito la UI per un feedback immediato
    setState(() {
      _activeTtsEngine = null;
      _playingChunkIndex = -1;
    });
    if (fromSleepTimer && mounted) {
      showStatusMessage(context, statusMessage);
    }
  }

  Future<void> _saveAutomaticBookmarkFromPlayback() async {
    if (_playingChunkIndex < 0 || _playingChunkIndex >= _chunks.length) {
      return;
    }
    if (!await _settings.isAutoBookmarkEnabled()) {
      return;
    }
    await _saveAutomaticBookmark(_playingChunkIndex);
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
          title: Text(AppLocalizations.of(context).editParagraph),
          content: SizedBox(
            width: double.maxFinite,
            child: Semantics(
              label: AppLocalizations.of(context).editParagraphTextField,
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.multiline,
                maxLines: 12,
                minLines: 6,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: AppLocalizations.of(context).editParagraphHint,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(AppLocalizations.of(context).applyAndSave),
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
        bookmarkIndex: _storedAutomaticBookmarkIndexForDocumentSave(),
        bookmarkIndexes: _bookmarkIndexes,
        editedTextPath: editedPath,
        isTemporary: _currentDoc.isTemporary,
        isFolder: _currentDoc.isFolder,
        parentId: _currentDoc.parentId,
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
        _chunks = _splitTextForDocumentDisplay(_documentText);
        // Chiavi gestite da AutoScrollTag
      });

      if (!mounted) return;
            showStatusMessage(context, AppLocalizations.of(context).textEditedAndSaved);
    } catch (e) {
      dev.log('DocumentReaderScreen: Errore fatale durante il salvataggio: $e');
      if (!mounted) return;
            showStatusMessage(context, '${AppLocalizations.of(context).saveError}: $e');
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
      await _setMagicTapPlaying(false);
    } else {
      await _audio.pause();
    }
    await _saveAutomaticBookmarkFromPlayback();
  }

  Future<void> _resumeReading() async {
    if (!_speaking || !_ttsPaused) return;

    if (_activeTtsEngine == 'system') {
      await _resumeSystemTtsFromCurrentChunk();
    } else {
      if (mounted) setState(() => _ttsPaused = false);
      await _audio.resumeSequentialPlayback();
    }
  }

  Future<void> _resumeSystemTtsFromCurrentChunk() async {
    if (_systemTtsResumeInProgress) return;
    if (!_speaking || _activeTtsEngine != 'system' || !_ttsPaused) return;
    final resumeIndex = _currentReadingBookmarkIndex();
    if (resumeIndex == null) return;

    _systemTtsResumeInProgress = true;
    final edgeController = _edgeFileController;
    _edgeFileController = null;
    _readingToken += 1;

    try {
      await _flutterTts.stop();
    } catch (e) {
      dev.log('DocumentReaderScreen system TTS stop before resume error: $e');
    }

    try {
      await _audio.stop();
    } catch (e) {
      dev.log('DocumentReaderScreen audio stop before system resume error: $e');
    }

    if (edgeController != null && !edgeController.isClosed) {
      try {
        await edgeController.close();
      } catch (e) {
        dev.log('DocumentReaderScreen stream close before system resume error: $e');
      }
    }

    if (!mounted) {
      _systemTtsResumeInProgress = false;
      return;
    }

    setState(() {
      _bookmarkIndex = resumeIndex;
      _playingChunkIndex = resumeIndex;
      _speaking = false;
      _ttsPaused = false;
      _ttsStatus = null;
      _activeTtsEngine = null;
    });

    try {
      await _startReading(restartSleepTimer: false);
    } finally {
      _systemTtsResumeInProgress = false;
    }
  }

  void _seekDocumentToPercent(double percent) {
    if (_chunks.isEmpty) return;
    final clampedPercent = percent.clamp(0.0, 100.0);
    final maxIndex = _chunks.length - 1;
    final targetIndex = ((clampedPercent / 100) * maxIndex).round();
    final currentIndex = _playingChunkIndex >= 0
        ? _playingChunkIndex
        : _bookmarkIndex.clamp(0, maxIndex);
    final positionChanged = targetIndex != currentIndex;
    final shouldRealignReading = _speaking && positionChanged;
    final shouldResumeReading = _speaking && !_ttsPaused;
    if (!positionChanged && !_speaking) return;
    setState(() {
      _bookmarkIndex = targetIndex;
      _playingChunkIndex = targetIndex;
    });
    _scrollToChunk(targetIndex);
    if (shouldRealignReading) {
      final seekToken = ++_documentSeekToken;
      unawaited(
        _realignReadingAfterDocumentSeek(
          targetIndex,
          seekToken,
          resumeReading: shouldResumeReading,
        ),
      );
    }
  }

  Future<void> _realignReadingAfterDocumentSeek(
    int targetIndex,
    int seekToken, {
    required bool resumeReading,
  }) async {
    if (targetIndex < 0 || targetIndex >= _chunks.length) return;

    final activeEngine = _activeTtsEngine;
    final edgeController = _edgeFileController;
    _edgeFileController = null;
    _readingToken += 1;

    try {
      await _audio.stop();
    } catch (e) {
      dev.log('DocumentReaderScreen: errore stop audio dopo slider: $e');
    }

    try {
      await _flutterTts.stop();
    } catch (e) {
      dev.log('DocumentReaderScreen: errore stop TTS dopo slider: $e');
    }

    if (edgeController != null && !edgeController.isClosed) {
      try {
        await edgeController.close();
      } catch (e) {
        dev.log('DocumentReaderScreen: errore chiusura stream Edge dopo slider: $e');
      }
    }

    if (Platform.isIOS && activeEngine == 'system') {
      try {
        await _ttsCommands.invokeMethod('clearMagicTap');
      } catch (_) {}
    }

    if (!mounted || seekToken != _documentSeekToken) return;

    setState(() {
      _bookmarkIndex = targetIndex;
      _playingChunkIndex = targetIndex;
      _speaking = false;
      _ttsPaused = false;
      _ttsStatus = null;
      _activeTtsEngine = null;
    });

    if (resumeReading && mounted && seekToken == _documentSeekToken) {
      await _startReading(restartSleepTimer: false);
    }
  }

  void _seekDocumentByPercent(double delta) {
    final currentPercent = _documentProgressPercent;
    final targetPercent = (currentPercent + delta).clamp(0.0, 100.0);
    if (targetPercent == currentPercent) return;
    _seekDocumentToPercent(targetPercent);
  }

  double get _documentProgressPercent {
    if (_chunks.isEmpty) return 0;
    final activeIndex = _playingChunkIndex >= 0
        ? _playingChunkIndex
        : _bookmarkIndex.clamp(0, _chunks.length - 1);
    if (_chunks.length == 1) return 100;
    return (activeIndex / (_chunks.length - 1)) * 100;
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
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.searchInDocument,
            onPressed: _chunks.isEmpty
                ? null
                : () => unawaited(_openDocumentSearch()),
          ),
          if (_documentIndex.isNotEmpty ||
              (_epubIndexSourcePath != null && _chunks.isNotEmpty))
            IconButton(
              icon: _documentIndexLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.list_alt),
              tooltip: l10n.documentIndex,
              onPressed: _documentIndexLoading
                  ? null
                  : () => unawaited(_openDocumentIndex()),
            ),
          if (doc.isTemporary)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: l10n.saveInLibrary,
              onPressed: () async {
                final newDoc = DocumentItem(
                  id: doc.id,
                  name: doc.name,
                  path: doc.path,
                  extension: doc.extension,
                  addedAt: doc.addedAt,
                  bookmarkIndex: doc.bookmarkIndex,
                  bookmarkIndexes: doc.bookmarkIndexes,
                  editedTextPath: doc.editedTextPath,
                  isTemporary: false,
                  isFolder: doc.isFolder,
                  parentId: doc.parentId,
                );
                final lib = DocumentLibraryService();
                await lib.load();
                await lib.add(newDoc);
                setState(() {
                  _currentDoc = newDoc;
                });
                if (!context.mounted) return;
                                showStatusMessage(context, l10n.docSavedInLibrary);
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
                              ? l10n.startReading
                              : (_ttsPaused
                                  ? l10n.resumeReading
                                  : l10n.pauseReading)),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _speaking ? () => _stopReading() : null,
                          icon: const Icon(Icons.stop),
                          label: Text(l10n.stopReading),
                        ),
                        if (_chunks.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _DocumentPositionSlider(
                            value: _documentProgressPercent,
                            label: l10n.documentPosition,
                            onChanged: _seekDocumentToPercent,
                            stepPercent: _documentSliderStepPercent,
                            onIncrease: () =>
                                _seekDocumentByPercent(_documentSliderStepPercent.toDouble()),
                            onDecrease: () =>
                                _seekDocumentByPercent(-_documentSliderStepPercent.toDouble()),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Semantics(
                      label: l10n.documentTextLabel,
                      explicitChildNodes: true,
                      child: CustomScrollView(
                        controller: _scrollController,
                        scrollCacheExtent: const ScrollCacheExtent.pixels(
                            4000), // Precarica i blocchi successivi per VoiceOver
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
                                                    ? ' (${l10n.modifiedInSonarpad})'
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
                                  ..._buildChunkWidgets(
                                    theme,
                                    colorScheme,
                                    l10n,
                                  )
                                else if (_documentText.isEmpty &&
                                    _loadError == null)
                                  Text(
                                    l10n.noTextAvailableForDocument,
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
  List<Widget> _buildChunkWidgets(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < _chunks.length; i++) {
      final isPlaying = i == _playingChunkIndex;
      final isBookmarked = _multipleDocumentBookmarksEnabled
          ? _bookmarkIndexes.contains(i)
          : (_hasBookmark && i == _bookmarkIndex);

      // Durante la lettura TTS il tap è disabilitato per non interferire.
      final canEdit = !_speaking;

      String hintText = canEdit ? l10n.documentEditParagraphActionHint : '';
      if (_multipleDocumentBookmarksEnabled) {
        hintText += l10n.documentBookmarkHintSet;
        if (_bookmarkIndexes.isNotEmpty) {
          hintText += ' $_goToBookmarkActionLabel.';
        }
      } else if (_hasBookmark) {
        hintText += l10n.documentBookmarkHintReplace;
      } else {
        hintText += l10n.documentBookmarkHintSet;
      }

      final Map<CustomSemanticsAction, VoidCallback> actions = {};
      if (_multipleDocumentBookmarksEnabled) {
        actions[CustomSemanticsAction(label: l10n.documentSetBookmarkAction)] =
            () => _setBookmark(i);
        if (_bookmarkIndexes.isNotEmpty) {
          actions[CustomSemanticsAction(label: _goToBookmarkActionLabel)] =
              () => unawaited(_openBookmarkPicker());
        }
      } else if (_hasBookmark) {
        actions[CustomSemanticsAction(
            label: l10n.documentReplaceBookmarkAction)] = () => _setBookmark(i);
      } else {
        actions[CustomSemanticsAction(label: l10n.documentSetBookmarkAction)] =
            () => _setBookmark(i);
      }
      widgets.add(
        AutoScrollTag(
          key: ValueKey(i),
          controller: _scrollController,
          index: i,
          child: Semantics(
            key: ValueKey('document_chunk_semantics_$i'),
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
    if (_multipleDocumentBookmarksEnabled) {
      await _addMultipleBookmark(index, showSnack: false);
    } else {
      await _saveSingleBookmark(index, showSnack: false);
    }
    if (mounted) {
      showStatusMessage(
        context,
        AppLocalizations.of(context).bookmarkSet(index + 1),
      );
    }
  }

  Future<void> _saveAutomaticBookmark(int index) async {
    await _saveSingleBookmark(
      index,
      showSnack: false,
      clearMultiple: false,
      preserveMultipleState: true,
    );
  }

  Future<void> _saveSingleBookmark(
    int index, {
    required bool showSnack,
    bool clearMultiple = false,
    bool preserveMultipleState = false,
  }) async {
    final nextBookmarkIndexes = clearMultiple
        ? const <int>[]
        : (preserveMultipleState
            ? _bookmarkIndexes
            : (_multipleDocumentBookmarksEnabled
                ? _bookmarkIndexes
                : const <int>[]));

    setState(() {
      _bookmarkIndex = index;
      _hasBookmark = true;
      _bookmarkIndexes = List<int>.unmodifiable(nextBookmarkIndexes);
    });

    final newDoc = DocumentItem(
      id: _currentDoc.id,
      name: _currentDoc.name,
      path: _currentDoc.path,
      extension: _currentDoc.extension,
      addedAt: _currentDoc.addedAt,
      bookmarkIndex: index,
      bookmarkIndexes: List<int>.unmodifiable(nextBookmarkIndexes),
      editedTextPath: _currentDoc.editedTextPath,
      isTemporary: _currentDoc.isTemporary,
      isFolder: _currentDoc.isFolder,
      parentId: _currentDoc.parentId,
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
      showStatusMessage(
        context,
        AppLocalizations.of(context).bookmarkSet(index + 1),
      );
    }
  }

  Future<void> _deleteMultipleBookmark(int index) async {
    final nextBookmarks = List<int>.from(_bookmarkIndexes)..remove(index);
    final normalized = _normalizeBookmarkIndexes(nextBookmarks);
    final automaticIndex =
        _validAutomaticBookmarkIndex(_currentDoc.bookmarkIndex);
    final preferredIndex = _preferredMultipleBookmarkResumeIndex(
      normalized,
      automaticIndex: automaticIndex,
    );

    setState(() {
      _bookmarkIndexes = normalized;
      _bookmarkIndex = preferredIndex;
      _hasBookmark = _bookmarkIndex > 0;
    });

    final newDoc = DocumentItem(
      id: _currentDoc.id,
      name: _currentDoc.name,
      path: _currentDoc.path,
      extension: _currentDoc.extension,
      addedAt: _currentDoc.addedAt,
      bookmarkIndex: automaticIndex,
      bookmarkIndexes: normalized,
      editedTextPath: _currentDoc.editedTextPath,
      isTemporary: _currentDoc.isTemporary,
      isFolder: _currentDoc.isFolder,
      parentId: _currentDoc.parentId,
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
      showStatusMessage(context, _deleteBookmarkActionLabel);
    }
  }

  Future<void> _addMultipleBookmark(int index, {required bool showSnack}) async {
    final nextBookmarks = List<int>.from(_bookmarkIndexes);
    nextBookmarks.remove(index);
    nextBookmarks.add(index);
    final normalized = _normalizeBookmarkIndexes(nextBookmarks);
    final automaticIndex =
        _validAutomaticBookmarkIndex(_currentDoc.bookmarkIndex);
    final preferredIndex = _preferredMultipleBookmarkResumeIndex(
      normalized,
      automaticIndex: automaticIndex,
    );

    setState(() {
      _bookmarkIndex = preferredIndex;
      _hasBookmark = _bookmarkIndex > 0;
      _bookmarkIndexes = normalized;
    });

    final newDoc = DocumentItem(
      id: _currentDoc.id,
      name: _currentDoc.name,
      path: _currentDoc.path,
      extension: _currentDoc.extension,
      addedAt: _currentDoc.addedAt,
      bookmarkIndex: automaticIndex,
      bookmarkIndexes: normalized,
      editedTextPath: _currentDoc.editedTextPath,
      isTemporary: _currentDoc.isTemporary,
      isFolder: _currentDoc.isFolder,
      parentId: _currentDoc.parentId,
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
      showStatusMessage(
        context,
        AppLocalizations.of(context).bookmarkSet(index + 1),
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


class _DocumentIndexScreen extends StatelessWidget {
  const _DocumentIndexScreen({required this.entries});

  final List<DocumentTableOfContentsEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.documentIndex)),
      body: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return ListTile(
            contentPadding: EdgeInsetsDirectional.only(
              start: 16.0 + entry.level * 20.0,
              end: 16,
            ),
            title: Text(entry.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pop(entry.chunkIndex),
          );
        },
      ),
    );
  }
}


class _DocumentIndexLoadingDialog extends StatelessWidget {
  final String message;

  const _DocumentIndexLoadingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Semantics(
        liveRegion: true,
        container: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _DocumentSearchScreen extends StatefulWidget {
  const _DocumentSearchScreen({required this.chunks});

  final List<String> chunks;

  @override
  State<_DocumentSearchScreen> createState() => _DocumentSearchScreenState();
}

class _DocumentSearchScreenState extends State<_DocumentSearchScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final l10n = AppLocalizations.of(context);
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() => _error = l10n.documentSearchEmptyQuery);
      return;
    }

    final normalizedQuery = query.toLowerCase();
    final results = <_DocumentSearchResult>[];
    for (var i = 0; i < widget.chunks.length; i++) {
      final text = widget.chunks[i];
      final matchIndex = text.toLowerCase().indexOf(normalizedQuery);
      if (matchIndex < 0) continue;
      results.add(
        _DocumentSearchResult(
          chunkIndex: i,
          excerpt: _excerptForMatch(text, query),
        ),
      );
    }

    final selectedIndex = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/documents/search/results'),
        builder: (_) => _DocumentSearchResultsScreen(
          query: query,
          results: results,
        ),
      ),
    );
    if (selectedIndex == null || !mounted) return;
    Navigator.of(context).pop(selectedIndex);
  }

  String _excerptForMatch(String text, String query) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= 180) return collapsed;

    final collapsedMatchIndex =
        collapsed.toLowerCase().indexOf(query.toLowerCase());
    final safeMatchIndex =
        (collapsedMatchIndex < 0 ? 0 : collapsedMatchIndex)
            .clamp(0, collapsed.length)
            .toInt();
    
    int start = (safeMatchIndex - 70).clamp(0, collapsed.length).toInt();
    final end =
        (safeMatchIndex + query.length + 90).clamp(0, collapsed.length).toInt();
    
    final initialWords = collapsed.split(' ').take(3).join(' ');
    String prefix = '';
    
    if (start > 0) {
      if (start <= initialWords.length + 15) {
        start = 0;
      } else {
        prefix = '$initialWords ... ';
      }
    }
    
    final suffix = end < collapsed.length ? ' ...' : '';
    return '$prefix${collapsed.substring(start, end).trimLeft()}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchInDocument)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.documentSearchFieldLabel,
              hintText: l10n.documentSearchFieldHint,
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.search,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.search),
            label: Text(l10n.search),
          ),
        ],
      ),
    );
  }
}

class _DocumentSearchResultsScreen extends StatelessWidget {
  const _DocumentSearchResultsScreen({
    required this.query,
    required this.results,
  });

  final String query;
  final List<_DocumentSearchResult> results;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.documentSearchResultsTitle)),
      body: results.isEmpty
          ? Center(child: Text(l10n.noDocumentSearchResults(query)))
          : ListView.separated(
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final result = results[index];
                return ListTile(
                  title: Text(l10n.documentSearchResultParagraph(
                    result.chunkIndex + 1,
                  )),
                  subtitle: Text(result.excerpt),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pop(result.chunkIndex),
                );
              },
            ),
    );
  }
}

class _DocumentSearchResult {
  const _DocumentSearchResult({
    required this.chunkIndex,
    required this.excerpt,
  });

  final int chunkIndex;
  final String excerpt;
}

class _DocumentPositionSlider extends StatelessWidget {
  const _DocumentPositionSlider({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.stepPercent,
    required this.onIncrease,
    required this.onDecrease,
  });

  final double value;
  final String label;
  final ValueChanged<double> onChanged;
  final int stepPercent;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    final percent = value.round().clamp(0, 100);
    final step = stepPercent.clamp(1, 100);
    final increased = (percent + step).clamp(0, 100);
    final decreased = (percent - step).clamp(0, 100);

    return Semantics(
      slider: true,
      label: label,
      value: '$percent%',
      increasedValue: '$increased%',
      decreasedValue: '$decreased%',
      onIncrease: onIncrease,
      onDecrease: onDecrease,
      child: ExcludeSemantics(
        child: Slider(
          value: value.clamp(0.0, 100.0).toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
