import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/semantics.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/news_article.dart';
import '../services/app_settings_service.dart';
import '../services/news_service.dart';
import '../services/news_sources/news_rss_source.dart';
import 'news_webview_screen.dart';
import '../utils/status_message.dart';
import '../utils/list_timestamp_formatter.dart';
import 'package:sonarpad_mobile_starter/utils/accessibility_list_behavior.dart';
import '../widgets/universal_accessible_view.dart';

class NewsScreen extends StatefulWidget {
  final String? folderId;
  final String? title;
  final NewsLanguage? initialLanguage;

  const NewsScreen({
    super.key,
    this.folderId,
    this.title,
    this.initialLanguage,
  });

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final _service = NewsService();
  NewsLanguage? _language;
  List<NewsRssSource>? _sources;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_language == null) {
      final code = AppLocalizations.of(context).localeName;
      _language = widget.initialLanguage ?? switch (code) {
        'en' => NewsLanguage.english,
        'fr' => NewsLanguage.french,
        'es' => NewsLanguage.spanish,
        'pt' => NewsLanguage.portuguese,
        'pt_BR' => NewsLanguage.portugueseBrazil,
        'pl' => NewsLanguage.polish,
        'cs' => NewsLanguage.czech,
        'de' => NewsLanguage.german,
        'zh_CN' => NewsLanguage.chineseSimplified,
        'uk' => NewsLanguage.ukrainian,
        _ => NewsLanguage.italian,
      };
      _service.prefetchTinyfishFallbackOnlyPolicy();
      _loadSources();
    }
  }

  Future<void> _loadSources() async {
    if (_language == null) return;
    final sources = await _service.getOrderedSources(
      _language!,
      folderId: widget.folderId,
    );
    if (mounted) {
      setState(() {
        _sources = sources;
      });
    }
  }

  void _openSource(NewsRssSource source) {
    if (source.isFolder && source.folderId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/news/folder'),
          builder: (_) => NewsScreen(
            folderId: source.folderId,
            title: source.name,
            initialLanguage: _language!,
          ),
        ),
      ).then((_) => _loadSources());
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/news/source'),
        builder: (_) => _NewsSourceArticlesScreen(
          source: source,
          language: _language!,
        ),
      ),
    );
  }

  Future<void> _restoreSources() async {
    if (_language == null) return;
    await _service.restoreHiddenSources(_language!);
    await _loadSources();
  }

  Future<void> _addCustomSource() async {
    if (_language == null) return;
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).addRssSource),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).newsSourceName,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).newsSourceUrlOrSearch,
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).add),
          ),
        ],
      ),
    );

    if (result != true) return;

    final name = nameCtrl.text.trim();
    final url = urlCtrl.text.trim();
    if (url.isEmpty) return;

    try {
      await _service.addCustomSource(
        _language!,
        name,
        url,
        parentFolderId: widget.folderId,
      );
      await _loadSources();
    } catch (e) {
      if (!mounted) return;
            final l10n = AppLocalizations.of(context);
      showStatusMessage(context, '${l10n.errorPrefix}: ${l10n.technicalErrorGeneric}');
    }
  }

  Future<void> _addCommunitySource() async {
    if (_language == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/news/community/add'),
        builder: (_) => _AddCommunityNewsSourceScreen(language: _language!),
      ),
    );
  }

  Future<void> _openCommunitySources() async {
    if (_language == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/news/community'),
        builder: (_) => _CommunityNewsSourcesScreen(
          language: _language!,
          parentFolderId: widget.folderId,
        ),
      ),
    );
    await _loadSources();
  }

  Future<void> _createFolder() async {
    if (_language == null || widget.folderId != null) return;
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
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(AppLocalizations.of(context).create),
          ),
        ],
      ),
    );
    final cleanName = name?.trim();
    if (cleanName == null || cleanName.isEmpty) return;
    await _service.createFolder(_language!, cleanName);
    await _loadSources();
  }

  Future<void> _importRssFromOpml() async {
    if (_language == null) return;
    final language = _language!;
    final l10n = AppLocalizations.of(context);

    try {
      // On iOS, some document providers/iCloud folders can gray out .opml
      // files when the picker is restricted to custom extensions. This is
      // already handled this way in Podcasts: let the user select any file,
      // then validate OPML/XML here before importing it.
      final result = await FilePicker.pickFiles(type: FileType.any);
      final path = result == null || result.files.isEmpty
          ? null
          : result.files.first.path;
      if (path == null || path.isEmpty) return;
      final ext = p.extension(path).toLowerCase();
      if (ext != '.opml' && ext != '.xml') {
        if (!mounted) return;
        showStatusMessage(context, l10n.podcastInvalidOpmlFile);
        return;
      }

      final added = await _service.importCustomSourcesFromOpml(
        language,
        File(path),
        parentFolderId: widget.folderId,
      );
      await _loadSources();
      if (!mounted) return;
            showStatusMessage(context, l10n.rssImportComplete(added));
    } catch (e) {
      if (!mounted) return;
            showStatusMessage(context, l10n.rssImportError(l10n.technicalErrorGeneric));
    }
  }

  Future<void> _exportRssToOpml() async {
    if (_language == null) return;
    final language = _language!;
    final l10n = AppLocalizations.of(context);

    try {
      final opml = await _service.exportCustomSourcesToOpml(language);
      final bytes = utf8.encode(opml);
      final path = await FilePicker.saveFile(
        dialogTitle: l10n.exportRssSourcesToOpml,
        fileName: 'Sonarpad RSS.opml',
        type: FileType.custom,
        allowedExtensions: const ['opml'],
        bytes: Uint8List.fromList(bytes),
      );
      if (path == null || path.isEmpty) return;

      if (!mounted) return;
            showStatusMessage(context, l10n.rssExportComplete);
    } catch (e) {
      if (!mounted) return;
            showStatusMessage(context, l10n.rssExportError(l10n.technicalErrorGeneric));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? l10n.news),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addCustomNewsSource,
            onPressed: _addCustomSource,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: l10n.newsAddCommunitySource,
            onPressed: _addCommunitySource,
          ),
          IconButton(
            icon: const Icon(Icons.public),
            tooltip: l10n.newsBrowseCommunitySources,
            onPressed: _openCommunitySources,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: l10n.importRssSourcesFromOpml,
            onPressed: _importRssFromOpml,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: l10n.exportRssSourcesToOpml,
            onPressed: _exportRssToOpml,
          ),
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: l10n.restoreHiddenSources,
            onPressed: _restoreSources,
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.folderId == null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<NewsLanguage>(
                initialValue: _language,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.newsLanguage),
                items: NewsLanguage.values
                    .map(
                      (lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(lang.label(l10n)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _language = value;
                    _sources = null;
                  });
                  _loadSources();
                },
              ),
            ),
          Expanded(
            child: _sources == null
                ? const Center(child: CircularProgressIndicator())
                : _NewsSourceList(
                    sources: _sources!,
                    language: _language!,
                    currentFolderId: widget.folderId,
                    service: _service,
                    onSourceSelected: _openSource,
                    onSourcesChanged: _loadSources,
                    onCreateFolder:
                        widget.folderId == null ? _createFolder : null,
                  ),
          ),
        ],
      ),
    );
  }
}

