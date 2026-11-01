import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../models/document_item.dart';
import '../services/document_library_service.dart';
import '../services/cloud_file_picker_service.dart';
import '../services/document_text_extractor.dart';
import '../services/app_settings_service.dart';
import '../services/news_service.dart';
import '../services/news_translation_service.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';
import '../widgets/document_password_dialog.dart';
import '../widgets/universal_accessible_view.dart';
import 'news_webview_screen.dart' show NewsTranslationProgressView;

const _translationFileExtensions = [
  'txt',
  'md',
  'html',
  'htm',
  'rtf',
  'pdf',
  'epub',
  'docx',
  'doc',
];

class TranslationChoiceSlider extends StatelessWidget {
  const TranslationChoiceSlider({
    super.key,
    required this.title,
    required this.labels,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final List<String> labels;
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExcludeSemantics(child: Text(AppLocalizations.of(context).radioScheduleLabeledValue(title, labels[value]))),
      Semantics(
        label: title,
        child: Slider(
          value: value.toDouble(),
          min: 0,
          max: (labels.length - 1).toDouble(),
          divisions: labels.length - 1,
          semanticFormatterCallback: (v) => labels[v.round()],
          onChanged: (v) => onChanged(v.round()),
        ),
      ),
    ],
  );
}

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({super.key, this.createTranslator});
  final NewsTranslationService Function()? createTranslator;
  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  final _text = TextEditingController();
  final _languages = NewsLanguage.values
      .where((l) => l != NewsLanguage.portugueseBrazil)
      .toList();
  int _source = 0;
  int? _target;
  int _fileGeneration = 0;
  bool _readingFile = false;
  bool _choosingFile = false;
  bool _opening = false;
  String? _fileName;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _target ??= _languages.indexWhere(
      (l) =>
          NewsTranslationService.normalizeLanguage(l.code) ==
          Localizations.localeOf(context).languageCode,
    );
    if (_target! < 0) _target = 0;
  }

  @override
  void dispose() {
    _fileGeneration++;
    _text.dispose();
    super.dispose();
  }

  Future<void> _chooseFile() async {
    if (_readingFile || _opening || _choosingFile) return;
    _choosingFile = true;
    final l10n = AppLocalizations.of(context);
    final generation = ++_fileGeneration;
    try {
      final fromLibrary = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.translationChooseFile),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.translationLibraryDocuments),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.audioDescriptionBrowseProject),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      );
      if (!mounted || fromLibrary == null || generation != _fileGeneration) {
        return;
      }
      final String path, name, extension;
      if (fromLibrary) {
        final library = DocumentLibraryService();
        final doc = await Navigator.push<DocumentItem>(
          context,
          MaterialPageRoute(
            builder: (_) => TranslationDocumentPickerScreen(library: library),
          ),
        );
        if (!mounted || doc == null || generation != _fileGeneration) return;
        final edited = await library.resolveEditedFilePath(doc);
        final useEdited = edited != null && await File(edited).exists();
        path = useEdited ? edited : await library.resolveFilePath(doc);
        name = doc.name;
        extension = useEdited ? 'txt' : doc.extension.toLowerCase();
      } else {
        final selected = await CloudFilePicker.pickFiles(
          context: context,
          type: FileType.custom,
          allowedExtensions: _translationFileExtensions,
        );
        if (!mounted || generation != _fileGeneration || selected == null) {
          return;
        }
        final file = selected.files.single;
        if (file.path == null) throw StateError('Missing file');
        path = file.path!;
        name = file.name;
        extension = p.extension(file.name).substring(1).toLowerCase();
      }
      if (!mounted || generation != _fileGeneration) return;
      setState(() => _readingFile = true);
      final extractor = DocumentTextExtractor();
      var result = await extractor.extract(
        path: path,
        extension: extension,
        includeEpubFootnotesInText: await AppSettingsService()
            .includeEpubFootnotesInText(),
        footnoteLabel: l10n.documentFootnoteLabel,
      );
      String? password;
      while (result.passwordRequired) {
        if (!mounted || generation != _fileGeneration) return;
        password = await showDialog<String>(
          context: context,
          builder: (_) => DocumentPasswordDialog(
            title: l10n.documentPasswordRequiredTitle,
            prompt: l10n.enterDocumentPasswordToOpen,
            passwordLabel: l10n.documentPassword,
            confirmPasswordLabel: l10n.confirmDocumentPassword,
            requiredMessage: l10n.documentPasswordRequired,
            mismatchMessage: l10n.documentPasswordsDoNotMatch,
            invalidMessage: l10n.incorrectDocumentPassword,
            initialError: password == null
                ? null
                : l10n.incorrectDocumentPassword,
          ),
        );
        if (password == null || !mounted || generation != _fileGeneration) {
          return;
        }
        result = await extractor.extract(
          path: path,
          extension: extension,
          pdfPassword: password,
        );
      }
      if (!mounted || generation != _fileGeneration) return;
      if (result.text.trim().isEmpty) throw StateError('Empty extraction');
      setState(() {
        _text.text = result.text;
        _fileName = name;
      });
    } catch (error) {
      await AppLogger.log('Translator file failed type=${error.runtimeType}');
      if (mounted && generation == _fileGeneration) {
        showStatusMessage(context, l10n.technicalErrorGeneric);
      }
    } finally {
      _choosingFile = false;
      if (mounted && generation == _fileGeneration) {
        setState(() => _readingFile = false);
      }
    }
  }

  Future<void> _start() async {
    if (_opening || _readingFile) return;
    final original = _text.text;
    if (original.trim().isEmpty) {
      showStatusMessage(context, AppLocalizations.of(context).noTextToRead);
      return;
    }
    FocusScope.of(context).unfocus();
    _opening = true;
    try {
      final result = await Navigator.of(context).push<NewsTranslation>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/translator/progress'),
          builder: (_) => TranslatorProgressScreen(
            text: original,
            source: _source == 0 ? 'auto' : _languages[_source - 1].code,
            target: _languages[_target!].code,
            createTranslator: widget.createTranslator,
          ),
        ),
      );
      if (!mounted || result == null) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/translator/result'),
          builder: (_) => TranslatorResultScreen(
            original: original,
            translation: result,
            sourceName: _fileName,
          ),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = _languages.map((l) => l.label(l10n)).toList();
    return Scaffold(
      appBar: SonarpadAppBar(title: Text(l10n.translatorTitle)),
      body: _readingFile
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(semanticsLabel: l10n.loading),
                  Text(l10n.loading),
                  TextButton(
                    onPressed: () {
                      _fileGeneration++;
                      setState(() => _readingFile = false);
                    },
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TranslationChoiceSlider(
                  title: l10n.translationSourceLanguage,
                  labels: [l10n.translationDetectLanguage, ...labels],
                  value: _source,
                  onChanged: (v) => setState(() => _source = v),
                ),
                TranslationChoiceSlider(
                  title: l10n.translationTargetLanguage,
                  labels: labels,
                  value: _target!,
                  onChanged: (v) => setState(() => _target = v),
                ),
                TextField(
                  controller: _text,
                  minLines: 5,
                  maxLines: 12,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: l10n.translationInputText,
                  ),
                ),
                if (_fileName != null) Text(_fileName!),
                TextButton.icon(
                  onPressed: _chooseFile,
                  icon: const Icon(Icons.folder_open),
                  label: Text(l10n.translationChooseFile),
                ),
                ElevatedButton(
                  onPressed: _start,
                  child: Text(l10n.startTranslation),
                ),
              ],
            ),
    );
  }
}

