import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../l10n/app_localizations.dart';
import '../services/recent_searches_service.dart';
import '../widgets/native_ios_accessible_view.dart';

class RecentSearchesScreen extends StatefulWidget {
  final String title;
  final String domain;

  const RecentSearchesScreen({
    super.key,
    required this.title,
    required this.domain,
  });

  @override
  State<RecentSearchesScreen> createState() => _RecentSearchesScreenState();
}

class _RecentSearchesScreenState extends State<RecentSearchesScreen> {
  final _service = RecentSearchesService();
  List<String> _searches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSearches();
  }

  Future<void> _loadSearches() async {
    final searches = await _service.getRecentSearches(widget.domain);
    if (!mounted) return;
    setState(() {
      _searches = searches;
      _loading = false;
    });
  }

  Future<void> _deleteSearch(String query) async {
    await _service.removeSearch(widget.domain, query);
    await _loadSearches();
  }

  Future<void> _clearAll() async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).clearHistory),
        content: Text(AppLocalizations.of(context).confirmClearHistory),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(context).clear),
          ),
        ],
      ),
    );

    if (conf == true) {
      await _service.clearSearches(widget.domain);
      _loadSearches();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_searches.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep,
                  color: Theme.of(context).colorScheme.error),
              tooltip: AppLocalizations.of(context).clearHistory,
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _searches.isEmpty
              ? Center(
                  child: Text(AppLocalizations.of(context).noRecentSearches))
              : useNativeIosAccessibleViews
                  ? NativeIosAccessibleList(
                      sections: [
                        NativeIosListSection(
                          rows: _searches
                              .asMap()
                              .entries
                              .map((entry) => NativeIosListRow(
                                    id: 'search_${entry.key}',
                                    title: entry.value,
                                    actions: [
                                      NativeIosCustomAction(
                                        id: 'delete',
                                        label: AppLocalizations.of(context).deleteItem,
                                      ),
                                    ],
                                  ))
                              .toList(growable: false),
                        ),
                      ],
                      onEvent: (event) async {
                        if (event.id?.startsWith('search_') != true) return;
                        final index = int.tryParse(event.id!.substring(7));
                        if (index == null || index < 0 || index >= _searches.length) return;
                        final query = _searches[index];
                        if (event.type == 'customAction' && event.action == 'delete') {
                          await _deleteSearch(query);
                        } else if (event.type == 'activate') {
                          if (mounted) Navigator.of(context).pop(query);
                        }
                      },
                    )
                  : ListView.builder(
                  itemCount: _searches.length,
                  itemBuilder: (context, index) {
                    final query = _searches[index];
                    return Semantics(
                      key: ValueKey('recent_search_semantics_${widget.domain}_$query'),
                      container: true,
                      customSemanticsActions: {
                        CustomSemanticsAction(
                          label: AppLocalizations.of(context).deleteItem,
                        ): () => _deleteSearch(query),
                      },
                      child: ListTile(
                        title: Text(query),
                        trailing: ExcludeSemantics(
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: AppLocalizations.of(context).deleteItem,
                            onPressed: () => _deleteSearch(query),
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop(query);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
