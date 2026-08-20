import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/universal_accessible_view.dart';

import '../services/aifa_service.dart';
import '../services/parafarmaco_service.dart';
import '../services/recent_searches_service.dart';
import 'aifa_confezioni_screen.dart';
import 'parafarmaco_detail_screen.dart';

class AifaSearchResultsScreen extends StatefulWidget {
  final String query;

  const AifaSearchResultsScreen({super.key, required this.query});

  @override
  State<AifaSearchResultsScreen> createState() =>
      _AifaSearchResultsScreenState();
}

class _AifaSearchResultsScreenState extends State<AifaSearchResultsScreen> {
  static const _recentSearchesDomain = 'farmaci';

  final _service = AifaService();
  final _parafarmacoService = ParafarmacoService();

  bool _aifaLoading = true;
  bool _parafarmacoLoading = true;
  bool _recentSearchSaved = false;
  String? _aifaError;
  String? _parafarmacoError;
  List<AifaDrugResult> _results = [];
  List<ParafarmacoSearchResult> _parafarmacoResults = [];

  @override
  void initState() {
    super.initState();
    _searchAifa();
    _searchParafarmaci();
  }

  Future<void> _searchAifa() async {
    try {
      final results = await _service.searchDrugs(widget.query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _aifaError = null;
        _aifaLoading = false;
      });
      if (results.isNotEmpty) await _saveRecentSearchIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aifaError = e.toString();
        _aifaLoading = false;
      });
    }
  }

  Future<void> _searchParafarmaci() async {
    try {
      final results = await _parafarmacoService.searchProducts(widget.query);
      if (!mounted) return;
      setState(() {
        _parafarmacoResults = results;
        _parafarmacoError = null;
        _parafarmacoLoading = false;
      });
      if (results.isNotEmpty) await _saveRecentSearchIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _parafarmacoError = e.toString();
        _parafarmacoLoading = false;
      });
    }
  }

  Future<void> _saveRecentSearchIfNeeded() async {
    if (_recentSearchSaved) return;
    _recentSearchSaved = true;
    try {
      await RecentSearchesService().addSearch(
        _recentSearchesDomain,
        widget.query,
      );
    } catch (e) {
      debugPrint('Errore salvataggio ricerca farmaci/prodotti recente: $e');
    }
  }

  void _openDrugGroup(AifaDrugResult group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AifaConfezioniScreen(drugGroup: group),
      ),
    );
  }

  void _openParafarmaco(ParafarmacoSearchResult product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParafarmacoDetailScreen(product: product),
      ),
    );
  }

  bool _hideEmptyProductsSection(
    List<ParafarmacoSearchResult> visibleProducts,
  ) {
    return !_aifaLoading &&
        _results.isNotEmpty &&
        !_parafarmacoLoading &&
        _parafarmacoError == null &&
        visibleProducts.isEmpty;
  }

  List<Widget> _buildResultsChildren() {
    final l10n = AppLocalizations.of(context);
    final children = <Widget>[];
    final visibleParafarmacoResults = _aifaLoading
        ? _parafarmacoResults
            .where((product) => !_parafarmacoService.isMedicationResult(product))
            .toList(growable: false)
        : _parafarmacoService.excludeAifaMedicationDuplicates(
            _parafarmacoResults,
            _results,
          );

    children.add(const _SectionHeader(
      title: 'Farmaci AIFA',
      subtitle: 'Medicinali con dati AIFA e foglio illustrativo ufficiale.',
    ));

    if (_aifaLoading) {
      children.add(const _StatusTile.loading(
        title: 'Ricerca farmaci AIFA in corso...',
        subtitle: 'Sto cercando tra i medicinali AIFA.',
      ));
    } else if (_aifaError != null && _results.isEmpty) {
      children.add(_StatusTile.error(
        title: 'Errore nella ricerca AIFA',
        subtitle: _aifaError!,
      ));
    } else if (_results.isEmpty) {
      children.add(const _StatusTile.info(
        title: 'Nessun farmaco AIFA trovato',
        subtitle: 'La ricerca negli altri prodotti può comunque dare risultati.',
      ));
    } else {
      for (final group in _results) {
        final title =
            '${group.denominazione} - ${group.principiAttivi} - AIC ${group.aic9}';
        children.add(ListTile(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${group.confezioni.length} confezioni associate'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openDrugGroup(group),
        ));
      }
    }

    if (!_hideEmptyProductsSection(visibleParafarmacoResults)) {
      children.add(_SectionHeader(
        title: l10n.pharmacyProductsSectionTitle,
        subtitle: 'Schede prodotto non AIFA quando disponibili.',
      ));

      if (_parafarmacoLoading) {
        children.add(_StatusTile.loading(
          title: l10n.pharmacyProductsLoadingTitle,
          subtitle: 'Sto cercando parafarmaci, integratori e dispositivi.',
        ));
      } else if (_parafarmacoError != null && visibleParafarmacoResults.isEmpty) {
        children.add(_StatusTile.error(
          title: l10n.pharmacyProductsErrorTitle,
          subtitle: _parafarmacoError!,
        ));
      } else if (visibleParafarmacoResults.isEmpty) {
        children.add(_StatusTile.info(
          title: l10n.pharmacyProductsNoResultsTitle,
          subtitle: 'Non sono disponibili schede prodotto per questa ricerca.',
        ));
      } else {
        for (final product in visibleParafarmacoResults) {
          children.add(ListTile(
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text([
              product.category,
              if (product.sourceName != 'Codifa/Farmadati') product.sourceName,
              if (product.snippet != null && product.snippet!.trim().isNotEmpty)
                product.snippet!.trim(),
            ].join(' - ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openParafarmaco(product),
          ));
        }
      }
    }

    return children;
  }

  Widget _buildSharedAccessibleResults() {
    final l10n = AppLocalizations.of(context);
    final visibleParafarmacoResults = _aifaLoading
        ? _parafarmacoResults
            .where((product) => !_parafarmacoService.isMedicationResult(product))
            .toList(growable: false)
        : _parafarmacoService.excludeAifaMedicationDuplicates(
            _parafarmacoResults,
            _results,
          );

    final aifaRows = <AccessibleListRow>[];
    if (_aifaLoading) {
      aifaRows.add(const AccessibleListRow(id: 'aifa_status', title: 'Ricerca farmaci AIFA in corso...', subtitle: 'Sto cercando tra i medicinali AIFA.', kind: 'text'));
    } else if (_aifaError != null && _results.isEmpty) {
      aifaRows.add(AccessibleListRow(id: 'aifa_status', title: 'Errore nella ricerca AIFA', subtitle: _aifaError!, kind: 'text'));
    } else if (_results.isEmpty) {
      aifaRows.add(const AccessibleListRow(id: 'aifa_status', title: 'Nessun farmaco AIFA trovato', subtitle: 'La ricerca negli altri prodotti può comunque dare risultati.', kind: 'text'));
    } else {
      for (var i = 0; i < _results.length; i++) {
        final group = _results[i];
        aifaRows.add(AccessibleListRow(
          id: 'aifa_$i',
          title: '${group.denominazione} - ${group.principiAttivi} - AIC ${group.aic9}',
          subtitle: '${group.confezioni.length} confezioni associate',
        ));
      }
    }

    final productRows = <AccessibleListRow>[];
    if (_parafarmacoLoading) {
      productRows.add(AccessibleListRow(id: 'product_status', title: l10n.pharmacyProductsLoadingTitle, subtitle: 'Sto cercando parafarmaci, integratori e dispositivi.', kind: 'text'));
    } else if (_parafarmacoError != null && visibleParafarmacoResults.isEmpty) {
      productRows.add(AccessibleListRow(id: 'product_status', title: l10n.pharmacyProductsErrorTitle, subtitle: _parafarmacoError!, kind: 'text'));
    } else if (visibleParafarmacoResults.isEmpty) {
      productRows.add(AccessibleListRow(id: 'product_status', title: l10n.pharmacyProductsNoResultsTitle, subtitle: 'Non sono disponibili schede prodotto per questa ricerca.', kind: 'text'));
    } else {
      for (var i = 0; i < visibleParafarmacoResults.length; i++) {
        final product = visibleParafarmacoResults[i];
        productRows.add(AccessibleListRow(
          id: 'product_$i',
          title: product.name,
          subtitle: [
            product.category,
            if (product.sourceName != 'Codifa/Farmadati') product.sourceName,
            if (product.snippet != null && product.snippet!.trim().isNotEmpty) product.snippet!.trim(),
          ].join(' - '),
        ));
      }
    }

    return UniversalAccessibleList(
      sections: [
        AccessibleListSection(header: 'Farmaci AIFA', footer: 'Medicinali con dati AIFA e foglio illustrativo ufficiale.', rows: aifaRows),
        if (!_hideEmptyProductsSection(visibleParafarmacoResults))
          AccessibleListSection(header: l10n.pharmacyProductsSectionTitle, footer: 'Schede prodotto non AIFA quando disponibili.', rows: productRows),
      ],
      onEvent: (event) {
        if (event.type != 'activate' || event.id == null) return;
        if (event.id!.startsWith('aifa_')) {
          final index = int.tryParse(event.id!.substring(5));
          if (index != null && index >= 0 && index < _results.length) _openDrugGroup(_results[index]);
        } else if (event.id!.startsWith('product_')) {
          final visible = _aifaLoading
              ? _parafarmacoResults.where((p) => !_parafarmacoService.isMedicationResult(p)).toList(growable: false)
              : _parafarmacoService.excludeAifaMedicationDuplicates(_parafarmacoResults, _results);
          final index = int.tryParse(event.id!.substring(8));
          if (index != null && index >= 0 && index < visible.length) _openParafarmaco(visible[index]);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Risultati: ${widget.query}'),
      ),
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? _buildSharedAccessibleResults()
            : ListView(
                children: _buildResultsChildren(),
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final IconData? icon;
  final bool loading;
  final String title;
  final String subtitle;

  const _StatusTile._({
    required this.title,
    required this.subtitle,
    this.icon,
    this.loading = false,
  });

  const _StatusTile.loading({
    required String title,
    required String subtitle,
  }) : this._(
          title: title,
          subtitle: subtitle,
          loading: true,
        );

  const _StatusTile.info({
    required String title,
    required String subtitle,
  }) : this._(
          title: title,
          subtitle: subtitle,
          icon: Icons.info_outline,
        );

  const _StatusTile.error({
    required String title,
    required String subtitle,
  }) : this._(
          title: title,
          subtitle: subtitle,
          icon: Icons.warning_amber,
        );

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