class TranslationDocumentPickerScreen extends StatefulWidget {
  const TranslationDocumentPickerScreen({super.key, required this.library});
  final DocumentLibraryService library;
  @override
  State<TranslationDocumentPickerScreen> createState() =>
      _TranslationDocumentPickerScreenState();
}

class _TranslationDocumentPickerScreenState
    extends State<TranslationDocumentPickerScreen> {
  bool _loading = true, _failed = false, _opening = false;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await widget.library.load();
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _select(DocumentItem doc) async {
    if (_opening) return;
    _opening = true;
    try {
      if (doc.isPasswordProtected) {
        final l10n = AppLocalizations.of(context);
        final password = await showDialog<String>(
          context: context,
          builder: (_) => DocumentPasswordDialog(
            title: l10n.documentPasswordRequiredTitle,
            prompt: l10n.enterDocumentPasswordToOpen,
            passwordLabel: l10n.documentPassword,
            confirmPasswordLabel: l10n.confirmDocumentPassword,
            requiredMessage: l10n.documentPasswordRequired,
            mismatchMessage: l10n.documentPasswordsDoNotMatch,
            invalidMessage: l10n.incorrectDocumentPassword,
            validator: (value) =>
                widget.library.verifyDocumentPassword(doc, value),
          ),
        );
        if (!mounted || password == null) return;
      }
      if (mounted) Navigator.pop(context, doc);
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final documents = widget.library.documents
        .where(
          (d) =>
              !d.isFolder &&
              _translationFileExtensions.contains(d.extension.toLowerCase()) &&
              d.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: SonarpadAppBar(title: Text(l10n.translationLibraryDocuments)),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(semanticsLabel: l10n.loading),
            )
          : UniversalAccessibleList(
              sections: [
                AccessibleListSection(
                  rows: [
                    AccessibleListRow(
                      id: 'document_search',
                      title: l10n.search,
                      kind: 'textField',
                      value: _query,
                      onValueChanged: (value) =>
                          setState(() => _query = value?.toString() ?? ''),
                    ),
                    if (_failed || documents.isEmpty)
                      AccessibleListRow(
                        id: 'document_empty',
                        title: _failed
                            ? l10n.technicalErrorGeneric
                            : l10n.noDocumentsInLibrary,
                        kind: 'text',
                      ),
                    if (!_failed)
                      for (final doc in documents)
                        AccessibleListRow(
                          id: doc.id,
                          title: doc.displayName,
                          kind: 'button',
                          value: doc.isPasswordProtected
                              ? l10n.documentPasswordProtectedStatus
                              : null,
                          onActivate: () => _select(doc),
                        ),
                  ],
                ),
              ],
            ),
    );
  }
}

