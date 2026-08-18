import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../services/recent_routes_service.dart';
import '../services/route_service.dart';
import 'route_result_screen.dart';
import '../utils/status_message.dart';
import 'package:sonarpad_mobile_starter/utils/accessibility_list_behavior.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final _service = RouteService();
  final _recentRoutes = RecentRoutesService();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  String? _countryCode;
  RouteProfile _profile = RouteProfile.driving;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_countryCode == null) {
      final code = AppLocalizations.of(context).localeName;
      _countryCode = switch (code) {
        'es' => 'es',
        'fr' => 'fr',
        'pt' => 'pt',
        'pl' => 'pl',
        'cs' => 'cz',
        _ => 'it',
      };
    }
  }

  RoutePreference _preference = RoutePreference.fastest;
  bool _includeMunicipalities = false;
  bool _calculating = false;

  Future<void> _openRecentRoutes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/route/recent'),
        builder: (_) => const _RecentRoutesScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _calculateRoute() async {
    final l10n = AppLocalizations.of(context);

    final fromAddress = _fromController.text.trim();
    final toAddress = _toController.text.trim();

    if (fromAddress.isEmpty || toAddress.isEmpty) {
            showStatusMessage(context, l10n.routeErrorMissingFields);
      return;
    }

    setState(() => _calculating = true);

    try {
      final from = await _resolveAddress(
        query: fromAddress,
        title: l10n.routeChooseFrom,
        notFoundMessage: l10n.routeErrorFromNotFound,
      );
      if (from == null) return;

      final to = await _resolveAddress(
        query: toAddress,
        title: l10n.routeChooseTo,
        notFoundMessage: l10n.routeErrorToNotFound,
      );
      if (to == null) return;

      final result = await _service.calculateRoute(
        from: from,
        to: to,
        profile: _profile,
        preference: _preference,
        includeMunicipalities: _includeMunicipalities,
        language: l10n.localeName,
        countryCode: _countryCode!,
      );

      await _recentRoutes.addRecentRoute(
        RecentRouteItem.fromResult(
          result: result,
          language: l10n.localeName,
          countryCode: _countryCode!,
          includeMunicipalities: _includeMunicipalities,
        ),
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/route/results'),
          builder: (_) => RouteResultScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
            showStatusMessage(context, l10n.routeError(e));
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  Future<GeocodeCandidate?> _resolveAddress({
    required String query,
    required String title,
    required String notFoundMessage,
  }) async {
    final l10n = AppLocalizations.of(context);
    final candidates = await _service.geocode(
      query: query,
      language: l10n.localeName,
      countryCode: _countryCode!,
    );

    if (candidates.isEmpty) {
      throw Exception(notFoundMessage);
    }

    if (candidates.length == 1) {
      return candidates.first;
    }

    if (!mounted) return null;
    return showDialog<GeocodeCandidate>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              scrollCacheExtent: accessibilityListCacheExtentForPlatform(),
              shrinkWrap: true,
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                return ListTile(
                  title: Text(candidate.displayLabel),
                  onTap: () => Navigator.pop(dialogContext, candidate),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.routeCancel),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeTitle)),
      body: ListView(
        scrollCacheExtent: accessibilityListCacheExtentForPlatform(),
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _calculating ? null : _openRecentRoutes,
            icon: const Icon(Icons.history),
            label: Text(l10n.routeRecentRoutes),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _fromController,
            decoration: InputDecoration(labelText: l10n.routeFrom),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _toController,
            decoration: InputDecoration(labelText: l10n.routeTo),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _calculating ? null : _calculateRoute(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _countryCode,
            decoration: InputDecoration(labelText: l10n.routeCountry),
            items: [
              DropdownMenuItem(
                  value: 'it', child: Text(l10n.routeCountryItaly)),
              DropdownMenuItem(
                  value: 'fr', child: Text(l10n.routeCountryFrance)),
              DropdownMenuItem(
                  value: 'es', child: Text(l10n.routeCountrySpain)),
              DropdownMenuItem(
                  value: 'pt', child: Text(l10n.radioCountryOptionPt)),
              DropdownMenuItem(
                  value: 'pl', child: Text(l10n.radioCountryOptionPl)),
              DropdownMenuItem(
                  value: 'cz', child: Text(l10n.routeCountryCzechRepublic)),
              DropdownMenuItem(
                  value: 'au', child: Text(l10n.radioCountryOptionAu)),
              DropdownMenuItem(
                  value: 'ca', child: Text(l10n.radioCountryOptionCa)),
              DropdownMenuItem(
                  value: 'de', child: Text(l10n.radioCountryOptionDe)),
              DropdownMenuItem(
                  value: 'gb', child: Text(l10n.radioCountryOptionGb)),
              DropdownMenuItem(
                  value: 'us', child: Text(l10n.radioCountryOptionUs)),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _countryCode = val);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<RouteProfile>(
            initialValue: _profile,
            decoration: InputDecoration(labelText: l10n.routeVehicle),
            items: [
              DropdownMenuItem(
                  value: RouteProfile.walking, child: Text(l10n.routeWalking)),
              DropdownMenuItem(
                  value: RouteProfile.cycling, child: Text(l10n.routeCycling)),
              DropdownMenuItem(
                  value: RouteProfile.driving, child: Text(l10n.routeDriving)),
              DropdownMenuItem(
                  value: RouteProfile.wheelchair,
                  child: Text(l10n.routeWheelchair)),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _profile = val);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<RoutePreference>(
            initialValue: _preference,
            decoration: InputDecoration(labelText: l10n.routeType),
            items: [
              DropdownMenuItem(
                  value: RoutePreference.fastest,
                  child: Text(l10n.routeFastest)),
              DropdownMenuItem(
                  value: RoutePreference.shortest,
                  child: Text(l10n.routeShortest)),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _preference = val);
            },
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _includeMunicipalities,
            title: Text(l10n.routeIncludeMunicipalities),
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() => _includeMunicipalities = value ?? false);
            },
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _calculating ? null : _calculateRoute,
            icon: const Icon(Icons.directions),
            label: Text(
                _calculating ? l10n.routeCalculating : l10n.routeCalculate),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRoutesScreen extends StatefulWidget {
  const _RecentRoutesScreen();

  @override
  State<_RecentRoutesScreen> createState() => _RecentRoutesScreenState();
}

class _RecentRoutesScreenState extends State<_RecentRoutesScreen> {
  final RecentRoutesService _recentRoutes = RecentRoutesService();
  final RouteService _routeService = RouteService();
  late Future<List<RecentRouteItem>> _future;
  bool _calculating = false;

  @override
  void initState() {
    super.initState();
    _future = _recentRoutes.loadRecentRoutes();
  }

  void _reload() {
    setState(() {
      _future = _recentRoutes.loadRecentRoutes();
    });
  }

  Future<void> _clearHistory() async {
    await _recentRoutes.clearRecentRoutes();
    if (!mounted) return;
    _reload();
  }

  Future<void> _deleteRoute(RecentRouteItem item) async {
    await _recentRoutes.removeRecentRoute(item.id);
    if (!mounted) return;
    _reload();
  }

  Future<void> _openRoute(RecentRouteItem item) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _calculating = true);
    try {
      final result = await _routeService.calculateRoute(
        from: item.fromCandidate,
        to: item.toCandidate,
        profile: item.profile,
        preference: item.preference,
        includeMunicipalities: item.includeMunicipalities,
        language: item.language,
        countryCode: item.countryCode,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/route/results'),
          builder: (_) => RouteResultScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
            showStatusMessage(context, l10n.routeError(e));
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  String _formattedDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.routeRecentRoutes),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: l10n.clearHistory,
            onPressed: _calculating ? null : _clearHistory,
          ),
        ],
      ),
      body: FutureBuilder<List<RecentRouteItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: Text(l10n.loading));
          }
          final routes = snapshot.data ?? const <RecentRouteItem>[];
          if (routes.isEmpty) {
            return Center(child: Text(l10n.routeRecentRoutesEmpty));
          }
          return ListView.separated(
            scrollCacheExtent: accessibilityListCacheExtentForPlatform(),
            padding: const EdgeInsets.all(16),
            itemCount: routes.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final item = routes[index];
              final title = '${item.fromDisplayLabel} → ${item.toDisplayLabel}';
              final subtitle = _formattedDate(item.createdAt);
              return Semantics(
                customSemanticsActions: {
                  CustomSemanticsAction(label: l10n.deleteItem): () =>
                      _deleteRoute(item),
                },
                child: ListTile(
                  title: Text(title),
                  subtitle: Text(subtitle),
                  trailing: ExcludeSemantics(
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.deleteItem,
                      onPressed: _calculating ? null : () => _deleteRoute(item),
                    ),
                  ),
                  onTap: _calculating ? null : () => _openRoute(item),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

