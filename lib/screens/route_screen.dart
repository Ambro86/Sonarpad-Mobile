import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/ui_route_localizations.dart';
import '../services/route_service.dart';
import 'route_result_screen.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final _service = RouteService();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  String? _countryCode;
  RouteProfile _profile = RouteProfile.driving;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_countryCode == null) {
      final code = AppLocalizations.of(context).locale.languageCode;
      _countryCode = code == 'es' ? 'es' : (code == 'fr' ? 'fr' : 'it');
    }
  }
  RoutePreference _preference = RoutePreference.fastest;
  bool _calculating = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.routeErrorMissingFields)),
      );
      return;
    }

    setState(() => _calculating = true);

    try {
      final result = await _service.routeFromAddresses(
        fromAddress: fromAddress,
        toAddress: toAddress,
        profile: _profile,
        preference: _preference,
        language: l10n.locale.languageCode,
        countryCode: _countryCode!,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.routeError(e))),
      );
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            items: const [
              DropdownMenuItem(value: 'it', child: Text('Italia')),
              DropdownMenuItem(value: 'fr', child: Text('France')),
              DropdownMenuItem(value: 'es', child: Text('España')),
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
              DropdownMenuItem(value: RouteProfile.walking, child: Text(l10n.routeWalking)),
              DropdownMenuItem(value: RouteProfile.cycling, child: Text(l10n.routeCycling)),
              DropdownMenuItem(value: RouteProfile.driving, child: Text(l10n.routeDriving)),
              DropdownMenuItem(value: RouteProfile.wheelchair, child: Text(l10n.routeWheelchair)),
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
              DropdownMenuItem(value: RoutePreference.fastest, child: Text(l10n.routeFastest)),
              DropdownMenuItem(value: RoutePreference.shortest, child: Text(l10n.routeShortest)),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _preference = val);
            },
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _calculating ? null : _calculateRoute,
            icon: const Icon(Icons.directions),
            label: Text(_calculating ? l10n.routeCalculating : l10n.routeCalculate),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
