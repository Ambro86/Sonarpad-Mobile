import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/parafarmaco_service.dart';
import '../widgets/letter_jump_option_picker_screen.dart';
import '../widgets/universal_accessible_view.dart';
import 'aifa_search_results_screen.dart';
import 'parafarmaco_detail_screen.dart';

enum PharmacyAlphabeticalKind { drugs, parafarmaci }

class PharmacyAlphabeticalScreen extends StatefulWidget {
  const PharmacyAlphabeticalScreen({
    super.key,
    required this.kind,
  });

  final PharmacyAlphabeticalKind kind;

  @override
  State<PharmacyAlphabeticalScreen> createState() =>
      _PharmacyAlphabeticalScreenState();
}

class _PharmacyAlphabeticalScreenState
    extends State<PharmacyAlphabeticalScreen> {
  static const _letters = <String>[
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  final ParafarmacoService _service = ParafarmacoService();
  final Map<String, List<ParafarmacoSearchResult>> _resultsByLetter = {};
  final Set<String> _failedLetters = {};

  bool _loading = true;
  int _loadedLetters = 0;
  int _loadGeneration = 0;

  bool get _isDrugCatalog => widget.kind == PharmacyAlphabeticalKind.drugs;

  String get _title => _isDrugCatalog ? 'Farmaci A-Z' : 'Parafarmaci A-Z';

  List<ParafarmacoSearchResult> get _allResults {
    final byUrl = <String, ParafarmacoSearchResult>{};
    for (final letter in _letters) {
      for (final result in _resultsByLetter[letter] ?? const <ParafarmacoSearchResult>[]) {
        byUrl[result.sourceUrl] = result;
      }
    }
    final results = byUrl.values.toList();
    results.sort(_compareResults);
    return results;
  }

  @override
  void initState() {
    super.initState();
    _loadAllLetters();
  }

  Future<List<ParafarmacoSearchResult>> _loadLetter(String letter) {
    return _isDrugCatalog
        ? _service.browseDrugsByLetter(letter)
        : _service.browseParafarmaciByLetter(letter);
  }

  Future<void> _loadAllLetters() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _loadedLetters = 0;
      _resultsByLetter.clear();
      _failedLetters.clear();
    });

    const batchSize = 4;
    for (var start = 0; start < _letters.length; start += batchSize) {
      if (!mounted || generation != _loadGeneration) return;
      final batch = _letters.skip(start).take(batchSize).toList(growable: false);
      final responses = await Future.wait(
        batch.map((letter) async {
          try {
            return (letter: letter, results: await _loadLetter(letter), error: false);
          } catch (_) {
            return (
              letter: letter,
              results: const <ParafarmacoSearchResult>[],
              error: true,
            );
          }
        }),
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        for (final response in responses) {
          _resultsByLetter[response.letter] = response.results;
          if (response.error) {
            _failedLetters.add(response.letter);
          } else {
            _failedLetters.remove(response.letter);
          }
        }
        _loadedLetters = start + batch.length;
      });
    }

    if (!mounted || generation != _loadGeneration) return;
    setState(() => _loading = false);
  }

  Future<void> _selectLetter() async {
    final l10n = AppLocalizations.of(context);
    final letter = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => LetterJumpOptionPickerScreen<String>(
          title: l10n.letterJumpSelectLetter,
          options: _letters,
          labelBuilder: (value) => value,
          leadingBuilder: (_) => const Icon(Icons.sort_by_alpha),
          selectLetterLabel: l10n.letterJumpSelectLetter,
          selectLetterTitle: l10n.letterJumpSelectLetter,
          minimumItemsForLetterPicker: 100,
        ),
      ),
    );
    if (!mounted || letter == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _PharmacyAlphabeticalLetterScreen(
          title: _title,
          letter: letter,
          kind: widget.kind,
          service: _service,
          initialResults: _resultsByLetter[letter],
        ),
      ),
    );
  }

  void _openResult(ParafarmacoSearchResult result) {
    if (_isDrugCatalog) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AifaSearchResultsScreen(
            query: result.name,
            aifaOnly: true,
            saveRecentSearch: false,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParafarmacoDetailScreen(product: result),
      ),
    );
  }

  String? get _statusText {
    if (_loading) {
      return 'Caricamento elenco alfabetico: $_loadedLetters di ${_letters.length} lettere.';
    }
    if (_failedLetters.isNotEmpty) {
      final failed = _failedLetters.toList()..sort();
      final failedText = failed.join(', ');
      return 'Elenco caricato. Alcune lettere non sono disponibili: $failedText.';
    }
    return null;
  }

  Widget _buildSharedAccessibleList(List<ParafarmacoSearchResult> results) {
    final rows = <AccessibleListRow>[
      AccessibleListRow(
        id: 'select_letter',
        title: AppLocalizations.of(context).letterJumpSelectLetter,
      ),
      if (_statusText != null)
        AccessibleListRow(
          id: 'status',
          title: _statusText!,
          kind: 'text',
          accessibilityButtonTrait: false,
        ),
      if (!_loading && results.isEmpty)
        const AccessibleListRow(
          id: 'empty',
          title: 'Nessun elemento disponibile.',
          kind: 'text',
          accessibilityButtonTrait: false,
        ),
      for (var index = 0; index < results.length; index++)
        AccessibleListRow(
          id: 'item_$index',
          title: results[index].name,
          subtitle: _isDrugCatalog ? 'Farmaco' : results[index].category,
        ),
      if (!_loading && _failedLetters.isNotEmpty)
        const AccessibleListRow(
          id: 'retry',
          title: 'Riprova le lettere non disponibili',
          kind: 'button',
        ),
    ];

    return UniversalAccessibleList(
      sections: [AccessibleListSection(rows: rows)],
      debugTag: _isDrugCatalog ? 'pharmacy-drugs-az' : 'pharmacy-products-az',
      onEvent: (event) async {
        if (event.type != 'activate' || event.id == null) return;
        if (event.id == 'select_letter') {
          await _selectLetter();
          return;
        }
        if (event.id == 'retry') {
          await _loadAllLetters();
          return;
        }
        if (event.id!.startsWith('item_')) {
          final index = int.tryParse(event.id!.substring(5));
          if (index != null && index >= 0 && index < results.length) {
            _openResult(results[index]);
          }
        }
      },
    );
  }

  Widget _buildFlutterList(List<ParafarmacoSearchResult> results) {
    final status = _statusText;
    final extraRows = 1 +
        (status != null ? 1 : 0) +
        (!_loading && results.isEmpty ? 1 : 0) +
        (!_loading && _failedLetters.isNotEmpty ? 1 : 0);

    return ListView.separated(
      itemCount: results.length + extraRows,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        var cursor = index;
        if (cursor == 0) {
          return ListTile(
            leading: const Icon(Icons.sort_by_alpha),
            title: Text(AppLocalizations.of(context).letterJumpSelectLetter),
            trailing: const Icon(Icons.chevron_right),
            onTap: _selectLetter,
          );
        }
        cursor--;

        if (status != null) {
          if (cursor == 0) {
            return ListTile(
              leading: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.info_outline),
              title: Text(status),
            );
          }
          cursor--;
        }

        if (!_loading && results.isEmpty) {
          if (cursor == 0) {
            return const ListTile(title: Text('Nessun elemento disponibile.'));
          }
          cursor--;
        }

        if (cursor < results.length) {
          final result = results[cursor];
          return ListTile(
            title: Text(result.name),
            subtitle: Text(_isDrugCatalog ? 'Farmaco' : result.category),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openResult(result),
          );
        }

        return ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Riprova le lettere non disponibili'),
          onTap: _loadAllLetters,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _allResults;
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? _buildSharedAccessibleList(results)
            : _buildFlutterList(results),
      ),
    );
  }
}