class _AddCommunityNewsSourceScreen extends StatefulWidget {
  const _AddCommunityNewsSourceScreen({required this.language});

  final NewsLanguage language;

  @override
  State<_AddCommunityNewsSourceScreen> createState() =>
      _AddCommunityNewsSourceScreenState();
}

class _AddCommunityNewsSourceScreenState
    extends State<_AddCommunityNewsSourceScreen> {
  final _service = NewsService();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    if (name.isEmpty || url.isEmpty) {
      showStatusMessage(context, l10n.newsCommunityMissingFields);
      return;
    }

    setState(() => _submitting = true);
    try {
      final message = await _service.addCommunityNewsSource(
        language: widget.language,
        name: name,
        feedUrl: url,
        uiLanguageCode: l10n.localeName,
      );
      if (!mounted) return;
      _nameController.clear();
      _urlController.clear();
      showStatusMessage(
        context,
        message.trim().isEmpty ? l10n.newsCommunityAdded : message.trim(),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showStatusMessage(context, l10n.newsCommunityAddError(l10n.technicalErrorGeneric));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.newsAddCommunitySource)),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [AccessibleListSection(rows: [
                AccessibleListRow(
                  id: 'instructions',
                  kind: 'text',
                  title: l10n.newsAddCommunityInstructions,
                ),
                AccessibleListRow(
                  id: 'name',
                  kind: 'textField',
                  title: l10n.newsCommunitySourceName,
                  value: _nameController.text,
                ),
                AccessibleListRow(
                  id: 'url',
                  kind: 'textField',
                  title: l10n.newsCommunitySourceUrl,
                  value: _urlController.text,
                ),
                AccessibleListRow(
                  id: 'language',
                  kind: 'text',
                  title: l10n.newsCommunitySelectedLanguage(widget.language.label(l10n)),
                ),
                AccessibleListRow(
                  id: 'submit',
                  kind: 'button',
                  title: _submitting ? l10n.newsCommunityChecking : l10n.newsCommunitySubmit,
                  enabled: !_submitting,
                ),
              ])],
              onEvent: (event) {
                if (event.id == 'name' && event.type == 'textChanged') {
                  _nameController.text = event.value?.toString() ?? '';
                } else if (event.id == 'url' && event.type == 'textChanged') {
                  _urlController.text = event.value?.toString() ?? '';
                } else if (event.id == 'submit' && event.type == 'activate' && !_submitting) {
                  _submit();
                }
              },
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.newsAddCommunityInstructions),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.newsCommunitySourceName,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: l10n.newsCommunitySourceUrl,
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.newsCommunitySelectedLanguage(widget.language.label(l10n)),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.cloud_upload),
                  label: Text(_submitting
                      ? l10n.newsCommunityChecking
                      : l10n.newsCommunitySubmit),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CommunityNewsSourcesScreen extends StatefulWidget {
  const _CommunityNewsSourcesScreen({
    required this.language,
    this.parentFolderId,
  });

  final NewsLanguage language;
  final String? parentFolderId;

  @override
  State<_CommunityNewsSourcesScreen> createState() =>
      _CommunityNewsSourcesScreenState();
}

