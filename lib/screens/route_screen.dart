import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../services/recent_routes_service.dart';
import '../services/route_service.dart';
import 'route_result_screen.dart';
import '../utils/status_message.dart';
import '../utils/country_name_helper.dart';
import '../widgets/universal_accessible_view.dart';

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
        'pt_BR' => 'br',
        'pl' => 'pl',
        'cs' => 'cz',
        'de' => 'de',
        'zh_CN' => 'cn',
        'uk' => 'ua',
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
            showStatusMessage(context, l10n.routeError(l10n.technicalErrorGeneric));
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
        if (useSharedAccessibleViewModel) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: UniversalAccessibleList(
                sections: [
                  AccessibleListSection(
                    rows: [
                      for (var i = 0; i < candidates.length; i++)
                        AccessibleListRow(
                          id: 'candidate_$i',
                          title: candidates[i].displayLabel,
                        ),
                    ],
                  ),
                ],
                onEvent: (event) {
                  if (event.type == 'activate' && event.id != null) {
                    final index = int.tryParse(event.id!.split('_').last);
                    if (index != null && index < candidates.length) {
                      Navigator.pop(dialogContext, candidates[index]);
                    }
                  }
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
        }
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
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

  Widget _buildSharedAccessibleRouteForm(AppLocalizations l10n) {
    final countries = [
      AccessibleOption(value: 'it', label: l10n.routeCountryItaly),
      AccessibleOption(value: 'fr', label: l10n.routeCountryFrance),
      AccessibleOption(value: 'es', label: l10n.routeCountrySpain),
      AccessibleOption(value: 'pt', label: l10n.radioCountryOptionPt),
      AccessibleOption(value: 'br', label: l10n.radioCountryOptionBr),
      AccessibleOption(value: 'pl', label: l10n.radioCountryOptionPl),
      AccessibleOption(value: 'cz', label: l10n.routeCountryCzechRepublic),
      AccessibleOption(value: 'au', label: l10n.radioCountryOptionAu),
      AccessibleOption(value: 'ca', label: l10n.radioCountryOptionCa),
      AccessibleOption(value: 'de', label: l10n.radioCountryOptionDe),
      AccessibleOption(value: 'gb', label: l10n.radioCountryOptionGb),
      AccessibleOption(value: 'us', label: l10n.radioCountryOptionUs),
      AccessibleOption(value: 'ua', label: localizedCountryDisplayName('UA', localeName: l10n.localeName)),
      AccessibleOption(value: 'cn', label: l10n.chinaCountryName),
    ];
    String? countryValueLabel;
    for (final option in countries) {
      if (option.value == _countryCode) {
        countryValueLabel = option.label;
        break;
      }
    }
    final profileValueLabel = switch (_profile) {
      RouteProfile.walking => l10n.routeWalking,
      RouteProfile.cycling => l10n.routeCycling,
      RouteProfile.driving => l10n.routeDriving,
      RouteProfile.wheelchair => l10n.routeWheelchair,
    };
    final preferenceValueLabel = switch (_preference) {
      RoutePreference.fastest => l10n.routeFastest,
      RoutePreference.shortest => l10n.routeShortest,
    };
    return UniversalAccessibleList(
      sections: [
        AccessibleListSection(rows: [
          AccessibleListRow(id: 'recent', title: l10n.routeRecentRoutes, enabled: !_calculating),
          AccessibleListRow(id: 'from', title: l10n.routeFrom, kind: 'textField', value: _fromController.text),
          AccessibleListRow(id: 'to', title: l10n.routeTo, kind: 'textField', value: _toController.text, textInputAction: 'done', onSubmitted: (_) { if (!_calculating) _calculateRoute(); }),
          AccessibleListRow(id: 'country', title: l10n.routeCountry, kind: 'picker', value: _countryCode, valueLabel: countryValueLabel, options: countries),
          AccessibleListRow(
            id: 'profile',
            title: l10n.routeVehicle,
            kind: 'picker',
            value: _profile.name,
            valueLabel: profileValueLabel,
            options: [
              AccessibleOption(value: RouteProfile.walking.name, label: l10n.routeWalking),
              AccessibleOption(value: RouteProfile.cycling.name, label: l10n.routeCycling),
              AccessibleOption(value: RouteProfile.driving.name, label: l10n.routeDriving),
              AccessibleOption(value: RouteProfile.wheelchair.name, label: l10n.routeWheelchair),
            ],
          ),
          AccessibleListRow(
            id: 'preference',
            title: l10n.routeType,
            kind: 'picker',
            value: _preference.name,
            valueLabel: preferenceValueLabel,
            options: [
              AccessibleOption(value: RoutePreference.fastest.name, label: l10n.routeFastest),
              AccessibleOption(value: RoutePreference.shortest.name, label: l10n.routeShortest),
            ],
          ),
          AccessibleListRow(id: 'municipalities', title: l10n.routeIncludeMunicipalities, kind: 'toggle', toggleValue: _includeMunicipalities),
          AccessibleListRow(
            id: 'calculate',
            title: _calculating ? l10n.routeCalculating : l10n.routeCalculate,
            kind: 'button',
            enabled: !_calculating,
          ),
        ]),
      ],
      onEvent: (event) async {
        final id = event.id;
        if (id == 'recent' && event.type == 'activate' && !_calculating) {
          await _openRecentRoutes();
        } else if (id == 'from' && event.type == 'textChanged') {
          _fromController.text = event.value?.toString() ?? '';
        } else if (id == 'to' && event.type == 'textChanged') {
          _toController.text = event.value?.toString() ?? '';
        } else if (id == 'country' && event.type == 'picker' && event.value != null) {
          setState(() => _countryCode = event.value.toString());
        } else if (id == 'profile' && event.type == 'picker') {
          final value = event.value?.toString();
          final found = RouteProfile.values.where((e) => e.name == value);
          if (found.isNotEmpty) setState(() => _profile = found.first);
        } else if (id == 'preference' && event.type == 'picker') {
          final value = event.value?.toString();
          final found = RoutePreference.values.where((e) => e.name == value);
          if (found.isNotEmpty) setState(() => _preference = found.first);
        } else if (id == 'municipalities' && event.type == 'toggle') {
          setState(() => _includeMunicipalities = event.value == true);
        } else if (id == 'calculate' && event.type == 'activate' && !_calculating) {
          await _calculateRoute();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeTitle)),
      body: useSharedAccessibleViewModel ? _buildSharedAccessibleRouteForm(l10n) : ListView(
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
                  value: 'br', child: Text(l10n.radioCountryOptionBr)),
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
              DropdownMenuItem(
                  value: 'ua', child: Text(localizedCountryDisplayName('UA', localeName: l10n.localeName))),
              DropdownMenuItem(
                  value: 'cn', child: Text(l10n.chinaCountryName)),
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
            showStatusMessage(context, l10n.routeError(l10n.technicalErrorGeneric));
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
          if (useSharedAccessibleViewModel) {
            return UniversalAccessibleList(
              sections: [
                AccessibleListSection(
                  rows: [
                    for (var i = 0; i < routes.length; i++)
                      AccessibleListRow(
                        id: 'route_$i',
                        title: '${routes[i].fromDisplayLabel} → ${routes[i].toDisplayLabel}',
                        subtitle: _formattedDate(routes[i].createdAt),
                        enabled: !_calculating,
                        actions: [AccessibleCustomAction(id: 'delete', label: l10n.deleteItem)],
                      ),
                  ],
                ),
              ],
              onEvent: (event) async {
                final id = event.id;
                if (id == null || !id.startsWith('route_')) return;
                final index = int.tryParse(id.substring(6));
                if (index == null || index >= routes.length || _calculating) return;
                if (event.type == 'customAction' && event.action == 'delete') {
                  await _deleteRoute(routes[index]);
                } else if (event.type == 'activate') {
                  await _openRoute(routes[index]);
                }
              },
            );
          }
          return ListView.separated(
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

