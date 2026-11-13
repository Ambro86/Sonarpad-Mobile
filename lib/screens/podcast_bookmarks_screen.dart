import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/media_playback_speed.dart';
import '../models/podcast.dart';
import '../services/podcast_bookmarks_service.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';
import 'podcast_episode_player_screen.dart';

class PodcastBookmarksScreen extends StatefulWidget {
  const PodcastBookmarksScreen({super.key});
  @override
  State<PodcastBookmarksScreen> createState() => _PodcastBookmarksScreenState();
}

class _PodcastBookmarksScreenState extends State<PodcastBookmarksScreen> {
  final _service = PodcastBookmarksService();
  List<Map<String, dynamic>>? _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = (await _service.read())
        .where((r) => r['data']['position_seconds'] > 0)
        .toList();
    rows.sort(
      (a, b) => (b['data']['updated_at'] as int).compareTo(
        a['data']['updated_at'] as int,
      ),
    );
    if (mounted) setState(() => _rows = rows);
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final d = row['data'] as Map<String, dynamic>;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PodcastEpisodePlayerScreen(
          speedCategory: MediaPlaybackSpeedCategory.podcasts,
          initialPlaybackPosition: Duration(
            seconds: d['position_seconds'] as int,
          ),
          episode: PodcastEpisode(
            title: d['title'],
            description: '',
            audioUrl: d['url'],
          ),
        ),
      ),
    );
    await _load();
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.documentDeleteBookmarkAction),
        content: Text(row['data']['title'] as String),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteItem),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.save(row['id'] as String, 0, reset: true);
    await _load();
    if (mounted) announceStatusMessage(context, l10n.bookmarkRemoved);
  }

  String _time(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600 ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$remainder';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = _rows;
    return Scaffold(
      appBar: SonarpadAppBar(title: Text(l10n.podcastBookmarks)),
      body: rows == null
          ? const Center(child: CircularProgressIndicator())
          : UniversalAccessibleList(
              sections: [
                AccessibleListSection(
                  rows: [
                    if (rows.isEmpty)
                      AccessibleListRow(
                        id: 'empty',
                        title: l10n.podcastNoBookmarks,
                        kind: 'text',
                      ),
                    for (final row in rows)
                      AccessibleListRow(
                        id: row['id'] as String,
                        title: row['data']['title'] as String,
                        subtitle: _time(row['data']['position_seconds'] as int),
                        onActivate: () => _open(row),
                        actions: [
                          AccessibleCustomAction(
                            id: 'remove',
                            label: l10n.documentDeleteBookmarkAction,
                          ),
                        ],
                        visualActions: [
                          AccessibleVisualAction(
                            id: 'remove',
                            label: l10n.documentDeleteBookmarkAction,
                            icon: 'delete',
                          ),
                        ],
                        onCustomAction: (action) async {
                          if (action == 'remove') await _remove(row);
                        },
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
