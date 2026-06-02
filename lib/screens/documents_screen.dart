import 'dart:developer' as dev;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../l10n/app_localizations.dart';
import '../models/document_item.dart';
import '../services/document_library_service.dart';
import '../services/document_text_extractor.dart';
import '../utils/app_logger.dart';
import 'document_editor_screen.dart';
import 'document_reader_screen.dart';
import 'dropbox_browser_screen.dart';

/// Schermata libreria documenti.
/// Permette di aggiungere file dal dispositivo (PDF, DOCX, EPUB, TXT, ecc.)
/// e di sfogliarli / leggerli con TTS.
class DocumentsScreen extends StatefulWidget {
  final String? folderId;
  const DocumentsScreen({super.key, this.folderId});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _service = DocumentLibraryService();
  bool _loading = true;
  String? _errorMessage;

  List<DocumentItem> get _displayedDocs =>
      _service.documents.where((d) => d.parentId == widget.folderId).toList();

  static const _allowedExtensions = [
    'pdf',
    'docx',
    'doc',
    'epub',
    'txt',
    'rtf',
    'odt',
    'md',
    'html',
    'htm',
    'zip',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _service.load();
      if (_service.documents.isEmpty) {
        await _service.recoverVisibleDocuments(_allowedExtensions);
      }
    } catch (e) {
      dev.log('DocumentsScreen: errore caricamento: $e');
      if (mounted) {
        setState(() =>
            _errorMessage = AppLocalizations.of(context).libraryLoadError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFile() async {
    final allowMultiple = await _askImportSelectionMode();
    if (allowMultiple == null) return;

    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        allowMultiple: allowMultiple,
      );
    } catch (e) {
      dev.log('DocumentsScreen: errore apertura file picker: $e');
      if (mounted) {
        _showSnack(AppLocalizations.of(context).fileOpenError(e));
      }
      return;
    }

    if (result == null || result.files.isEmpty) {
      return;
    }

    for (final file in result.files) {
      final path = file.path;
      if (path == null) {
        if (mounted) {
          _showSnack(AppLocalizations.of(context).filePathUnavailable);
        }
        continue;
      }

      await AppLogger.log('Importazione singolo file: $path');
      final f = File(path);
      if (!await f.exists()) {
        await AppLogger.log('Il file non esiste o inaccessibile: $path');
        if (mounted) {
          _showSnack(
              AppLocalizations.of(context).fileInaccessible(p.basename(path)));
        }
        continue;
      }

      if (f.path.toLowerCase().endsWith('.zip')) {
        try {
          await _service.importZip(f, parentId: widget.folderId);
          await AppLogger.log('Zip importato: ${p.basename(path)}');
        } catch (e) {
          dev.log('DocumentsScreen: errore importazione zip: $e');
          await AppLogger.log('DocumentsScreen: errore importazione zip: $e');
          if (mounted) {
            _showSnack(AppLocalizations.of(context).importZipError(e));
          }
        }
        continue;
      }

      try {
        final doc = await _service.importFile(
          f,
          originalName: file.name.isNotEmpty ? file.name : p.basename(path),
          parentId: widget.folderId,
        );
        await _service.add(doc);
        await AppLogger.log('File importato: ${doc.displayName}');
      } catch (e) {
        dev.log('DocumentsScreen: errore aggiunta documento: $e');
        await AppLogger.log('DocumentsScreen: errore aggiunta documento: $e');
        if (mounted) {
          _showSnack(AppLocalizations.of(context).documentAddError(e));
        }
        continue;
      }
    }

    if (mounted) {
      setState(() {});
      await _showImportCompleteDialog(
          AppLocalizations.of(context).documentsAdded);
    }
  }

  Future<bool?> _askImportSelectionMode() {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addToLibrary),
        content: Text(l10n.documentImportSelectionMode),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.documentImportSingle),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.documentImportMultiple),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(String id) async {
    final l10n = AppLocalizations.of(context);
    bool isFolder = false;
    try {
      // Troviamo il documento per ottenerne il path e cancellarlo dal disco
      final doc = _service.documents.firstWhere((d) => d.id == id);
      isFolder = doc.isFolder;
      final resolvedPath = await _service.resolveFilePath(doc);
      final file = File(resolvedPath);
      if (await file.exists()) {
        await file.delete();
      }

      await _service.remove(id);
    } catch (e) {
      dev.log('DocumentsScreen: errore rimozione documento: $e');
      if (mounted) _showSnack(l10n.documentRemoveError(e));
      return;
    }
    if (mounted) {
      setState(() {});
      _showSnack(isFolder ? l10n.folderRemoved : l10n.documentRemoved);
    }
  }

  Future<void> _handleAction(_DocumentAction action, DocumentItem doc) async {
    final l10n = AppLocalizations.of(context);
    final displayed = _displayedDocs;
    final currentIndex = displayed.indexWhere((d) => d.id == doc.id);
    if (currentIndex == -1) return;

    final globalList = List<DocumentItem>.from(_service.documents);
    final globalCurrentIndex = globalList.indexWhere((d) => d.id == doc.id);

    if (action == _DocumentAction.moveUp && currentIndex > 0) {
      final targetDoc = displayed[currentIndex - 1];
      final globalTargetIndex =
          globalList.indexWhere((d) => d.id == targetDoc.id);

      final temp = globalList[globalCurrentIndex];
      globalList[globalCurrentIndex] = globalList[globalTargetIndex];
      globalList[globalTargetIndex] = temp;

      await _service.saveAll(globalList);
      if (!mounted) return;
      setState(() {});
    } else if (action == _DocumentAction.moveDown &&
        currentIndex < displayed.length - 1) {
      final targetDoc = displayed[currentIndex + 1];
      final globalTargetIndex =
          globalList.indexWhere((d) => d.id == targetDoc.id);

      final temp = globalList[globalCurrentIndex];
      globalList[globalCurrentIndex] = globalList[globalTargetIndex];
      globalList[globalTargetIndex] = temp;

      await _service.saveAll(globalList);
      if (!mounted) return;
      setState(() {});
    } else if (action == _DocumentAction.moveToPosition) {
      final folders = _service.documents
          .where((d) => d.isFolder && d.id != doc.id)
          .toList();
      final result = await showDialog<dynamic>(
        context: context,
        builder: (_) => _DocumentPositionSliderDialog(
          currentIndex: currentIndex,
          documents: displayed,
          allFolders: folders,
          currentFolderId: widget.folderId,
        ),
      );

      if (result is int && result != currentIndex) {
        final itemToMove = globalList.removeAt(globalCurrentIndex);

        final visibleTargets = displayed.where((d) => d.id != doc.id).toList();
        if (result < visibleTargets.length) {
          final targetDoc = visibleTargets[result];
          final insertIdx = globalList.indexWhere((d) => d.id == targetDoc.id);
          globalList.insert(
              insertIdx != -1 ? insertIdx : globalList.length, itemToMove);
        } else {
          globalList.add(itemToMove);
        }

        await _service.saveAll(globalList);
        if (!mounted) return;
        setState(() {});
      } else if (result is String) {
        String? selectedFolderId;
        if (result == 'select_folder') {
          if (!mounted) return;
          selectedFolderId = await showDialog<String?>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.selectFolder),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: folders
                      .map((f) => ListTile(
                            leading:
                                const Icon(Icons.folder, color: Colors.amber),
                            title: Text(f.name),
                            onTap: () => Navigator.pop(ctx, f.id),
                          ))
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.cancel)),
              ],
            ),
          );
          if (selectedFolderId == null) return;
        } else {
          selectedFolderId = result;
        }

        final clearParent = selectedFolderId == 'root';
        final newParentId = clearParent ? null : selectedFolderId;
        if (doc.parentId != newParentId) {
          final updatedDoc = doc.copyWith(
            parentId: newParentId,
            clearParentId: clearParent,
          );
          await _service.update(updatedDoc);
          if (!mounted) return;
          setState(() {});
          _showSnack(l10n.documentMoved);
        }
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showImportCompleteDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).ok),
          ),
        ],
      ),
    );
  }

  Future<void> _exportDocument(DocumentItem doc) async {
    String? format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).exportDocument),
        content: Text(AppLocalizations.of(context).exportFormatPrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'txt'),
            child: Text(AppLocalizations.of(context).textFormat),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'pdf'),
            child: Text(AppLocalizations.of(context).pdfFormat),
          ),
        ],
      ),
    );

    if (format == null || !mounted) return;

    try {
      await AppLogger.log('Inizio esportazione documento in formato $format');
      final text = await _exportTextForDocument(doc);
      await AppLogger.log(
          'Testo estratto correttamente (lunghezza: ${text.length})');

      final appDir = await getTemporaryDirectory();
      final baseName = doc.displayName;

      if (format == 'txt') {
        final path = '${appDir.path}/${baseName}_export.txt';
        await AppLogger.log('Scrittura file txt in: $path');
        await File(path).writeAsString(text);
        await AppLogger.log('File txt scritto, avvio condivisione');
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path)],
            text: p.basename(path),
          ),
        );
        await AppLogger.log('Condivisione file txt completata o chiusa');
      } else if (format == 'pdf') {
        await AppLogger.log('Inizio generazione PDF');
        final path = await _generatePdf(baseName, text, appDir.path);
        await AppLogger.log('PDF generato in: $path, avvio condivisione');
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path)],
            text: p.basename(path),
          ),
        );
        await AppLogger.log('Condivisione PDF completata o chiusa');
      }
    } catch (e) {
      dev.log('Errore durante l\'esportazione: $e');
      await AppLogger.log('Errore esportazione: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${AppLocalizations.of(context).exportError}: $e')),
        );
      }
    }
  }

  Future<String> _exportTextForDocument(DocumentItem doc) async {
    final l10n = AppLocalizations.of(context);
    await AppLogger.log('Cerco file modificato per ${doc.id}');
    final editedPath = await _service.resolveEditedFilePath(doc);
    if (editedPath != null && await File(editedPath).exists()) {
      await AppLogger.log('Trovato file modificato, lettura...');
      final text = await File(editedPath).readAsString();
      if (text.trim().isNotEmpty) return text;
      throw Exception(l10n.modifiedDocumentNoExportableText);
    }

    await AppLogger.log('Cerco file originale per ${doc.id}');
    final resolvedPath = await _service.resolveFilePath(doc);
    await AppLogger.log(
        'Estrazione testo da file originale (estensione: ${doc.extension})');
    final result = await DocumentTextExtractor().extract(
      path: resolvedPath,
      extension: doc.extension,
    );
    if (result.text.trim().isEmpty) {
      throw Exception(result.error ?? l10n.noExportableTextFound);
    }
    return result.text;
  }

  String _sanitizeTextForPdf(String text) {
    var sanitized = text
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('…', '...')
        .replaceAll('€', 'EUR')
        .replaceAll('™', '(TM)')
        .replaceAll('\u200B', '') // Zero width space
        .replaceAll('\uFEFF', '') // Byte order mark
        .replaceAll('\r\n', '\n');

    // PdfStandardFont supporta solo caratteri 0-255 (WinAnsi)
    return sanitized.replaceAllMapped(RegExp(r'[^\x00-\xFF]'), (match) => '?');
  }

  Future<String> _generatePdf(
      String baseName, String text, String outDir) async {
    final PdfDocument document = PdfDocument();
    final PdfPage page = document.pages.add();
    final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);

    final safeText = _sanitizeTextForPdf(text);

    final PdfTextElement element = PdfTextElement(
      text: safeText,
      font: font,
    );

    element.draw(
      page: page,
      bounds: Rect.fromLTWH(
          0, 0, page.getClientSize().width, page.getClientSize().height),
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

  Future<void> _openDocument(DocumentItem doc) async {
    if (doc.isFolder) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentsScreen(folderId: doc.id),
        ),
      );
      if (mounted) {
        await _service.load();
        setState(() {});
      }
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentReaderScreen(document: doc),
        settings: const RouteSettings(name: '/documents/reader'),
      ),
    );
    if (mounted) {
      await _service.load();
      setState(() {});
    }
  }

  Future<void> _createDocument() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DocumentEditorScreen(service: _service),
      ),
    );
    if (result == true && mounted) {
      await _load();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final docs = _displayedDocs;
    final currentFolderName = widget.folderId != null
        ? _service.documents
            .firstWhere((d) => d.id == widget.folderId,
                orElse: () => _service.documents.first)
            .name
        : l10n.documents;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentFolderName),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add),
            tooltip: l10n.writeNewDocument,
            onPressed: _createDocument,
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'new_folder') {
                final ctrl = TextEditingController();
                final name = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(AppLocalizations.of(context).newFolder),
                    content: TextField(
                      controller: ctrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).folderNameHint,
                      ),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(AppLocalizations.of(context).cancel)),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, ctrl.text),
                          child: Text(AppLocalizations.of(context).create)),
                    ],
                  ),
                );
                if (name != null && name.trim().isNotEmpty) {
                  await _service.createFolder(name.trim(),
                      parentId: widget.folderId);
                  setState(() {});
                }
              } else if (value == 'dropbox') {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        DropboxBrowserScreen(documentService: _service),
                  ),
                );
                if (mounted) {
                  await _load();
                  setState(() {});
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'new_folder',
                child: Text(AppLocalizations.of(context).createNewFolder),
              ),
              PopupMenuItem(
                value: 'dropbox',
                child: Text(AppLocalizations.of(context).importFromDropbox),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _ErrorState(message: _errorMessage!)
                : docs.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final isFirst = index == 0;
                          final isLast = index == docs.length - 1;

                          return _DocumentTile(
                            doc: doc,
                            isFirst: isFirst,
                            isLast: isLast,
                            onOpen: () => _openDocument(doc),
                            onRemove: () => _remove(doc.id),
                            onExport: () => _exportDocument(doc),
                            onAction: (action) => _handleAction(action, doc),
                          );
                        },
                      ),
      ),
      floatingActionButton: Semantics(
        button: true,
        label: l10n.addDocumentToLibraryHint,
        excludeSemantics: true,
        child: FloatingActionButton(
          onPressed: _pickFile,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile documento
// ---------------------------------------------------------------------------

class _DocumentTile extends StatelessWidget {
  final DocumentItem doc;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final VoidCallback onExport;
  final ValueChanged<_DocumentAction> onAction;

  const _DocumentTile({
    required this.doc,
    required this.isFirst,
    required this.isLast,
    required this.onOpen,
    required this.onRemove,
    required this.onExport,
    required this.onAction,
  });

  Color _badgeColor(String ext) {
    switch (ext) {
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
      case 'rtf':
      case 'odt':
        return Colors.orange.shade700;
      case 'folder':
        return Colors.amber.shade700;
      default:
        return Colors.purple.shade700;
    }
  }

  String _formattedDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final badgeColor = _badgeColor(doc.extension);
    final displayName = doc.displayName;

    return MergeSemantics(
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(
              label: doc.isFolder
                  ? l10n.removeFolder
                  : l10n.removeDocument): onRemove,
          CustomSemanticsAction(label: l10n.exportDocument): onExport,
          if (!isFirst)
            CustomSemanticsAction(label: l10n.moveUp): () =>
                onAction(_DocumentAction.moveUp),
          if (!isLast)
            CustomSemanticsAction(label: l10n.moveDown): () =>
                onAction(_DocumentAction.moveDown),
          CustomSemanticsAction(label: l10n.moveToPosition): () =>
              onAction(_DocumentAction.moveToPosition),
        },
        label:
            '${doc.isFolder ? l10n.folderTypeLabel : l10n.documentTypeLabel} $displayName, ${doc.isFolder ? '' : '${l10n.documentTypeDescription(doc.extension.toUpperCase())}, '}${l10n.documentAddedOn(_formattedDate(doc.addedAt))}',
        hint: doc.isFolder ? l10n.openFolderHint : l10n.openDocumentHint,
        child: Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Badge estensione
                  ExcludeSemantics(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: doc.isFolder
                          ? const Icon(Icons.folder,
                              color: Colors.white, size: 28)
                          : Text(
                              doc.extension.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Nome e data
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.documentAddedOn(_formattedDate(doc.addedAt)),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Pulsante rimuovi
                  ExcludeSemantics(
                    child: Semantics(
                      button: true,
                      label: l10n.removeItem(displayName),
                      child: IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error),
                        tooltip: doc.isFolder
                            ? l10n.removeFolder
                            : l10n.removeDocument,
                        onPressed: onRemove,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _DocumentAction { moveUp, moveDown, moveToPosition }

class _DocumentPositionSliderDialog extends StatefulWidget {
  final int currentIndex;
  final List<DocumentItem> documents;
  final List<DocumentItem> allFolders;
  final String? currentFolderId;

  const _DocumentPositionSliderDialog({
    required this.currentIndex,
    required this.documents,
    required this.allFolders,
    required this.currentFolderId,
  });

  @override
  State<_DocumentPositionSliderDialog> createState() =>
      _DocumentPositionSliderDialogState();
}

class _DocumentPositionSliderDialogState
    extends State<_DocumentPositionSliderDialog> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.currentIndex.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pos = _value.toInt();
    final targetDocuments = widget.documents
        .where((d) => d.id != widget.documents[widget.currentIndex].id)
        .toList();
    final maxPosition = targetDocuments.length;

    String positionLabel(int position) {
      if (position >= targetDocuments.length) {
        return l10n.positionLabelLast;
      }
      final targetName = targetDocuments[position].displayName;
      return l10n.positionLabel(position + 1, targetName);
    }

    void setPosition(int position) {
      setState(() {
        _value = position.clamp(0, maxPosition).toDouble();
      });
    }

    final label = positionLabel(pos);
    final increasedPosition = pos < maxPosition ? pos + 1 : maxPosition;
    final decreasedPosition = pos > 0 ? pos - 1 : 0;

    return AlertDialog(
      title: Text(AppLocalizations.of(context).moveDocument),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Semantics(
            slider: true,
            label: l10n.moveDocument,
            value: label,
            increasedValue: positionLabel(increasedPosition),
            decreasedValue: positionLabel(decreasedPosition),
            onIncrease: pos < maxPosition ? () => setPosition(pos + 1) : null,
            onDecrease: pos > 0 ? () => setPosition(pos - 1) : null,
            child: ExcludeSemantics(
              child: Slider(
                value: _value,
                min: 0,
                max: maxPosition.toDouble(),
                divisions: maxPosition > 0 ? maxPosition : null,
                label: (pos + 1).toString(),
                onChanged: (value) {
                  setState(() {
                    _value = value;
                  });
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.currentFolderId != null)
          TextButton(
            onPressed: () => Navigator.pop(context, 'root'),
            child: Text(AppLocalizations.of(context).outOfFolder),
          ),
        if (widget.allFolders.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, 'select_folder'),
            child: Text(AppLocalizations.of(context).moveToAnotherFolder),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, pos),
          child: Text(AppLocalizations.of(context).ok),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stato vuoto
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).noDocumentsInLibrary,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stato errore
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
