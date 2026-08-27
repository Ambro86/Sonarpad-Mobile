import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import '../utils/status_message.dart';
import 'radio_player_screen.dart';
import 'radio_screen.dart';
import '../widgets/radio_recording_schedule_action.dart';
import '../widgets/universal_accessible_view.dart'; // Per RadioTile

class FavoriteRadiosScreen extends StatefulWidget {
  const FavoriteRadiosScreen({
    super.key,
    this.recordingFeatureUnlocked = false,
  });

  final bool recordingFeatureUnlocked;

  @override
  State<FavoriteRadiosScreen> createState() => _FavoriteRadiosScreenState();
}

class _FavoriteRadiosScreenState extends State<FavoriteRadiosScreen> {
  final _service = RadioService();
  List<RadioStation> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    final favorites = await _service.loadFavorites();
    if (!mounted) return;
    setState(() {
      _favorites = favorites;
      _loading = false;
    });
  }

  String _sortKey(String value) => value.trim().toLowerCase();

  Future<void> _sortFavoritesAlphabetically() async {
    if (_favorites.length < 2) return;
    final l10n = AppLocalizations.of(context);
    final sorted = List<RadioStation>.from(_favorites)
      ..sort((a, b) => _sortKey(a.name).compareTo(_sortKey(b.name)));
    await _service.saveFavorites(sorted, updateOrder: true);
    if (!mounted) return;
    setState(() => _favorites = sorted);
    showStatusMessage(context, l10n.radioFavoritesSortedAlphabetically);
  }

  Future<void> _toggleFavorite(RadioStation station) async {
    final next = _favorites
        .where((item) => item.streamUrl != station.streamUrl)
        .toList();
    await _service.saveFavorites(next);
    setState(() => _favorites = next);

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    showStatusMessage(context, l10n.radioFavoriteRemoved(station.name));
  }

  Future<void> _play(RadioStation station) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/radio/player'),
        builder: (_) => RadioPlayerScreen(station: station),
      ),
    );
    await _loadFavorites();
  }

  Future<void> _playAndRecord(RadioStation station) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/radio/player'),
        builder: (_) => RadioPlayerScreen(
          station: station,
          autoStartRecording: true,
        ),
      ),
    );
    await _loadFavorites();
  }

  Future<void> _handleAction(_RadioAction action, int index) async {
    final list = List<RadioStation>.from(_favorites);
    final item = list.removeAt(index);

    if (action == _RadioAction.moveUp && index > 0) {
      list.insert(index - 1, item);
      await _service.saveFavorites(list, updateOrder: true);
      setState(() => _favorites = list);
    } else if (action == _RadioAction.moveDown && index < list.length) {
      list.insert(index + 1, item);
      await _service.saveFavorites(list, updateOrder: true);
      setState(() => _favorites = list);
    } else if (action == _RadioAction.moveToPosition) {
      list.insert(index, item);
      final newPos = await showDialog<int>(
        context: context,
        builder: (_) => _RadioPositionSliderDialog(
          currentIndex: index,
          favorites: list,
        ),
      );
      if (newPos != null && newPos != index) {
        final toMove = list.removeAt(index);
        list.insert(newPos, toMove);
        await _service.saveFavorites(list, updateOrder: true);
        setState(() => _favorites = list);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.radioFavoritesButton),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(semanticsLabel: l10n.loading))
          : _favorites.isEmpty
              ? Center(child: Text(l10n.radioNoFavorites))
              : useSharedAccessibleViewModel
                  ? UniversalAccessibleList(
                      key: ValueKey('shared-favorite-radios-${_favorites.length}'),
                      sections: [
                        AccessibleListSection(
                          rows: [
                            if (_favorites.length > 1)
                              AccessibleListRow(
                                id: '__sort__',
                                title: l10n.sortRadioFavoritesAlphabetically,
                                kind: 'button',
                              ),
                            ..._favorites.asMap().entries.map((entry) {
                              final index = entry.key;
                              final station = entry.value;
                              return AccessibleListRow(
                                id: station.streamUrl,
                                title: station.name,
                                subtitle: station.detailsText,
                                accessibilityLabel: station.accessibilityLabel,
                                kind: 'action',
                                actions: [
                                  AccessibleCustomAction(id: 'favorite', label: l10n.radioRemoveFavorite),
                                  if (index > 0) AccessibleCustomAction(id: 'move_up', label: l10n.moveUp),
                                  if (index < _favorites.length - 1) AccessibleCustomAction(id: 'move_down', label: l10n.moveDown),
                                  AccessibleCustomAction(id: 'move_position', label: l10n.moveToPosition),
                                  if (widget.recordingFeatureUnlocked)
                                    AccessibleCustomAction(
                                      id: 'play_record',
                                      label: l10n.playAndRecord,
                                    ),
                                  if (widget.recordingFeatureUnlocked)
                                    AccessibleCustomAction(
                                      id: 'schedule_recording',
                                      label: l10n.radioScheduleDialogTitle,
                                    ),
                                ],
                                visualActions: [
                                  if (widget.recordingFeatureUnlocked)
                                    AccessibleVisualAction(
                                      id: 'play_record',
                                      label: l10n.playAndRecord,
                                      icon: 'record',
                                    ),
                                  if (widget.recordingFeatureUnlocked)
                                    AccessibleVisualAction(
                                      id: 'schedule_recording',
                                      label: l10n.radioScheduleDialogTitle,
                                      icon: 'record',
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ],
                      onEvent: (event) async {
                        if (event.id == '__sort__' && event.type == 'activate') {
                          await _sortFavoritesAlphabetically();
                          return;
                        }
                        final id = event.id;
                        if (id == null) return;
                        final index = _favorites.indexWhere((e) => e.streamUrl == id);
                        if (index < 0) return;
                        final station = _favorites[index];
                        if (event.type == 'activate') {
                          await _play(station);
                        } else if (event.type == 'customAction') {
                          switch (event.action) {
                            case 'favorite': await _toggleFavorite(station); break;
                            case 'move_up': await _handleAction(_RadioAction.moveUp, index); break;
                            case 'move_down': await _handleAction(_RadioAction.moveDown, index); break;
                            case 'move_position': await _handleAction(_RadioAction.moveToPosition, index); break;
                            case 'play_record':
                              if (widget.recordingFeatureUnlocked) {
                                await _playAndRecord(station);
                              }
                              break;
                            case 'schedule_recording':
                              if (widget.recordingFeatureUnlocked) {
                                await showRadioScheduleRecordingAction(context, station);
                              }
                              break;
                          }
                        }
                      },
                    )
                  : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_favorites.length > 1) ...[
                      FilledButton.icon(
                        onPressed: _sortFavoritesAlphabetically,
                        icon: const Icon(Icons.sort_by_alpha),
                        label: Text(l10n.sortRadioFavoritesAlphabetically),
                      ),
                      const SizedBox(height: 8),
                    ],
                    ..._favorites.asMap().entries.map((entry) {
                      final index = entry.key;
                      final station = entry.value;
                      final isFirst = index == 0;
                      final isLast = index == _favorites.length - 1;

                      return Padding(
                        key: ValueKey('favorite_radio_row_${station.streamUrl}'),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RadioTile(
                          key: ValueKey('favorite_radio_tile_${station.streamUrl}'),
                          station: station,
                          isFavorite: true,
                          isPlaying: false,
                          onPlay: () => _play(station),
                          onToggleFavorite: () => _toggleFavorite(station),
                          extraSemanticsActions: {
                            if (!isFirst)
                              CustomSemanticsAction(label: l10n.moveUp): () =>
                                  _handleAction(_RadioAction.moveUp, index),
                            if (!isLast)
                              CustomSemanticsAction(label: l10n.moveDown): () =>
                                  _handleAction(_RadioAction.moveDown, index),
                            CustomSemanticsAction(label: l10n.moveToPosition):
                                () => _handleAction(
                                    _RadioAction.moveToPosition, index),
                            if (widget.recordingFeatureUnlocked)
                              CustomSemanticsAction(
                                label: l10n.playAndRecord,
                              ): () => _playAndRecord(station),
                            if (widget.recordingFeatureUnlocked)
                              CustomSemanticsAction(
                                label: l10n.radioScheduleDialogTitle,
                              ): () => showRadioScheduleRecordingAction(
                                    context,
                                    station,
                                  ),
                          },
                          extraTrailingActions: [
                            if (widget.recordingFeatureUnlocked)
                              IconButton(
                                key: ValueKey(
                                  'favorite_radio_play_record_${station.streamUrl}',
                                ),
                                tooltip: l10n.playAndRecord,
                                onPressed: () => _playAndRecord(station),
                                icon: const Icon(Icons.fiber_manual_record),
                              ),
                            if (widget.recordingFeatureUnlocked)
                              IconButton(
                                key: ValueKey(
                                  'favorite_radio_schedule_${station.streamUrl}',
                                ),
                                tooltip: l10n.radioScheduleDialogTitle,
                                onPressed: () => showRadioScheduleRecordingAction(
                                  context,
                                  station,
                                ),
                                icon: const Icon(Icons.schedule),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}

enum _RadioAction { moveUp, moveDown, moveToPosition }

class _RadioPositionSliderDialog extends StatefulWidget {
  final int currentIndex;
  final List<RadioStation> favorites;

  const _RadioPositionSliderDialog(
      {required this.currentIndex, required this.favorites});

  @override
  State<_RadioPositionSliderDialog> createState() =>
      _RadioPositionSliderDialogState();
}

class _RadioPositionSliderDialogState
    extends State<_RadioPositionSliderDialog> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.currentIndex.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pos = _value.toInt();

    String positionLabel(int requestedPosition) {
      final position =
          requestedPosition.clamp(0, widget.favorites.length - 1).toInt();
      if (position == widget.favorites.length - 1) {
        return l10n.positionLabelLast;
      }
      final targetIndex =
          position >= widget.currentIndex ? position + 1 : position;
      final targetName = targetIndex < widget.favorites.length
          ? widget.favorites[targetIndex].name
          : '';
      return l10n.positionLabel(position + 1, targetName);
    }

    final label = positionLabel(pos);

    return AlertDialog(
      title: Text(l10n.moveToPosition),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Semantics(
            slider: true,
            label: l10n.moveToPosition,
            value: label,
            increasedValue: positionLabel(pos + 1),
            decreasedValue: positionLabel(pos - 1),
            onIncrease: pos < widget.favorites.length - 1
                ? () => setState(() => _value = (pos + 1).toDouble())
                : null,
            onDecrease: pos > 0
                ? () => setState(() => _value = (pos - 1).toDouble())
                : null,
            child: ExcludeSemantics(
              child: Slider(
                value: _value,
                min: 0,
                max: (widget.favorites.length - 1).toDouble(),
                divisions: widget.favorites.length > 1
                    ? widget.favorites.length - 1
                    : 1,
                label: (pos + 1).toString(),
                onChanged: (val) {
                  setState(() {
                    _value = val;
                  });
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, pos),
          child: Text(AppLocalizations.of(context).ok),
        ),
      ],
    );
  }
}
