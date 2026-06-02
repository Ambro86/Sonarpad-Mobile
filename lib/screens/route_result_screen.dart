import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
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
    final items = _routeStepItems(path, l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeNavigation)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final distanceStr = l10n.formatDistance(item.distanceMeters);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              item.showDistance
                  ? '${item.instruction} ($distanceStr)'
                  : item.instruction,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        },
      ),
    );
  }

  List<_RouteStepItem> _routeStepItems(RoutePath path, AppLocalizations l10n) {
    final items = <_RouteStepItem>[];
    final changes = path.municipalityChanges
        .where((change) => change.name.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    if (changes.isEmpty) {
      return path.steps
          .map((step) => _RouteStepItem(
                instruction: step.instruction,
                distanceMeters: step.distanceMeters,
              ))
          .toList();
    }

    final seenMunicipalities = <String>{};
    final uniqueChanges = changes.where((change) {
      final key = change.name.trim().toLowerCase();
      return seenMunicipalities.add(key);
    }).toList();

    if (uniqueChanges.isNotEmpty && uniqueChanges.first.distanceMeters <= 1.0) {
      items.add(_RouteStepItem(
        instruction:
            '${l10n.routeStartMunicipality}: ${uniqueChanges.first.name.trim()}',
        distanceMeters: uniqueChanges.first.distanceMeters,
        showDistance: false,
      ));
    }

    var nextChangeIndex =
        uniqueChanges.indexWhere((change) => change.distanceMeters > 1.0);
    if (nextChangeIndex < 0) {
      nextChangeIndex = uniqueChanges.length;
    }

    var travelledMeters = 0.0;
    for (final step in path.steps) {
      while (nextChangeIndex < uniqueChanges.length &&
          uniqueChanges[nextChangeIndex].distanceMeters <= travelledMeters) {
        final change = uniqueChanges[nextChangeIndex];
        items.add(_RouteStepItem(
          instruction: '${l10n.routeEnterMunicipality} ${change.name.trim()}',
          distanceMeters: change.distanceMeters,
          showDistance: false,
        ));
        nextChangeIndex += 1;
      }

      items.add(_RouteStepItem(
        instruction: step.instruction,
        distanceMeters: step.distanceMeters,
      ));
      travelledMeters += step.distanceMeters;
    }

    while (nextChangeIndex < uniqueChanges.length) {
      final change = uniqueChanges[nextChangeIndex];
      items.add(_RouteStepItem(
        instruction: '${l10n.routeEnterMunicipality} ${change.name.trim()}',
        distanceMeters: change.distanceMeters,
        showDistance: false,
      ));
      nextChangeIndex += 1;
    }

    return items;
  }
}

class _RouteStepItem {
  final String instruction;
  final double distanceMeters;
  final bool showDistance;

  const _RouteStepItem({
    required this.instruction,
    required this.distanceMeters,
    this.showDistance = true,
  });
}
