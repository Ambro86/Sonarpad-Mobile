import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/recent_searches_service.dart';

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
              : ListView.builder(
                  itemCount: _searches.length,
                  itemBuilder: (context, index) {
                    final query = _searches[index];
                    return ListTile(
                      title: Text(query),
                      onTap: () {
                        Navigator.of(context).pop(query);
                      },
                    );
                  },
                ),
    );
  }
}