class TranslatorProgressScreen extends StatefulWidget {
  const TranslatorProgressScreen({
    super.key,
    required this.text,
    required this.source,
    required this.target,
    this.createTranslator,
  });
  final String text, source, target;
  final NewsTranslationService Function()? createTranslator;
  @override
  State<TranslatorProgressScreen> createState() =>
      _TranslatorProgressScreenState();
}

class _TranslatorProgressScreenState extends State<TranslatorProgressScreen> {
  late final _job = widget.createTranslator?.call() ?? NewsTranslationService();
  double _progress = 0;
  String? _error;
  bool _cancelled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _cancelled = true;
    _job.close();
    super.dispose();
  }

  Future<void> _run() async {
    if (!mounted || _cancelled) return;
    try {
      final result = await _job.translateArticle(
        title: '',
        text: widget.text,
        sourceLanguage: widget.source,
        targetLanguage: widget.target,
        onProgress: (done, total) {
          if (mounted && !_cancelled) setState(() => _progress = done / total);
        },
      );
      if (mounted && !_cancelled) Navigator.pop(context, result);
    } catch (error) {
      await AppLogger.log('Translator failed type=${error.runtimeType}');
      if (mounted && !_cancelled) {
        setState(
          () => _error = AppLocalizations.of(context).technicalErrorGeneric,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: SonarpadAppBar(title: Text(l10n.newsTranslating)),
      body: _error == null
          ? NewsTranslationProgressView(
              progress: _progress,
              onCancel: () {
                _cancelled = true;
                _job.close();
                Navigator.pop(context);
              },
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.ok),
                  ),
                ],
              ),
            ),
    );
  }
}

class TranslatorResultScreen extends StatefulWidget {
  const TranslatorResultScreen({
    super.key,
    required this.original,
    required this.translation,
    this.sourceName,
  });
  final String original;
  final NewsTranslation translation;
  final String? sourceName;
  @override
  State<TranslatorResultScreen> createState() => _TranslatorResultScreenState();
}

class _TranslatorResultScreenState extends State<TranslatorResultScreen> {
  int _selected = 0;
  bool _saving = false;
  String _exportText(AppLocalizations l10n) => widget.translation.isPartial
      ? '${l10n.documentTranslationPartial}\n\n${widget.translation.text}'
      : widget.translation.text;
  Future<void> _save({bool share = false}) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    if (!share) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.translationSave),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.saveInSonarpad),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.share),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      share = choice;
    }
    setState(() => _saving = true);
    try {
      final name =
          '${widget.sourceName == null ? l10n.translatorTitle : p.basenameWithoutExtension(widget.sourceName!)}_${l10n.documentTranslatedSuffix}.txt';
      final content = _exportText(l10n);
      if (share) {
        final dir = await Directory(
          (await getTemporaryDirectory()).path,
        ).createTemp('translation-');
        final file = await File(p.join(dir.path, name)).writeAsString(content);
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      } else {
        final library = DocumentLibraryService();
        final document = await library.createTextDocument(
          name: name,
          content: content,
        );
        await library.add(document);
        if (mounted) showStatusMessage(context, l10n.exportSavedInSonarpad);
      }
    } catch (error) {
      await AppLogger.log('Translator export failed type=${error.runtimeType}');
      if (mounted) showStatusMessage(context, l10n.technicalErrorGeneric);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: SonarpadAppBar(title: Text(l10n.translationResult)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TranslationChoiceSlider(
            title: l10n.translationResult,
            labels: [
              l10n.translationTranslatedText,
              l10n.translationOriginalText,
            ],
            value: _selected,
            onChanged: (v) => setState(() => _selected = v),
          ),
          if (widget.translation.isPartial && _selected == 0)
            Text(l10n.documentTranslationPartial),
          SelectableText(
            _selected == 0 ? widget.translation.text : widget.original,
          ),
          ElevatedButton(
            onPressed: _saving ? null : () => _save(),
            child: Text(l10n.translationSave),
          ),
          TextButton(
            onPressed: _saving ? null : () => _save(share: true),
            child: Text(l10n.share),
          ),
        ],
      ),
    );
  }
}
