import 'package:flutter/material.dart';

import '../models/document_item.dart';
import '../services/aifa_pdf_parser.dart';
import '../services/aifa_service.dart';
import 'document_reader_screen.dart';
import '../utils/status_message.dart';

class AifaConfezioniScreen extends StatefulWidget {
  final AifaDrugResult drugGroup;

  const AifaConfezioniScreen({super.key, required this.drugGroup});

  @override
  State<AifaConfezioniScreen> createState() => _AifaConfezioniScreenState();
}

class _AifaConfezioniScreenState extends State<AifaConfezioniScreen> {
  final _service = AifaService();
  AifaConfezione? _downloadingConf;
  String? _error;

  void _showReadingOptions(AifaConfezione conf) {
    showModalBottomSheet(
      context: context,
      barrierLabel: 'Chiudi opzioni farmaco',
      routeSettings: const RouteSettings(name: '/aifa/reading_options'),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: const Text('Indietro'),
                onTap: () => Navigator.pop(context),
              ),
              const Divider(),
              ListTile(
                title: Text(conf.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Scegli cosa leggere:'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('A cosa serve?'),
                onTap: () {
                  Navigator.pop(context);
                  _openDrugPdf(conf, AifaSectionType.aCosaServe);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text("Cosa deve sapere prima dell'uso"),
                onTap: () {
                  Navigator.pop(context);
                  _openDrugPdf(conf, AifaSectionType.cosaDeveSapere);
                },
              ),
              ListTile(
                leading: const Icon(Icons.medication),
                title: const Text("Posologia d'uso"),
                onTap: () {
                  Navigator.pop(context);
                  _openDrugPdf(conf, AifaSectionType.posologia);
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber),
                title: const Text(
                    'Effetti indesiderati, dimenticanze e sovradosaggio'),
                onTap: () {
                  Navigator.pop(context);
                  _openDrugPdf(conf, AifaSectionType.effettiIndesiderati);
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Conservazione e composizione'),
                onTap: () {
                  Navigator.pop(context);
                  _openDrugPdf(conf, AifaSectionType.conservazione);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.menu_book),
                title: const Text('Leggi tutto il bugiardino'),
                onTap: () {
                  Navigator.pop(context);
                  _openDrugPdf(conf, AifaSectionType.leggiTutto);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openDrugPdf(
      AifaConfezione conf, AifaSectionType sectionType) async {
    setState(() {
      _downloadingConf = conf;
      _error = null;
    });

    try {
      final file = await _service.downloadFoglioIllustrativo(conf);

      if (!mounted) return;

      // Estrae la sezione desiderata o restituisce l'intero PDF
      final extractedPath = await AifaPdfParser.extractSectionAndSave(
        file.path,
        sectionType,
        conf.name,
      );

      if (!mounted) return;

      final isPdf = extractedPath.toLowerCase().endsWith('.pdf');

      String sectionName = '';
      switch (sectionType) {
        case AifaSectionType.aCosaServe:
          sectionName = 'A cosa serve';
          break;
        case AifaSectionType.cosaDeveSapere:
          sectionName = 'Avvertenze';
          break;
        case AifaSectionType.posologia:
          sectionName = 'Posologia';
          break;
        case AifaSectionType.effettiIndesiderati:
          sectionName = 'Effetti Indesiderati';
          break;
        case AifaSectionType.conservazione:
          sectionName = 'Conservazione';
          break;
        case AifaSectionType.leggiTutto:
          sectionName = 'Completo';
          break;
      }

      final docItem = DocumentItem(
        id: 'aifa_${conf.aic6}_${sectionType.name}',
        name: 'FI - ${conf.name} ($sectionName)',
        path: extractedPath,
        extension: isPdf ? 'pdf' : 'txt',
        addedAt: DateTime.now(),
      );

      // Apre la schermata di lettura dei documenti
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentReaderScreen(document: docItem),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Errore apertura PDF: $e');
            showStatusMessage(context, 'Errore download PDF: $e');
    } finally {
      if (mounted) {
        setState(() => _downloadingConf = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.drugGroup.denominazione),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: theme.colorScheme.surfaceContainerHighest,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.drugGroup.denominazione,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.drugGroup.principiAttivi,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AIC: ${widget.drugGroup.aic9}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.drugGroup.confezioni.length,
                itemBuilder: (context, index) {
                  final conf = widget.drugGroup.confezioni[index];
                  final isDownloading = _downloadingConf == conf;
                  return ListTile(
                    title: Text(conf.name),
                    trailing: isDownloading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    onTap:
                        isDownloading ? null : () => _showReadingOptions(conf),
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
