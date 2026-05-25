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
import 'document_reader_screen.dart';

/// Schermata libreria documenti.
/// Permette di aggiungere file dal dispositivo (PDF, DOCX, EPUB, TXT, ecc.)
/// e di sfogliarli / leggerli con TTS.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _service = DocumentLibraryService();
  bool _loading = true;
  String? _errorMessage;

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
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _service.load();
    } catch (e) {
      dev.log('DocumentsScreen: errore caricamento: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Errore caricamento libreria: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
      );
    } catch (e) {
      dev.log('DocumentsScreen: errore apertura file picker: $e');
      if (mounted) {
        _showSnack('Errore apertura file: $e');
      }
      return;
    }

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final path = file.path;
    if (path == null) {
      if (mounted) _showSnack('Percorso file non disponibile.');
      return;
    }

    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    final name = p.basename(path);
    final id = '${DateTime.now().microsecondsSinceEpoch}_$name';

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File(p.join(appDir.path, id));
      await File(path).copy(localFile.path);

      final doc = DocumentItem(
        id: id,
        name: name,
        path: id, // Salviamo solo l'ID come percorso relativo
        extension: ext,
        addedAt: DateTime.now(),
      );

      await _service.add(doc);
    } catch (e) {
      dev.log('DocumentsScreen: errore aggiunta documento: $e');
      if (mounted) _showSnack('Errore aggiunta documento: $e');
      return;
    }

    if (mounted) {
      setState(() {});
      _showSnack('Documento aggiunto');
    }
  }

  Future<void> _remove(String id) async {
    try {
      // Troviamo il documento per ottenerne il path e cancellarlo dal disco
      final doc = _service.documents.firstWhere((d) => d.id == id);
      final resolvedPath = await _service.resolveFilePath(doc);
      final file = File(resolvedPath);
      if (await file.exists()) {
        await file.delete();
      }
      
      await _service.remove(id);
    } catch (e) {
      dev.log('DocumentsScreen: errore rimozione documento: $e');
      if (mounted) _showSnack('Errore rimozione: $e');
      return;
    }
    if (mounted) {
      setState(() {});
      _showSnack('Documento rimosso');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _exportDocument(DocumentItem doc) async {
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
      final extractor = DocumentTextExtractor();
      final result = await extractor.extract(path: doc.path, extension: doc.extension);
      final text = result.text;

      final appDir = await getTemporaryDirectory();
      final baseName = doc.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      
      if (format == 'txt') {
        final path = '${appDir.path}/${baseName}_export.txt';
        await File(path).writeAsString(text);
        await Share.shareXFiles([XFile(path)], text: 'Documento esportato da Sonarpad');
      } else if (format == 'pdf') {
        final path = await _generatePdf(baseName, text, appDir.path);
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

  Future<void> _openDocument(DocumentItem doc) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documenti'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _ErrorState(message: _errorMessage!)
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Semantics(
                          hint: 'Sfoglia i file del dispositivo e aggiungili',
                          child: FilledButton.icon(
                            icon: const Icon(Icons.folder_open),
                            label: const Text(
                              'Aggiungi documento alla libreria',
                              style: TextStyle(fontSize: 18),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: _pickFile,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _service.documents.isEmpty
                            ? const _EmptyState()
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                itemCount: _service.documents.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final doc = _service.documents[index];
                                  return _DocumentTile(
                                    doc: doc,
                                    onOpen: () => _openDocument(doc),
                                    onRemove: () => _remove(doc.id),
                                    onExport: () => _exportDocument(doc),
                                  );
                                },
                              ),
                      ),
                    ],
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
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final VoidCallback onExport;

  const _DocumentTile({
    required this.doc,
    required this.onOpen,
    required this.onRemove,
    required this.onExport,
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

    return MergeSemantics(
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: l10n.removeDocument): onRemove,
          CustomSemanticsAction(label: 'Esporta documento'): onExport,
        },
        label: '${doc.name}, tipo ${doc.extension.toUpperCase()}, '
            'aggiunto il ${_formattedDate(doc.addedAt)}',
      hint: 'Tocca per aprire e leggere il documento',
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
                    child: Text(
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
                          doc.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aggiunto il ${_formattedDate(doc.addedAt)}',
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
                    label: 'Rimuovi ${doc.name}',
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Rimuovi documento',
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

// ---------------------------------------------------------------------------
// Stato vuoto
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Nessun documento. Aggiungi un file usando il pulsante in cima.',
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
              'Nessun documento.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Aggiungi un file usando il pulsante in cima.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
