import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import '../widgets/universal_accessible_view.dart';

class SonarTubePlayerActionsSettingsScreen extends StatefulWidget {
  const SonarTubePlayerActionsSettingsScreen({super.key});

  @override
  State<SonarTubePlayerActionsSettingsScreen> createState() =>
      _SonarTubePlayerActionsSettingsScreenState();
}

class _SonarTubePlayerActionsSettingsScreenState
    extends State<SonarTubePlayerActionsSettingsScreen> {
  final _settings = AppSettingsService();
  Set<String> _selected = const <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final selected = await _settings.loadSonarTubePlayerActions();
    if (!mounted) return;
    setState(() {
      _selected = selected;
      _loading = false;
    });
  }

  Future<void> _setSelected(String id, bool enabled) async {
    final next = Set<String>.from(_selected);
    if (enabled) {
      next.add(id);
    } else {
      next.remove(id);
    }
    setState(() => _selected = next);
    await _settings.saveSonarTubePlayerActions(next);
  }

  List<(String, String)> _actions(AppLocalizations l10n) => [
        (
          AppSettingsService.sonarTubePlayerActionPrevious,
          l10n.sonarTubePreviousTrack,
        ),
        (
          AppSettingsService.sonarTubePlayerActionNext,
          l10n.sonarTubeNextTrack,
        ),
        (
          AppSettingsService.sonarTubePlayerActionShare,
          l10n.sonarTubeShareVideo,
        ),
        (
          AppSettingsService.sonarTubePlayerActionFavorite,
          l10n.sonarTubeAddFavorite,
        ),
        (
          AppSettingsService.sonarTubePlayerActionChannel,
          l10n.sonarTubeGoToChannel,
        ),
        (
          AppSettingsService.sonarTubePlayerActionComments,
          l10n.sonarTubeViewComments,
        ),
        (
          AppSettingsService.sonarTubePlayerActionTranscript,
          l10n.sonarTubeTranscribeVideo,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = _actions(l10n);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        excludeHeaderSemantics: true,
        leading: BackButton(
          key: const ValueKey('settings_sonartube_player_actions_back'),
          onPressed: () => Navigator.pop(context),
        ),
        title: ExcludeSemantics(
          child: Text(l10n.settingsSonarTubePlayerActions),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(semanticsLabel: l10n.loading),
            )
          : useSharedAccessibleViewModel
              ? UniversalAccessibleList(
                  debugTag: 'settings-sonartube-player-actions',
                  sections: [
                    AccessibleListSection(
                      rows: [
                        AccessibleListRow(
                          id: 'title',
                          title: l10n.settingsSonarTubePlayerActions,
                          kind: 'text',
                          accessibilityButtonTrait: false,
                        ),
                        for (final action in actions)
                          AccessibleListRow(
                            id: 'sonartube_player_action_${action.$1}',
                            title: action.$2,
                            kind: 'toggle',
                            toggleValue: _selected.contains(action.$1),
                            flutterChild: CheckboxListTile(
                              key: ValueKey(
                                'settings_sonartube_player_action_${action.$1}',
                              ),
                              title: Text(action.$2),
                              value: _selected.contains(action.$1),
                              onChanged: (value) =>
                                  _setSelected(action.$1, value == true),
                            ),
                          ),
                      ],
                    ),
                  ],
                  onEvent: (event) async {
                    if (event.type != 'toggle' || event.id == null) return;
                    const prefix = 'sonartube_player_action_';
                    if (!event.id!.startsWith(prefix)) return;
                    final id = event.id!.substring(prefix.length);
                    if (!AppSettingsService.sonarTubePlayerActionIds
                        .contains(id)) {
                      return;
                    }
                    await _setSelected(id, event.value == true);
                  },
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      l10n.settingsSonarTubePlayerActions,
                      key: const ValueKey(
                        'settings_sonartube_player_actions_title',
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    for (final action in actions)
                      CheckboxListTile(
                        key: ValueKey(
                          'settings_sonartube_player_action_${action.$1}',
                        ),
                        title: Text(action.$2),
                        value: _selected.contains(action.$1),
                        onChanged: (value) =>
                            _setSelected(action.$1, value == true),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
    );
  }
}
