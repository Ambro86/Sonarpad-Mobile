import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/universal_accessible_view.dart';

import 'recent_searches_screen.dart';

import 'aifa_search_results_screen.dart';

class AifaSearchScreen extends StatefulWidget {
  const AifaSearchScreen({super.key});

  @override
  State<AifaSearchScreen> createState() => _AifaSearchScreenState();
}

class _AifaSearchScreenState extends State<AifaSearchScreen> {
  static const _recentSearchesTitle = 'Ricerche recenti';
  static const _recentSearchesDomain = 'farmaci';

  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitSearch(String query) {
    query = query.trim();
    if (query.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AifaSearchResultsScreen(query: query),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).pharmacyFeatureTitle),
      ),
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? UniversalAccessibleList(
                sections: [
                  AccessibleListSection(
                    rows: [
                      AccessibleListRow(
                        id: 'recent',
                        title: _recentSearchesTitle,
                      ),
                      const AccessibleListRow(
                        id: 'query',
                        title: 'Nome, principio attivo, ingrediente o codice AIC',
                        kind: 'textField',
                        placeholder: 'Nome, principio attivo, ingrediente o codice AIC',
                      ),
                      const AccessibleListRow(
                        id: 'search',
                        title: 'Cerca',
                        kind: 'button',
                      ),
                    ],
                  ),
                ],
                onEvent: (event) async {
                  if (event.id == 'query' && event.type == 'textChanged') {
                    _controller.text = event.value?.toString() ?? '';
                    return;
                  }
                  if (event.type != 'activate') return;
                  if (event.id == 'search') {
                    _submitSearch(_controller.text);
                  } else if (event.id == 'recent') {
                    final q = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (ctx) => const RecentSearchesScreen(
                          title: _recentSearchesTitle,
                          domain: _recentSearchesDomain,
                        ),
                      ),
                    );
                    if (q != null && mounted) {
                      _controller.text = q;
                      _submitSearch(q);
                    }
                  }
                },
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: () async {
                            final q = await Navigator.of(context).push<String>(
                              MaterialPageRoute(
                                builder: (ctx) => const RecentSearchesScreen(
                                  title: _recentSearchesTitle,
                                  domain: _recentSearchesDomain,
                                ),
                              ),
                            );
                            if (q != null && mounted) {
                              _controller.text = q;
                              _submitSearch(q);
                            }
                          },
                          child: const Text(_recentSearchesTitle),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              decoration: const InputDecoration(
                                labelText: 'Nome, principio attivo, ingrediente o codice AIC',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.search),
                              ),
                              textInputAction: TextInputAction.search,
                              onSubmitted: _submitSearch,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => _submitSearch(_controller.text),
                            child: const Text('Cerca'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