class _PharmacyAlphabeticalLetterScreen extends StatefulWidget {
  const _PharmacyAlphabeticalLetterScreen({
    required this.title,
    required this.letter,
    required this.kind,
    required this.service,
    this.initialResults,
  });

  final String title;
  final String letter;
  final PharmacyAlphabeticalKind kind;
  final ParafarmacoService service;
  final List<ParafarmacoSearchResult>? initialResults;

  @override
  State<_PharmacyAlphabeticalLetterScreen> createState() =>
      _PharmacyAlphabeticalLetterScreenState();
}

class _PharmacyAlphabeticalLetterScreenState
    extends State<_PharmacyAlphabeticalLetterScreen> {
  bool _loading = true;
  String? _error;
  List<ParafarmacoSearchResult> _results = const [];

  bool get _isDrugCatalog => widget.kind == PharmacyAlphabeticalKind.drugs;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialResults;
    if (initial != null && initial.isNotEmpty) {
      _results = List.of(initial)..sort(_compareResults);
      _loading = false;
    } else {
      // Un risultato vuoto ottenuto durante il caricamento globale non e'
      // considerato definitivo: aprendo una lettera la richiediamo di nuovo.
      // Questo evita che un indice temporaneamente ridotto/filtrato dal sito
      // lasci per sempre vuota la schermata della singola lettera.
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = _isDrugCatalog
          ? await widget.service.browseDrugsByLetter(widget.letter)
          : await widget.service.browseParafarmaciByLetter(widget.letter);
      if (!mounted) return;
      setState(() {
        _results = List.of(results)..sort(_compareResults);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _openResult(ParafarmacoSearchResult result) {
    if (_isDrugCatalog) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AifaSearchResultsScreen(
            query: result.name,
            aifaOnly: true,
            saveRecentSearch: false,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParafarmacoDetailScreen(product: result),
      ),
    );
  }

  Widget _buildSharedAccessibleList() {
    final rows = <AccessibleListRow>[];
    if (_loading) {
      rows.add(
        AccessibleListRow(
          id: 'status',
          title: 'Caricamento risultati per la lettera ${widget.letter}...',
          kind: 'text',
          accessibilityButtonTrait: false,
        ),
      );
    } else if (_error != null) {
      rows.add(
        AccessibleListRow(
          id: 'error',
          title: 'Errore nel caricamento della lettera ${widget.letter}',
          subtitle: _error,
          kind: 'text',
          accessibilityButtonTrait: false,
        ),
      );
      rows.add(
        const AccessibleListRow(
          id: 'retry',
          title: 'Riprova',
          kind: 'button',
        ),
      );
    } else if (_results.isEmpty) {
      rows.add(
        AccessibleListRow(
          id: 'empty',
          title: 'Nessun risultato per la lettera ${widget.letter}.',
          kind: 'text',
          accessibilityButtonTrait: false,
        ),
      );
    } else {
      for (var index = 0; index < _results.length; index++) {
        final result = _results[index];
        rows.add(
          AccessibleListRow(
            id: 'item_$index',
            title: result.name,
            subtitle: _isDrugCatalog ? 'Farmaco' : result.category,
          ),
        );
      }
    }

    return UniversalAccessibleList(
      sections: [AccessibleListSection(rows: rows)],
      debugTag: _isDrugCatalog
          ? 'pharmacy-drugs-letter-${widget.letter}'
          : 'pharmacy-products-letter-${widget.letter}',
      onEvent: (event) async {
        if (event.type != 'activate' || event.id == null) return;
        if (event.id == 'retry') {
          await _load();
          return;
        }
        if (event.id!.startsWith('item_')) {
          final index = int.tryParse(event.id!.substring(5));
          if (index != null && index >= 0 && index < _results.length) {
            _openResult(_results[index]);
          }
        }
      },
    );
  }

  Widget _buildFlutterList() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('Caricamento risultati per la lettera ${widget.letter}...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Errore nel caricamento della lettera ${widget.letter}: $_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Riprova')),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text('Nessun risultato per la lettera ${widget.letter}.'),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _results[index];
        return ListTile(
          title: Text(result.name),
          subtitle: Text(_isDrugCatalog ? 'Farmaco' : result.category),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openResult(result),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} - ${widget.letter}')),
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? _buildSharedAccessibleList()
            : _buildFlutterList(),
      ),
    );
  }
}

int _compareResults(
  ParafarmacoSearchResult a,
  ParafarmacoSearchResult b,
) {
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
