import 'package:flutter/material.dart';

import '../models/document_item.dart';
import '../services/parafarmaco_service.dart';
import '../utils/status_message.dart';
import 'document_reader_screen.dart';

class ParafarmacoDetailScreen extends StatefulWidget {
  final ParafarmacoSearchResult product;

  const ParafarmacoDetailScreen({super.key, required this.product});

  @override
  State<ParafarmacoDetailScreen> createState() => _ParafarmacoDetailScreenState();
}

class _ParafarmacoDetailScreenState extends State<ParafarmacoDetailScreen> {
  final _service = ParafarmacoService();
  bool _loading = true;
  ParafarmacoDetail? _detail;
  ParafarmacoSectionType? _openingSection;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await _service.loadDetail(widget.product);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Errore apertura scheda prodotto: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openSection(ParafarmacoSectionType type) async {
    final detail = _detail;
    if (detail == null) return;

    setState(() => _openingSection = type);
    try {
      final file = await _service.saveSectionAsText(detail, type);
      if (!mounted) return;
      final docItem = DocumentItem(
        id: 'parafarmaco_${DateTime.now().millisecondsSinceEpoch}_${type.name}',
        name: '${detail.name} - ${type.label}',
        path: file.path,
        extension: 'txt',
        addedAt: DateTime.now(),
        isTemporary: true,
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentReaderScreen(document: docItem),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showStatusMessage(context, 'Errore apertura scheda: $e');
    } finally {
      if (mounted) setState(() => _openingSection = null);
    }
  }

  Widget _sectionTile({
    required IconData icon,
    required ParafarmacoSectionType type,
    required String subtitle,
  }) {
    final loading = _openingSection == type;
    return ListTile(
      leading: Icon(icon),
      title: Text(type.label),
      subtitle: Text(subtitle),
      trailing: loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: loading ? null : () => _openSection(type),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;
    final detail = _detail;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail?.name ?? product.name,
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              detail?.category ?? product.category,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if ((detail?.sourceName ?? product.sourceName) !=
                                'Codifa/Farmadati') ...[
                              const SizedBox(height: 6),
                              Text(
                                'Fonte: ${detail?.sourceName ?? product.sourceName}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            if ((detail?.code ?? product.code)?.trim().isNotEmpty ?? false)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Codice: ${detail?.code ?? product.code}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            if ((detail?.sourceName ?? product.sourceName) !=
                                'Codifa/Farmadati') ...[
                              const SizedBox(height: 8),
                              Text(
                                'Le informazioni possono provenire da schede prodotto non AIFA. Verifica sempre confezione, medico o farmacista.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      _sectionTile(
                        icon: Icons.help_outline,
                        type: ParafarmacoSectionType.indications,
                        subtitle: 'Indicazioni, descrizione o a cosa serve.',
                      ),
                      _sectionTile(
                        icon: Icons.medication,
                        type: ParafarmacoSectionType.usage,
                        subtitle: 'Modalità d’uso, dosaggio o posologia se presenti.',
                      ),
                      _sectionTile(
                        icon: Icons.warning_amber,
                        type: ParafarmacoSectionType.warnings,
                        subtitle: 'Avvertenze, precauzioni o controindicazioni se presenti.',
                      ),
                      _sectionTile(
                        icon: Icons.inventory_2_outlined,
                        type: ParafarmacoSectionType.composition,
                        subtitle: 'Componenti, ingredienti o composizione.',
                      ),
                      const Divider(),
                      _sectionTile(
                        icon: Icons.menu_book,
                        type: ParafarmacoSectionType.complete,
                        subtitle: 'Scheda completa o bugiardino disponibile.',
                      ),
                    ],
                  ),
      ),
    );
  }
}
