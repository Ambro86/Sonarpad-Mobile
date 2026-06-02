import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import 'package:flutter/semantics.dart';
import 'radio_player_screen.dart';
import 'radio_screen.dart'; // Per RadioTile

class FavoriteRadiosScreen extends StatefulWidget {
  const FavoriteRadiosScreen({super.key});

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

  Future<void> _toggleFavorite(RadioStation station) async {
    final next = _favorites
        .where((item) => item.streamUrl != station.streamUrl)
        .toList();
    await _service.saveFavorites(next);
    setState(() => _favorites = next);

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    SemanticsService.sendAnnouncement(
      View.of(context),
      l10n.radioFavoriteRemoved(station.name),
      TextDirection.ltr,
    );
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

  Future<void> _handleAction(_RadioAction action, int index) async {
    final list = List<RadioStation>.from(_favorites);
    final item = list.removeAt(index);

    if (action == _RadioAction.moveUp && index > 0) {
      list.insert(index - 1, item);
      await _service.saveFavorites(list);
      setState(() => _favorites = list);
    } else if (action == _RadioAction.moveDown && index < list.length) {
      list.insert(index + 1, item);
      await _service.saveFavorites(list);
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
        await _service.saveFavorites(list);
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final station = _favorites[index];
                    final isFirst = index == 0;
                    final isLast = index == _favorites.length - 1;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RadioTile(
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
                        },
                      ),
                    );
                  },
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

    String label;
    if (pos == widget.favorites.length - 1) {
      label = l10n.positionLabelLast;
    } else {
      final targetIndex = pos >= widget.currentIndex ? pos + 1 : pos;
      final targetName = targetIndex < widget.favorites.length
          ? widget.favorites[targetIndex].name
          : '';
      label = l10n.positionLabel(pos + 1, targetName);
    }

    return AlertDialog(
      title: Text(l10n.moveToPosition),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Slider(
            value: _value,
            min: 0,
            max: (widget.favorites.length - 1).toDouble(),
            divisions:
                widget.favorites.length > 1 ? widget.favorites.length - 1 : 1,
            label: (pos + 1).toString(),
            onChanged: (val) {
              setState(() {
                _value = val;
              });
            },
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
