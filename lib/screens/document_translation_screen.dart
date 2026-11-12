import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/document_item.dart';
import '../services/document_library_service.dart';
import '../services/news_service.dart';
import '../services/news_translation_service.dart';
import '../utils/app_logger.dart';
import '../widgets/universal_accessible_view.dart';
import 'news_webview_screen.dart' show NewsTranslationProgressView;

/// Saves text in a new, collision-safe file; never writes to the source path.
Future<DocumentItem> saveDocumentTranslation({
  required DocumentLibraryService library,
  required DocumentItem source,
  required NewsTranslation result,
  required String suffix,
  required String partialNotice,
}) async {
  if (result.text.trim().isEmpty) throw StateError('Empty translation');
  final content = result.isPartial
      ? '$partialNotice\n\n${result.text}'
      : result.text;
  final doc = await library.createTextDocument(
    name: '${source.displayName}_$suffix.txt',
    content: content,
    parentId: source.parentId,
  );
  await library.add(doc);
  return doc;
}

class DocumentTranslationScreen extends StatefulWidget {
  const DocumentTranslationScreen({
    super.key,
    required this.document,
    required this.loadText,
    this.library,
    this.createTranslator,
  });
  final DocumentItem document;
  final Future<String> Function() loadText;
  final DocumentLibraryService? library;
  final NewsTranslationService Function()? createTranslator;

  @override
  State<DocumentTranslationScreen> createState() =>
      _DocumentTranslationScreenState();
}

class _DocumentTranslationScreenState extends State<DocumentTranslationScreen> {
  final _languages = NewsLanguage.values
      .where((l) => l != NewsLanguage.portugueseBrazil)
      .toList();
  int? _selected;
  NewsTranslationService? _job;
  NewsTranslation? _result;
  bool _saving = false;
  double _progress = 0;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selected ??= _languages.indexWhere(
      (l) =>
          NewsTranslationService.normalizeLanguage(l.code) ==
          Localizations.localeOf(context).languageCode,
    );
    if (_selected! < 0) _selected = 0;
  }

  @override
  void dispose() {
    _job?.close();
    super.dispose();
  }

  void _cancel() {
    _job?.close();
    setState(() {
      _job = null;
      _progress = 0;
    });
  }

  Future<void> _start() async {
    if (_job != null || _saving) return;
    final l10n = AppLocalizations.of(context);
    final job = widget.createTranslator?.call() ?? NewsTranslationService();
    setState(() {
      _job = job;
      _progress = 0;
      _error = null;
    });
    try {
      if (_result == null) {
        final text = await widget.loadText();
        if (!mounted || _job != job) return;
        // The source filename is retained, rather than translated as a title.
        _result = await job.translateArticle(
          title: '',
          text: text,
          targetLanguage: _languages[_selected!].code,
          onProgress: (done, total) {
            if (mounted && _job == job) {
              setState(() => _progress = done / total);
            }
          },
        );
      }
      if (!mounted || _job != job) {
        _result = null;
        return;
      }
      setState(() {
        _saving = true;
        _job = null;
      });
      final doc = await saveDocumentTranslation(
        library: widget.library ?? DocumentLibraryService(),
        source: widget.document,
        result: _result!,
        suffix: l10n.documentTranslatedSuffix,
        partialNotice: l10n.documentTranslationPartial,
      );
      await AppLogger.log(
        'Document translation saved partial=${_result!.isPartial} chars=${_result!.text.length}',
      );
      if (!mounted) return;
      if (_result!.isPartial) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(l10n.translateDocument),
            content: Text(l10n.documentTranslationPartial),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.ok),
              ),
            ],
          ),
        );
      }
      if (mounted) Navigator.pop(context, doc);
    } catch (error) {
      if (!mounted || (_job != job && !_saving)) return;
      // Keep the translated text in memory if local saving fails, so Retry
      // saves that same result without making new translation requests.
      setState(() {
        _job = null;
        _saving = false;
        _error = l10n.technicalErrorGeneric;
      });
      await AppLogger.log(
        'Document translation failed type=${error.runtimeType} retained=${_result != null}',
      );
    } finally {
      job.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = _languages.map((l) => l.label(l10n)).toList();
    final index = _selected!;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: SonarpadAppBar(title: Text(l10n.translateDocument)),
        body: _saving
            ? Center(
                child: CircularProgressIndicator(semanticsLabel: l10n.loading),
              )
            : _job != null
            ? NewsTranslationProgressView(
                progress: _progress,
                onCancel: _cancel,
              )
            : UniversalAccessibleList(
                sections: [
                  AccessibleListSection(
                    rows: [
                      AccessibleListRow(
                        id: 'translation_format',
                        title: l10n.documentTranslationTextOnly,
                        kind: 'text',
                      ),
                      if (_error != null)
                        AccessibleListRow(
                          id: 'translation_error',
                          title: _error!,
                          kind: 'text',
                        ),
                      if (_result == null)
                        AccessibleListRow(
                          id: 'translation_language',
                          title: l10n.translationTargetLanguage,
                          kind: 'slider',
                          value: '$index',
                          valueLabel: labels[index],
                          options: [
                            for (var i = 0; i < labels.length; i++)
                              AccessibleOption(value: '$i', label: labels[i]),
                          ],
                          sliderValue: index.toDouble(),
                          sliderMin: 0,
                          sliderMax: (labels.length - 1).toDouble(),
                          sliderStep: 1,
                          sliderIncreasedValueLabel:
                              labels[(index + 1).clamp(0, labels.length - 1)],
                          sliderDecreasedValueLabel:
                              labels[(index - 1).clamp(0, labels.length - 1)],
                          onValueChanged: (value) {
                            final n = double.tryParse('$value');
                            if (n != null && n.isFinite) {
                              setState(
                                () => _selected = n.round().clamp(
                                  0,
                                  labels.length - 1,
                                ),
                              );
                            }
                          },
                        ),
                      AccessibleListRow(
                        id: 'translation_start',
                        title: _result == null
                            ? l10n.startTranslation
                            : l10n.retry,
                        kind: 'button',
                        onActivate: _start,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
