import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';

import '../services/tv_service.dart';
import '../utils/status_message.dart';
import '../widgets/tv_recording_schedule_action.dart';
import '../widgets/universal_accessible_view.dart';

class FavoriteTvsScreen extends StatefulWidget {
  const FavoriteTvsScreen({
    super.key,
    required this.channels,
    required this.currentPrograms,
    required this.onOpenChannel,
    required this.onPlayLive,
    required this.onPlayAndRecord,
    this.recordingFeatureUnlocked = false,
  });

  final List<TvChannel> channels;
  final Map<String, TvProgram> currentPrograms;
  final ValueChanged<TvChannel> onOpenChannel;
  final ValueChanged<TvChannel> onPlayLive;
  final ValueChanged<TvChannel> onPlayAndRecord;
  final bool recordingFeatureUnlocked;

  @override
  State<FavoriteTvsScreen> createState() => _FavoriteTvsScreenState();
}

class _FavoriteTvsScreenState extends State<FavoriteTvsScreen> {
  final _service = TvService();
  List<TvChannel> _favorites = [];
  bool _loading = true;

  TvProgram? _currentProgramFor(TvChannel channel) {
    for (final key in _service.guideLookupKeys(channel)) {
      final program = widget.currentPrograms[key];
      if (program != null) return program;
    }
    return null;
  }

  String _channelLabel(TvChannel channel, TvProgram? currentProgram) {
    final title = currentProgram?.title.trim();
    if (title != null && title.isNotEmpty) {
      return '${channel.name}. Ora in onda: $title';
    }
    return channel.name;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favs = await _service.loadFavorites(
      currentChannels: widget.channels,
    );
    if (!mounted) return;
    setState(() {
      _favorites = favs;
      _loading = false;
    });
  }

  Future<void> _removeFromFavorites(TvChannel channel) async {
    final favs = await _service.loadFavorites();
    favs.removeWhere((favorite) =>
        _service.isSameFavoriteChannel(favorite, channel));
    await _service.saveFavorites(favs);
    if (!mounted) return;
    showStatusMessage(context, '${channel.name} rimosso dai preferiti');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('TV preferite')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? const Center(
                  child: Text(
                    'Nessun canale TV preferito.',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : useSharedAccessibleViewModel
                  ? UniversalAccessibleList(
                      key: ValueKey('shared-favorite-tvs-${_favorites.length}'),
                      sections: [
                        AccessibleListSection(
                          rows: _favorites.map((channel) {
                            final currentProgram = _currentProgramFor(channel);
                            return AccessibleListRow(
                              id: channel.name,
                              title: channel.name,
                              subtitle: currentProgram == null ? null : 'Ora in onda: ${currentProgram.title}',
                              accessibilityLabel: _channelLabel(channel, currentProgram),
                              hint: 'Tocca per aprire il canale TV',
                              kind: 'action',
                              actions: [
                                AccessibleCustomAction(
                                  id: 'play_live',
                                  label: l10n.tvPlayLive,
                                ),
                                const AccessibleCustomAction(
                                  id: 'remove',
                                  label: 'Rimuovi dai preferiti',
                                ),
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
                                AccessibleVisualAction(
                                  id: 'play_live',
                                  label: l10n.tvPlayLive,
                                  icon: 'play',
                                ),
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
                          }).toList(),
                        ),
                      ],
                      onEvent: (event) async {
                        final id = event.id;
                        if (id == null) return;
                        final index = _favorites.indexWhere((e) => e.name == id);
                        if (index < 0) return;
                        final channel = _favorites[index];
                        if (event.type == 'activate') {
                          widget.onOpenChannel(channel);
                        } else if (event.type == 'customAction' &&
                            event.action == 'play_live') {
                          widget.onPlayLive(channel);
                        } else if (event.type == 'customAction' && event.action == 'remove') {
                          await _removeFromFavorites(channel);
                        } else if (event.type == 'customAction' &&
                            event.action == 'play_record' &&
                            widget.recordingFeatureUnlocked) {
                          widget.onPlayAndRecord(channel);
                        } else if (event.type == 'customAction' &&
                            event.action == 'schedule_recording' &&
                            widget.recordingFeatureUnlocked) {
                          await showTvScheduleRecordingAction(context, channel);
                        }
                      },
                    )
                  : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final channel = _favorites[index];
                    final currentProgram = _currentProgramFor(channel);
                    final semanticsLabel = _channelLabel(
                      channel,
                      currentProgram,
                    );

                    return Padding(
                      key: ValueKey('favorite_tv_channel_row_${channel.name}'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: MergeSemantics(
                        child: Semantics(
                          key: ValueKey(
                              'favorite_tv_channel_semantics_${channel.name}'),
                          container: true,
                          button: true,
                          enabled: true,
                          label: semanticsLabel,
                          hint: 'Tocca per aprire il canale TV',
                          onTap: () => widget.onOpenChannel(channel),
                          customSemanticsActions: {
                            CustomSemanticsAction(
                              label: l10n.tvPlayLive,
                            ): () => widget.onPlayLive(channel),
                            const CustomSemanticsAction(
                                    label: 'Rimuovi dai preferiti'):
                                () => _removeFromFavorites(channel),
                            if (widget.recordingFeatureUnlocked)
                              CustomSemanticsAction(
                                label: l10n.playAndRecord,
                              ): () => widget.onPlayAndRecord(channel),
                            if (widget.recordingFeatureUnlocked)
                              CustomSemanticsAction(
                                label: l10n.radioScheduleDialogTitle,
                              ): () => showTvScheduleRecordingAction(
                                    context,
                                    channel,
                                  ),
                          },
                          child: ExcludeSemantics(
                            child: Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(64),
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                    ),
                                    onPressed: () => widget.onOpenChannel(channel),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.tv),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                channel.name,
                                                style: const TextStyle(fontSize: 20),
                                              ),
                                              if (currentProgram != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Ora in onda: ${currentProgram.title}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onPrimary
                                                        .withValues(alpha: 0.8),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  key: ValueKey(
                                    'favorite_tv_play_live_${channel.name}',
                                  ),
                                  tooltip: l10n.tvPlayLive,
                                  icon: const Icon(Icons.play_arrow),
                                  onPressed: () => widget.onPlayLive(channel),
                                ),
                                if (widget.recordingFeatureUnlocked)
                                  IconButton(
                                    key: ValueKey(
                                      'favorite_tv_play_record_${channel.name}',
                                    ),
                                    tooltip: l10n.playAndRecord,
                                    icon: const Icon(Icons.fiber_manual_record),
                                    onPressed: () =>
                                        widget.onPlayAndRecord(channel),
                                  ),
                                if (widget.recordingFeatureUnlocked)
                                  IconButton(
                                    key: ValueKey(
                                      'favorite_tv_schedule_${channel.name}',
                                    ),
                                    tooltip: l10n.radioScheduleDialogTitle,
                                    icon: const Icon(Icons.schedule),
                                    onPressed: () => showTvScheduleRecordingAction(
                                      context,
                                      channel,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
