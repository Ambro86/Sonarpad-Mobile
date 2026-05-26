import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/ui_route_localizations.dart';
import '../services/route_service.dart';

class RouteResultScreen extends StatelessWidget {
  final RouteResult result;

  const RouteResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeResultsTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: result.paths.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final path = result.paths[index];
          final distanceStr = l10n.formatDistance(path.distanceMeters);
          final durationStr = l10n.formatDuration(path.durationSeconds);
          
          return ListTile(
            title: Text('${l10n.routeDistance}: $distanceStr'),
            subtitle: Text('${l10n.routeDuration}: $durationStr'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/route/steps'),
                  builder: (_) => RouteStepsScreen(path: path),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class RouteStepsScreen extends StatelessWidget {
  final RoutePath path;

  const RouteStepsScreen({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeNavigation)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: path.steps.length,
        itemBuilder: (context, index) {
          final step = path.steps[index];
          final distanceStr = l10n.formatDistance(step.distanceMeters);
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '${step.instruction} ($distanceStr)',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        },
      ),
    );
  }
}