class _CommunityNewsSourcesScreenState
    extends State<_CommunityNewsSourcesScreen> {
  final _service = NewsService();
  late Future<List<NewsRssSource>> _future;
  final Set<String> _addingUrls = {};

  @override
  void initState() {
    super.initState();
    _future = _service.fetchCommunityNewsSources(widget.language);
  }

  void _reload() {
    setState(() {
      _future = _service.fetchCommunityNewsSources(widget.language);
    });
  }

  Future<void> _addToLibrary(NewsRssSource source) async {
    final url = source.uri.toString();
    if (_addingUrls.contains(url)) return;
    setState(() => _addingUrls.add(url));
    try {
      await _service.addCustomSource(
        widget.language,
        source.name,
        url,
        parentFolderId: widget.parentFolderId,
      );
      if (!mounted) return;
      showStatusMessage(
        context,
        AppLocalizations.of(context).newsCommunitySourceAddedToLibrary(
          source.name,
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      showStatusMessage(
        context,
        AppLocalizations.of(context).newsCommunityAddToLibraryError(AppLocalizations.of(context).technicalErrorGeneric),
      );
    } finally {
      if (mounted) {
        setState(() => _addingUrls.remove(url));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newsCommunitySourcesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.update,
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<NewsRssSource>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.newsCommunitySourcesError(l10n.technicalErrorGeneric)),
              ),
            );
          }
          final sources = snapshot.data ?? const <NewsRssSource>[];
          if (sources.isEmpty) {
            return Center(child: Text(l10n.newsCommunitySourcesEmpty));
          }
          if (useSharedAccessibleViewModel) {
            return UniversalAccessibleList(
              sections: [AccessibleListSection(rows: [
                for (var index = 0; index < sources.length; index++)
                  AccessibleListRow(
                    id: 'source_$index',
                    title: sources[index].name,
                    subtitle: sources[index].uri.toString(),
                    accessibilityLabel: '${sources[index].name}, ${sources[index].uri}',
                    hint: l10n.newsCommunitySourceTapHint,
                    enabled: !_addingUrls.contains(sources[index].uri.toString()),
                  ),
              ])],
              onEvent: (event) {
                if (event.type != 'activate' || event.id == null) return;
                final index = int.tryParse(event.id!.replaceFirst('source_', ''));
                if (index != null && index >= 0 && index < sources.length) {
                  _addToLibrary(sources[index]);
                }
              },
            );
          }
          return ListView.separated(
            itemCount: sources.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final source = sources[index];
              final adding = _addingUrls.contains(source.uri.toString());
              final sourceUrl = source.uri.toString();
              final semanticLabel = '${source.name}, $sourceUrl';
              return Semantics(
                button: true,
                enabled: !adding,
                label: semanticLabel,
                hint: l10n.newsCommunitySourceTapHint,
                onTap: adding ? null : () => _addToLibrary(source),
                child: ExcludeSemantics(
                  child: ListTile(
                    leading: const Icon(Icons.rss_feed),
                    title: Text(source.name),
                    subtitle: Text(sourceUrl),
                    trailing: adding
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    onTap: adding ? null : () => _addToLibrary(source),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NewsSourceArticlesScreen extends StatefulWidget {
  const _NewsSourceArticlesScreen({
    required this.source,
    required this.language,
    this.initialUri,
    this.title,
  });

  final NewsRssSource source;
  final NewsLanguage language;
  final Uri? initialUri;
  final String? title;

  @override
  State<_NewsSourceArticlesScreen> createState() =>
      _NewsSourceArticlesScreenState();
}

class _NewsSourceArticlesScreenState extends State<_NewsSourceArticlesScreen> {
  final _service = NewsService();
  final _settings = AppSettingsService();
  final _localCityController = TextEditingController();
  final ValueNotifier<bool> _suppressBackSemantics = ValueNotifier<bool>(false);
  late Future<List<NewsArticle>> _future;
  late Uri _currentUri;

  @override
  void initState() {
    super.initState();
    _service.prefetchTinyfishFallbackOnlyPolicy();
    _currentUri = widget.initialUri ?? widget.source.uri;
    _future = _buildFuture();
  }

  @override
  void dispose() {
    _suppressBackSemantics.dispose();
    _localCityController.dispose();
    super.dispose();
  }

  void _openCategory(Uri uri, String title) {
    if (uri == _currentUri) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/news/source/category'),
        builder: (_) => _NewsSourceArticlesScreen(
          source: widget.source,
          language: widget.language,
          initialUri: uri,
          title: title,
        ),
      ),
    );
  }

  Future<List<NewsArticle>> _buildFuture() {
    final cat = widget.source.categories
        ?.where((c) => c.uri == _currentUri)
        .firstOrNull;
    final categorySourceName = widget.title ?? widget.source.name;
    if (cat != null && cat.isLocal) {
      return _fetchLocalCategory(categorySourceName);
    }
    return _service.fetchSourceNews(
      NewsRssSource(
        name: categorySourceName,
        uri: _currentUri,
        isCustom: widget.source.isCustom,
      ),
      language: widget.language,
    );
  }

  void _fetch() {
    setState(() {
      _future = _buildFuture();
    });
  }

  Future<void> _refresh() async {
    _fetch();
    await _future;
  }

  Future<void> _reloadLocalCategory() async {
    final city = _localCityController.text.trim();
    if (city.isEmpty) return;
    await _settings.setNewsLocalCity(city);
    if (!mounted) return;
    setState(_fetch);
  }

  Future<List<NewsArticle>> _fetchLocalCategory(String categorySourceName) async {
    final lang = switch (widget.language) {
      NewsLanguage.portuguese => 'pt-PT',
      NewsLanguage.portugueseBrazil => 'pt-BR',
      NewsLanguage.chineseSimplified => 'zh-CN',
      NewsLanguage.ukrainian => 'uk',
      _ => widget.language.code,
    };
    final ceidLanguage = switch (widget.language) {
      NewsLanguage.portuguese => 'pt-150',
      NewsLanguage.portugueseBrazil => 'pt-419',
      NewsLanguage.chineseSimplified => 'zh-Hans',
      NewsLanguage.ukrainian => 'uk',
      _ => widget.language.code,
    };
    final savedCity = await _settings.getNewsLocalCity();
    final loc = await _service.getUserLocationData();
    final detectedCity = loc?['city'] ?? '';
    final country = loc?['countryCode'] ?? _defaultCountryCode(widget.language);
    final city = savedCity.trim().isNotEmpty ? savedCity.trim() : detectedCity;
    if (mounted &&
        _localCityController.text.trim().isEmpty &&
        city.isNotEmpty) {
      // The local Google News feed already uses the detected city at this
      // point. Rebuild as soon as the controller is populated so the shared
      // accessible model sends the same value to the native iOS text field.
      // Without this rebuild Flutter saw the controller change directly, while
      // UIKit kept the initial empty value until the next manual refresh.
      setState(() {
        _localCityController.text = city;
        _localCityController.selection =
            TextSelection.collapsed(offset: city.length);
      });
    }
    if (city.isNotEmpty) {
      final searchUri = Uri.parse(
          'https://news.google.com/rss/search?q=${Uri.encodeComponent(city)}&hl=$lang&gl=$country&ceid=$country:$ceidLanguage');
      return _service.fetchSourceNews(
        NewsRssSource(name: categorySourceName, uri: searchUri),
        language: widget.language,
      );
    }
    // Fallback to top news if location fails
    return _service.fetchSourceNews(
      NewsRssSource(name: categorySourceName, uri: widget.source.uri),
      language: widget.language,
    );
  }

  String _defaultCountryCode(NewsLanguage language) => switch (language) {
        NewsLanguage.english => 'US',
        NewsLanguage.french => 'FR',
        NewsLanguage.spanish => 'ES',
        NewsLanguage.portuguese => 'PT',
        NewsLanguage.portugueseBrazil => 'BR',
        NewsLanguage.polish => 'PL',
        NewsLanguage.czech => 'CZ',
        NewsLanguage.german => 'DE',
        NewsLanguage.chineseSimplified => 'CN',
        NewsLanguage.ukrainian => 'UA',
        NewsLanguage.italian => 'IT',
      };

  @override
  Widget build(BuildContext context) {
    final showCategories = widget.initialUri == null;
    final currentCategory = widget.source.categories
        ?.where((c) => c.uri == _currentUri)
        .firstOrNull;
    final isLocalCategory = currentCategory?.isLocal == true;

    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !canPop,
        leading: canPop
            ? ValueListenableBuilder<bool>(
                valueListenable: _suppressBackSemantics,
                builder: (context, suppress, child) => ExcludeSemantics(
                  excluding: suppress,
                  child: child,
                ),
                child: const BackButton(),
              )
            : null,
        title: Text(widget.title ?? widget.source.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppLocalizations.of(context).update,
            onPressed: _fetch,
          ),
        ],
      ),
      body: Column(
        children: [
          if (showCategories &&
              widget.source.categories != null &&
              widget.source.categories!.isNotEmpty)
            useSharedAccessibleViewModel
                ? SizedBox(
                    height: 72,
                    child: UniversalAccessibleList(
                      showVerticalScrollIndicator: false,
                      sections: [
                        AccessibleListSection(
                          rows: [
                            AccessibleListRow(
                              id: 'category_top',
                              title: AppLocalizations.of(context).newsCategoryTop,
                              kind: 'button',
                              selected: _currentUri == widget.source.uri,
                            ),
                            for (var index = 0;
                                index < widget.source.categories!.length;
                                index++)
                              AccessibleListRow(
                                id: 'category_$index',
                                title: widget.source.categories![index].name,
                                kind: 'button',
                                selected: _currentUri ==
                                    widget.source.categories![index].uri,
                              ),
                          ],
                        ),
                      ],
                      onEvent: (event) {
                        if (event.type != 'activate' || event.id == null) return;
                        if (event.id == 'category_top') {
                          _openCategory(widget.source.uri, widget.source.name);
                          return;
                        }
                        if (!event.id!.startsWith('category_')) return;
                        final index = int.tryParse(
                          event.id!.substring('category_'.length),
                        );
                        if (index == null ||
                            index < 0 ||
                            index >= widget.source.categories!.length) {
                          return;
                        }
                        final category = widget.source.categories![index];
                        _openCategory(
                          category.uri,
                          '${widget.source.name}: ${category.name}',
                        );
                      },
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text(AppLocalizations.of(context).newsCategoryTop),
                          selected: _currentUri == widget.source.uri,
                          onSelected: (selected) {
                            if (selected) {
                              _openCategory(widget.source.uri, widget.source.name);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ...widget.source.categories!.map((cat) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(cat.name),
                              selected: _currentUri == cat.uri,
                              onSelected: (selected) {
                                if (selected) {
                                  _openCategory(
                                    cat.uri,
                                    '${widget.source.name}: ${cat.name}',
                                  );
                                }
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
          if (isLocalCategory)
            useSharedAccessibleViewModel
                ? SizedBox(
                    height: 132,
                    child: UniversalAccessibleList(
                      sections: [AccessibleListSection(rows: [
                        AccessibleListRow(
                          id: 'local_city',
                          kind: 'textField',
                          title: AppLocalizations.of(context).newsLocalCityLabel,
                          placeholder: AppLocalizations.of(context).newsLocalCityHint,
                          value: _localCityController.text,
                          textInputAction: 'search',
                          onSubmitted: (_) => _reloadLocalCategory(),
                        ),
                        AccessibleListRow(
                          id: 'local_update',
                          kind: 'button',
                          title: AppLocalizations.of(context).update,
                        ),
                      ])],
                      onEvent: (event) {
                        if (event.id == 'local_city' && event.type == 'textChanged') {
                          _localCityController.text = event.value?.toString() ?? '';
                        } else if (event.id == 'local_update' && event.type == 'activate') {
                          _reloadLocalCategory();
                        }
                      },
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _localCityController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context).newsLocalCityLabel,
                            hintText: AppLocalizations.of(context).newsLocalCityHint,
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _reloadLocalCategory(),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _reloadLocalCategory,
                          child: Text(AppLocalizations.of(context).update),
                        ),
                      ],
                    ),
                  ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _NewsArticleList(
                future: _future,
                language: widget.language,
                sourceName: widget.title ?? widget.source.name,
                suppressBackSemantics: _suppressBackSemantics,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _NewsSourceAction {
  moveUp,
  moveDown,
  moveToPosition,
  hide,
  delete,
  moveToFolder,
  moveOutOfFolder,
}

String _newsSourceStableId(NewsRssSource source) {
  if (source.isFolder) {
    return 'folder:${source.folderId ?? source.uri}';
  }
  return 'source:${source.uri}';
}

class _NewsSourceList extends StatelessWidget {
  const _NewsSourceList({
    required this.sources,
    required this.language,
    required this.currentFolderId,
    required this.service,
    required this.onSourceSelected,
    required this.onSourcesChanged,
    this.onCreateFolder,
  });

  final List<NewsRssSource> sources;
  final NewsLanguage language;
  final String? currentFolderId;
  final NewsService service;
  final ValueChanged<NewsRssSource> onSourceSelected;
  final VoidCallback onSourcesChanged;
  final Future<void> Function()? onCreateFolder;

  Future<String?> _selectTargetFolder(
    BuildContext context,
    NewsRssSource source,
  ) async {
    final l10n = AppLocalizations.of(context);
    final folders = (await service.getFolders(language))
        .where((folder) => folder.id != currentFolderId)
        .toList();
    if (!context.mounted || folders.isEmpty) return null;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.selectFolder),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: useSharedAccessibleViewModel
              ? UniversalAccessibleList(
                  sections: [AccessibleListSection(rows: [
                    for (final folder in folders)
                      AccessibleListRow(id: folder.id, title: folder.name),
                  ])],
                  onEvent: (event) {
                    if (event.type == 'activate' && event.id != null) {
                      Navigator.pop(ctx, event.id);
                    }
                  },
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: folders
                        .map(
                          (folder) => ListTile(
                            key: ValueKey('news_move_folder_${folder.id}'),
                            leading: const Icon(Icons.folder, color: Colors.amber),
                            title: Text(folder.name),
                            onTap: () => Navigator.pop(ctx, folder.id),
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  void _handleAction(
      BuildContext context, _NewsSourceAction action, int index) async {
    final source = sources[index];
    try {
      if (action == _NewsSourceAction.hide && !source.isFolder) {
        await service.hideSource(language, source);
        onSourcesChanged();
        return;
      }
      if (action == _NewsSourceAction.delete) {
        if (source.isFolder && source.folderId != null) {
          await service.removeFolder(language, source.folderId!);
        } else if (source.isCustom) {
          await service.removeCustomSource(language, source.name);
        }
        onSourcesChanged();
        return;
      }
      if (action == _NewsSourceAction.moveOutOfFolder && !source.isFolder) {
        await service.moveSourceToFolder(language, source, null);
        onSourcesChanged();
        if (!context.mounted) return;
                showStatusMessage(context, AppLocalizations.of(context).documentMoved);
        return;
      }
      if (action == _NewsSourceAction.moveToFolder && !source.isFolder) {
        final folderId = await _selectTargetFolder(context, source);
        if (folderId == null) return;
        await service.moveSourceToFolder(language, source, folderId);
        onSourcesChanged();
        if (!context.mounted) return;
                showStatusMessage(context, AppLocalizations.of(context).documentMoved);
        return;
      }

      final list = List<NewsRssSource>.from(sources);
      final item = list.removeAt(index);

      if (action == _NewsSourceAction.moveUp && index > 0) {
        list.insert(index - 1, item);
        await service.saveSourcesOrder(
          language,
          list,
          folderId: currentFolderId,
        );
        onSourcesChanged();
      } else if (action == _NewsSourceAction.moveDown && index < list.length) {
        list.insert(index + 1, item);
        await service.saveSourcesOrder(
          language,
          list,
          folderId: currentFolderId,
        );
        onSourcesChanged();
      } else if (action == _NewsSourceAction.moveToPosition) {
        final newPos = await showDialog<int>(
          context: context,
          builder: (_) => _PositionSliderDialog(
            currentIndex: index,
            sources: sources,
          ),
        );
        if (newPos != null && newPos != index) {
          list.insert(newPos, item);
          await service.saveSourcesOrder(
            language,
            list,
            folderId: currentFolderId,
          );
          onSourcesChanged();
        }
      }
    } catch (e) {
      if (!context.mounted) return;
            final l10n = AppLocalizations.of(context);
      showStatusMessage(context, '${l10n.errorPrefix}: ${l10n.technicalErrorGeneric}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (useSharedAccessibleViewModel) {
      final rows = <AccessibleListRow>[];
      for (var index = 0; index < sources.length; index++) {
        final source = sources[index];
        final actions = <AccessibleCustomAction>[
          if (onCreateFolder != null)
            AccessibleCustomAction(id: 'create_folder', label: l10n.createNewFolder),
          if (index > 0)
            AccessibleCustomAction(id: 'move_up', label: l10n.moveUp),
          if (index < sources.length - 1)
            AccessibleCustomAction(id: 'move_down', label: l10n.moveDown),
          AccessibleCustomAction(id: 'move_position', label: l10n.moveToPosition),
          if (!source.isFolder && currentFolderId != null)
            AccessibleCustomAction(id: 'move_out', label: l10n.outOfFolder),
          if (!source.isFolder)
            AccessibleCustomAction(id: 'move_folder', label: l10n.moveToAnotherFolder),
          if (!source.isFolder)
            AccessibleCustomAction(
              id: source.isCustom ? 'delete' : 'hide',
              label: l10n.deleteNewsSource,
            ),
          if (source.isFolder)
            AccessibleCustomAction(id: 'delete', label: l10n.removeFolder),
        ];
        rows.add(AccessibleListRow(
          id: _newsSourceStableId(source),
          title: source.name,
          accessibilityLabel: source.isFolder
              ? '${l10n.folderTypeLabel} ${source.name}'
              : source.name,
          hint: source.isFolder ? l10n.openFolderHint : null,
          kind: 'action',
          actions: actions,
        ));
      }
      return UniversalAccessibleList(
        key: ValueKey('shared-news-sources-${language.code}-${currentFolderId ?? 'root'}-${sources.length}'),
        sections: [AccessibleListSection(rows: rows)],
        onEvent: (event) async {
          final id = event.id;
          if (id == null) return;
          final index = sources.indexWhere((source) => _newsSourceStableId(source) == id);
          if (index < 0) return;
          if (event.type == 'activate') {
            onSourceSelected(sources[index]);
            return;
          }
          if (event.type != 'customAction') return;
          switch (event.action) {
            case 'create_folder': onCreateFolder?.call(); break;
            case 'move_up': _handleAction(context, _NewsSourceAction.moveUp, index); break;
            case 'move_down': _handleAction(context, _NewsSourceAction.moveDown, index); break;
            case 'move_position': _handleAction(context, _NewsSourceAction.moveToPosition, index); break;
            case 'move_out': _handleAction(context, _NewsSourceAction.moveOutOfFolder, index); break;
            case 'move_folder': _handleAction(context, _NewsSourceAction.moveToFolder, index); break;
            case 'hide': _handleAction(context, _NewsSourceAction.hide, index); break;
            case 'delete': _handleAction(context, _NewsSourceAction.delete, index); break;
          }
        },
      );
    }
    return ListView.separated(
      key: PageStorageKey<String>(
        'news_sources_${language.code}_${currentFolderId ?? 'root'}',
      ),
      scrollCacheExtent: accessibilityListCacheExtent(context),
      itemCount: sources.length,
      findItemIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        const prefix = 'news_source_item_';
        if (!key.value.startsWith(prefix)) return null;
        final stableId = key.value.substring(prefix.length);
        final itemIndex = sources.indexWhere(
          (source) => _newsSourceStableId(source) == stableId,
        );
        return itemIndex < 0 ? null : itemIndex;
      },
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final source = sources[index];
        final stableId = _newsSourceStableId(source);
        final isFirst = index == 0;
        final isLast = index == sources.length - 1;

        return Semantics(
          key: ValueKey<String>('news_source_item_$stableId'),
          container: true,
          button: true,
          label: source.isFolder
              ? '${l10n.folderTypeLabel} ${source.name}'
              : source.name,
          hint: source.isFolder ? l10n.openFolderHint : null,
          onTap: () => onSourceSelected(source),
          customSemanticsActions: {
              if (onCreateFolder != null)
                CustomSemanticsAction(label: l10n.createNewFolder): () {
                  onCreateFolder!();
                },
              if (!isFirst)
                CustomSemanticsAction(label: l10n.moveUp): () =>
                    _handleAction(context, _NewsSourceAction.moveUp, index),
              if (!isLast)
                CustomSemanticsAction(label: l10n.moveDown): () =>
                    _handleAction(context, _NewsSourceAction.moveDown, index),
              CustomSemanticsAction(label: l10n.moveToPosition): () =>
                  _handleAction(
                      context, _NewsSourceAction.moveToPosition, index),
              if (!source.isFolder && currentFolderId != null)
                CustomSemanticsAction(label: l10n.outOfFolder): () =>
                    _handleAction(
                        context, _NewsSourceAction.moveOutOfFolder, index),
              if (!source.isFolder)
                CustomSemanticsAction(label: l10n.moveToAnotherFolder): () =>
                    _handleAction(context, _NewsSourceAction.moveToFolder, index),
              if (!source.isFolder)
                CustomSemanticsAction(label: l10n.deleteNewsSource): () =>
                    _handleAction(
                      context,
                      source.isCustom
                          ? _NewsSourceAction.delete
                          : _NewsSourceAction.hide,
                      index,
                    ),
              if (source.isFolder)
                CustomSemanticsAction(label: l10n.removeFolder): () =>
                    _handleAction(context, _NewsSourceAction.delete, index),
          },
          child: ExcludeSemantics(
            child: ListTile(
              leading: Icon(source.isFolder ? Icons.folder : Icons.rss_feed),
              title: Text(source.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onSourceSelected(source),
            ),
          ),
        );
      },
    );
  }
}

class _PositionSliderDialog extends StatefulWidget {
  final int currentIndex;
  final List<NewsRssSource> sources;

  const _PositionSliderDialog(
      {required this.currentIndex, required this.sources});

  @override
  State<_PositionSliderDialog> createState() => _PositionSliderDialogState();
}

class _PositionSliderDialogState extends State<_PositionSliderDialog> {
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
    final targetSources = [
      for (var i = 0; i < widget.sources.length; i++)
        if (i != widget.currentIndex) widget.sources[i],
    ];
    final maxPosition = targetSources.length;

    String positionLabel(int position) {
      if (position >= targetSources.length) {
        return l10n.positionLabelLast;
      }
      final targetName = targetSources[position].name;
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
      title: Text(l10n.moveToPosition),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Semantics(
            slider: true,
            label: l10n.moveToPosition,
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
                onChanged: (val) {
                  setState(() {
                    _value = val;
                  });
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
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

class _NewsArticleList extends StatefulWidget {
  const _NewsArticleList({
    required this.future,
    required this.language,
    required this.sourceName,
    required this.suppressBackSemantics,
  });

  final Future<List<NewsArticle>> future;
  final NewsLanguage language;
  final String sourceName;
  final ValueNotifier<bool> suppressBackSemantics;

  @override
  State<_NewsArticleList> createState() => _NewsArticleListState();
}

class _NewsArticleListState extends State<_NewsArticleList> {
  final _service = NewsService();
  final _scrollController = AutoScrollController();
  final _accessibleListController = AccessibleListController();
  Set<String> _readUris = {};
  bool _loadingRead = true;
  String? _pendingArticleScrollId;
  bool _pendingArticleScrollScheduled = false;

  @override
  void initState() {
    super.initState();
    _loadReadArticles();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openArticle(
    NewsArticle article,
    List<NewsArticle> visibleArticles,
  ) async {
    final navigator = Navigator.of(context);
    final currentIndex = visibleArticles.indexWhere((a) => a.id == article.id);
    NewsArticle? scrollTarget;
    if (currentIndex >= 0) {
      if (currentIndex + 1 < visibleArticles.length) {
        scrollTarget = visibleArticles[currentIndex + 1];
      } else if (currentIndex - 1 >= 0) {
        scrollTarget = visibleArticles[currentIndex - 1];
      }
    }

    _pendingArticleScrollId = scrollTarget?.id;
    _pendingArticleScrollScheduled = false;

    await _service.addReadArticle(
      widget.language,
      widget.sourceName,
      article,
    );
    if (!mounted) return;
    setState(() {
      _readUris = {..._readUris, article.id};
    });

    if (scrollTarget != null && suppressBackSemanticsDuringRouteReturn) {
      widget.suppressBackSemantics.value = true;
    }
    await navigator.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/news/article'),
        builder: (_) => NewsWebViewScreen(
          article: article,
          language: widget.language,
          readSourceName: widget.sourceName,
        ),
      ),
    );
    if (!mounted) return;

    // The source route is visible again now. Back may be excluded while the
    // article route is closing so VoiceOver does not steal the initial focus,
    // but it must be exposed as soon as the user is back on the article list.
    // Do not keep it hidden while the read-state reload or the native UIKit
    // route-return focus handoff settles: that work can legitimately take a
    // few seconds on large feeds.
    if (widget.suppressBackSemantics.value) {
      widget.suppressBackSemantics.value = false;
    }

    await _loadReadArticles();
    if (!mounted) return;
    if (useSharedAccessibleViewModel) {
      _schedulePendingArticleFocus();
    }
  }

  Future<void> _shareArticle(NewsArticle article) async {
    try {
      final resolved = await _service.resolveArticleUrlForSharing(article.link);
      final url = resolved.trim().isNotEmpty
          ? resolved.trim()
          : article.link.trim();
      await SharePlus.instance.share(
        ShareParams(
          text: '${article.title}\n$url',
          subject: article.title,
        ),
      );
    } catch (e) {
      debugPrint('Error sharing news article from list: $e');
    }
  }

  Future<void> _loadReadArticles() async {
    final list = await _service.getReadArticles(widget.language, widget.sourceName);
    if (!mounted) return;
    setState(() {
      _readUris = list.map((e) => e.id).toSet();
      _loadingRead = false;
    });
  }

  void _openReadArticles() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ReadArticlesScreen(
          language: widget.language,
          sourceName: widget.sourceName,
        ),
      ),
    ).then((_) => _loadReadArticles());
  }

  void _schedulePendingArticleScroll(List<NewsArticle> articles) {
    if (useSharedAccessibleViewModel) return;

    final pendingId = _pendingArticleScrollId;
    if (pendingId == null || _pendingArticleScrollScheduled) return;

    final articleIndex = articles.indexWhere((a) => a.id == pendingId);
    if (articleIndex < 0) {
      _pendingArticleScrollId = null;
      _pendingArticleScrollScheduled = false;
      return;
    }

    final listIndex = articleIndex + (_readUris.isNotEmpty ? 1 : 0);
    _pendingArticleScrollScheduled = true;

    Future<void>.delayed(const Duration(milliseconds: 350), () {
      _tryScrollToPendingArticle(listIndex);
    });
  }

  void _schedulePendingArticleFocus() {
    final pendingId = _pendingArticleScrollId;
    if (pendingId == null || _pendingArticleScrollScheduled) return;

    _pendingArticleScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(
        const Duration(milliseconds: 180),
        () => _tryFocusPendingArticle(pendingId),
      );
    });
  }

  Future<void> _tryFocusPendingArticle(
    String id, {
    int attempt = 0,
  }) async {
    if (!mounted || _pendingArticleScrollId != id) return;

    if (!_accessibleListController.hasAttachedRenderer) {
      if (attempt < 4) {
        Future<void>.delayed(
          Duration(milliseconds: 180 + (attempt * 120)),
          () => _tryFocusPendingArticle(id, attempt: attempt + 1),
        );
      } else {
        widget.suppressBackSemantics.value = false;
        _pendingArticleScrollId = null;
        _pendingArticleScrollScheduled = false;
      }
      return;
    }

    try {
      await _accessibleListController.focusAccessibleRow(
        id,
        mode: AccessibleFocusMode.routeReturnJump,
        animated: false,
      );
      if (!mounted || _pendingArticleScrollId != id) return;
      // Back is already exposed again as soon as the article route closes.
      // The native focus request may keep retrying internally, but it must not
      // control the availability of the navigation button.
      if (!widget.suppressBackSemantics.value) {
        _pendingArticleScrollId = null;
        _pendingArticleScrollScheduled = false;
      }
    } catch (_) {
      if (!mounted || _pendingArticleScrollId != id) return;
      if (attempt < 4) {
        Future<void>.delayed(
          Duration(milliseconds: 220 + (attempt * 150)),
          () => _tryFocusPendingArticle(id, attempt: attempt + 1),
        );
      } else {
        widget.suppressBackSemantics.value = false;
        _pendingArticleScrollId = null;
        _pendingArticleScrollScheduled = false;
      }
    }
  }

  void _handleArticleAccessibilityFocus(String id) {
    if (_pendingArticleScrollId != id) return;
    _pendingArticleScrollId = null;
    _pendingArticleScrollScheduled = false;
    if (widget.suppressBackSemantics.value) {
      widget.suppressBackSemantics.value = false;
    }
  }

  Future<void> _tryScrollToPendingArticle(int listIndex, {int attempt = 0}) async {
    if (!mounted) return;

    if (!_scrollController.hasClients) {
      if (attempt < 3) {
        Future<void>.delayed(
          Duration(milliseconds: 250 + (attempt * 150)),
          () => _tryScrollToPendingArticle(listIndex, attempt: attempt + 1),
        );
      } else {
        _pendingArticleScrollId = null;
        _pendingArticleScrollScheduled = false;
      }
      return;
    }

    try {
      await _scrollController.scrollToIndex(
        listIndex,
        preferPosition: AutoScrollPosition.begin,
        duration: const Duration(milliseconds: 300),
      );

      // Primo rientro da una fonte: a volte la lista e l'albero semantico iOS
      // arrivano un attimo dopo il primo scroll. Un secondo scroll leggero,
      // senza forzare il focus VoiceOver, rende più stabile il posizionamento.
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.scrollToIndex(
        listIndex,
        preferPosition: AutoScrollPosition.begin,
        duration: const Duration(milliseconds: 120),
      );

      if (!mounted) return;
      _pendingArticleScrollId = null;
      _pendingArticleScrollScheduled = false;
    } catch (_) {
      if (!mounted) return;
      if (attempt < 3) {
        Future<void>.delayed(
          Duration(milliseconds: 300 + (attempt * 200)),
          () => _tryScrollToPendingArticle(listIndex, attempt: attempt + 1),
        );
      } else {
        _pendingArticleScrollId = null;
        _pendingArticleScrollScheduled = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<NewsArticle>>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || _loadingRead) {
          return Center(
            child: CircularProgressIndicator(
              semanticsLabel: l10n.loadingNews,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text(l10n.error(l10n.technicalErrorGeneric)));
        }
        final allArticles = snapshot.data ?? const [];
        final articles = allArticles.where((a) => !_readUris.contains(a.id)).toList();
        final itemCount = articles.length + (_readUris.isNotEmpty ? 1 : 0);

        _schedulePendingArticleScroll(articles);

        if (itemCount == 0) {
          return Center(child: Text(l10n.noNewsFound));
        }

        if (useSharedAccessibleViewModel) {
          final rows = <AccessibleListRow>[
            if (_readUris.isNotEmpty)
              AccessibleListRow(
                id: '__read_articles__',
                title: l10n.newsReadArticles,
                kind: 'action',
              ),
            ...articles.map((article) {
              final summaryTrimmed = article.summary.trim();
              final titleTrimmed = article.title.trim();
              final isSummaryDuplicate = summaryTrimmed.isNotEmpty &&
                  (summaryTrimmed == titleTrimmed ||
                      summaryTrimmed.contains(titleTrimmed) ||
                      titleTrimmed.contains(summaryTrimmed));
              final subtitleText = isSummaryDuplicate
                  ? article.source
                  : '${article.source}. ${article.summary}';
              return AccessibleListRow(
                id: article.id,
                onAccessibilityFocus: () =>
                    _handleArticleAccessibilityFocus(article.id),
                title: titleWithListTimestamp(
                  article.title,
                  article.publishedAt,
                  l10n.localeName,
                ),
                subtitle: subtitleText,
                kind: 'action',
                actions: [
                  AccessibleCustomAction(
                    id: 'share',
                    label: l10n.shareArticle,
                  ),
                ],
                visualActions: [
                  AccessibleVisualAction(
                    id: 'share',
                    label: l10n.shareArticle,
                    icon: 'share',
                  ),
                ],
              );
            }),
          ];
          return UniversalAccessibleList(
            key: ValueKey('shared-news-articles-${widget.sourceName}-${rows.length}'),
            controller: _accessibleListController,
            routeReturnSemanticsSettleDelay: Duration.zero,
            routeReturnUseFocusProxy: false,
            routeReturnWaitForForeignFocusClear: true,
            sections: [AccessibleListSection(rows: rows)],
            onEvent: (event) async {
              final id = event.id;
              if (id == null) return;
              if (event.type == 'activate' && id == '__read_articles__') {
                _openReadArticles();
                return;
              }
              final index = articles.indexWhere((article) => article.id == id);
              if (index < 0) return;
              final article = articles[index];
              if (event.type == 'customAction' && event.action == 'share') {
                await _shareArticle(article);
              } else if (event.type == 'activate') {
                await _openArticle(article, articles);
              }
            },
          );
        }

        return ListView.separated(
          controller: _scrollController,
          itemCount: itemCount,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (_readUris.isNotEmpty && index == 0) {
              return AutoScrollTag(
                key: const ValueKey('news_read_articles_scroll'),
                controller: _scrollController,
                index: index,
                child: ListTile(
                  key: const ValueKey('news_read_articles'),
                  leading: const Icon(Icons.history),
                  title: Text(l10n.newsReadArticles),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openReadArticles,
                ),
              );
            }
            final articleIndex = _readUris.isNotEmpty ? index - 1 : index;
            final article = articles[articleIndex];
            final summaryTrimmed = article.summary.trim();
            final titleTrimmed = article.title.trim();
            final isSummaryDuplicate = summaryTrimmed.isNotEmpty &&
                (summaryTrimmed == titleTrimmed ||
                 summaryTrimmed.contains(titleTrimmed) ||
                 titleTrimmed.contains(summaryTrimmed));
            final subtitleText = isSummaryDuplicate
                ? article.source
                : '${article.source}. ${article.summary}';

            return AutoScrollTag(
              key: ValueKey('news_article_scroll_$index'),
              controller: _scrollController,
              index: index,
              child: Semantics(
                container: true,
                customSemanticsActions: {
                  CustomSemanticsAction(label: l10n.shareArticle): () =>
                      _shareArticle(article),
                },
                child: ListTile(
                  key: ValueKey('news_article_${article.id}'),
                  title: Text(titleWithListTimestamp(
                    article.title,
                    article.publishedAt,
                    l10n.localeName,
                  )),
                  subtitle: Text(
                    subtitleText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: ExcludeSemantics(
                    child: IconButton(
                      icon: const Icon(Icons.share),
                      tooltip: l10n.shareArticle,
                      onPressed: () => _shareArticle(article),
                    ),
                  ),
                  onTap: () => _openArticle(article, articles),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReadArticlesScreen extends StatefulWidget {
  final NewsLanguage language;
  final String sourceName;

  const _ReadArticlesScreen({required this.language, required this.sourceName});

  @override
  State<_ReadArticlesScreen> createState() => _ReadArticlesScreenState();
}

class _ReadArticlesScreenState extends State<_ReadArticlesScreen> {
  final _service = NewsService();
  List<NewsArticle> _articles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _service.getReadArticles(widget.language, widget.sourceName);
    if (!mounted) return;
    setState(() {
      _articles = list;
      _loading = false;
    });
  }

  Future<void> _deleteArticle(NewsArticle article) async {
    await _service.removeReadArticle(
      widget.language,
      widget.sourceName,
      article.id,
    );
    await _load();
  }

  Future<void> _clearHistory() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearHistory),
        content: Text(l10n.confirmClearHistory),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.clearHistory),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _service.clearReadArticles(widget.language, widget.sourceName);
    _load();
  }


  Widget _buildSharedAccessibleReadArticles(AppLocalizations l10n) {
    final rows = _articles.map((article) {
      final summaryTrimmed = article.summary.trim();
      final titleTrimmed = article.title.trim();
      final isSummaryDuplicate = summaryTrimmed.isNotEmpty &&
          (summaryTrimmed == titleTrimmed ||
              summaryTrimmed.contains(titleTrimmed) ||
              titleTrimmed.contains(summaryTrimmed));
      final subtitleText = isSummaryDuplicate
          ? article.source
          : '${article.source}. ${article.summary}';
      return AccessibleListRow(
        id: article.id,
        title: titleWithListTimestamp(
          article.title,
          article.publishedAt,
          l10n.localeName,
        ),
        subtitle: subtitleText,
        kind: 'action',
        actions: [
          AccessibleCustomAction(id: 'delete', label: l10n.deleteItem),
        ],
      );
    }).toList();
    return UniversalAccessibleList(
      key: ValueKey('shared-read-news-${rows.length}'),
      sections: [AccessibleListSection(rows: rows)],
      onEvent: (event) async {
        final id = event.id;
        if (id == null) return;
        final index = _articles.indexWhere((article) => article.id == id);
        if (index < 0) return;
        final article = _articles[index];
        if (event.type == 'customAction' && event.action == 'delete') {
          await _deleteArticle(article);
        } else if (event.type == 'activate') {
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/news/article'),
              builder: (_) => NewsWebViewScreen(
                article: article,
                language: widget.language,
                readSourceName: widget.sourceName,
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newsReadArticles),
        actions: [
          if (_articles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: l10n.clearHistory,
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _articles.isEmpty
              ? Center(child: Text(l10n.noNewsFound))
              : useSharedAccessibleViewModel
                  ? _buildSharedAccessibleReadArticles(l10n)
                  : ListView.separated(
                  itemCount: _articles.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final article = _articles[index];
                    final summaryTrimmed = article.summary.trim();
                    final titleTrimmed = article.title.trim();
                    final isSummaryDuplicate = summaryTrimmed.isNotEmpty &&
                        (summaryTrimmed == titleTrimmed ||
                         summaryTrimmed.contains(titleTrimmed) ||
                         titleTrimmed.contains(summaryTrimmed));
                    final subtitleText = isSummaryDuplicate
                        ? article.source
                        : '${article.source}. ${article.summary}';

                    return Semantics(
                      key: ValueKey('news_read_article_semantics_${article.id}'),
                      container: true,
                      customSemanticsActions: {
                        CustomSemanticsAction(label: l10n.deleteItem): () =>
                            _deleteArticle(article),
                      },
                      child: ListTile(
                        key: ValueKey('news_read_article_${article.id}'),
                        title: Text(titleWithListTimestamp(
                          article.title,
                          article.publishedAt,
                          l10n.localeName,
                        )),
                        subtitle: Text(
                          subtitleText,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: ExcludeSemantics(
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: l10n.deleteItem,
                            onPressed: () => _deleteArticle(article),
                          ),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: '/news/article'),
                            builder: (_) => NewsWebViewScreen(
                              article: article,
                              language: widget.language,
                              readSourceName: widget.sourceName,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
