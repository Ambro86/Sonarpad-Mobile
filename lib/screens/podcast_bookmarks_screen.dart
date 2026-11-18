import '../services/app_settings_service.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/media_playback_speed.dart';
import '../models/podcast.dart';
import '../models/document_item.dart';
import '../services/document_library_service.dart';
import '../widgets/document_password_dialog.dart';
import 'document_reader_screen.dart';
import '../services/podcast_bookmarks_service.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';
import 'podcast_episode_player_screen.dart';

class PodcastBookmarksScreen extends StatefulWidget {
  const PodcastBookmarksScreen({super.key, this.includeDocuments = false});
  final bool includeDocuments;
  @override
  State<PodcastBookmarksScreen> createState() => _PodcastBookmarksScreenState();
}

class _PodcastBookmarksScreenState extends State<PodcastBookmarksScreen> {
  final _service = PodcastBookmarksService();
  final _library = DocumentLibraryService();
  final _settings = AppSettingsService();
  final _listController = AccessibleListController();
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
    if (widget.includeDocuments) {
      await _library.load();
      for (final document in _library.documents) {
        if (document.isFolder) continue;
        final indexes = <int>{
          if (document.bookmarkIndex > 0) document.bookmarkIndex,
          ...document.bookmarkIndexes.where((index) => index >= 0),
        }.toList()..sort();
        for (final index in indexes) {
          rows.add({
            'id': 'document:${document.id}:$index',
            'document': document,
            'index': index,
            'data': {'title': document.displayName},
          });
        }
      }
    }
    if (widget.includeDocuments) {
      final documentTitles = {
        for (final doc in _library.documents)
          'document_media:${doc.id}': doc.displayName,
      };
      for (final bookmark in await _settings.mediaBookmarks()) {
        rows.add({
          'id': 'media:${bookmark.id}',
          'mediaId': bookmark.id,
          'data': {
            'title': documentTitles[bookmark.id] ?? bookmark.title,
            'position_seconds': bookmark.seconds,
          },
        });
      }
    }
    if (mounted) setState(() => _rows = rows);
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final document = row['document'] as DocumentItem?;
    if (document != null) {
      if (document.isPasswordProtected) {
        final l10n = AppLocalizations.of(context);
        final password = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (_) => DocumentPasswordDialog(
            title: l10n.documentPasswordRequiredTitle,
            prompt: l10n.enterDocumentPasswordToOpen,
            passwordLabel: l10n.documentPassword,
            confirmPasswordLabel: l10n.confirmDocumentPassword,
            requiredMessage: l10n.documentPasswordRequired,
            mismatchMessage: l10n.documentPasswordsDoNotMatch,
            invalidMessage: l10n.incorrectDocumentPassword,
            validator: (value) =>
                _library.verifyDocumentPassword(document, value),
          ),
        );
        if (password == null || !mounted) return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DocumentReaderScreen(
            document: document,
            initialParagraphIndex: row['index'] as int,
          ),
        ),
      );
      await _load();
      return;
    }
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
      barrierDismissible: false,
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
    final oldIndex = _rows!.indexWhere((item) => item['id'] == row['id']);
    await _deleteRow(row);
    await _load();
    if (!mounted) return;
    announceStatusMessage(context, l10n.bookmarkRemoved);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rows = _rows!;
      final target = rows.isEmpty
          ? 'empty'
          : rows[oldIndex.clamp(0, rows.length - 1)]['id'] as String;
      _listController.focusToReturnAfterStructureChange(target);
    });
  }

  Future<void> _deleteRow(Map<String, dynamic> row) async {
    final document = row['document'] as DocumentItem?;
    if (row['mediaId'] != null) {
      await _settings.removeMediaBookmark(row['mediaId'] as String);
    } else if (document == null) {
      await _service.save(row['id'] as String, 0, reset: true);
    } else {
      await _library.load();
      for (final current in _library.documents) {
        if (current.id != document.id) continue;
        final index = row['index'] as int;
        await _library.update(
          current.copyWith(
            bookmarkIndex: current.bookmarkIndex == index
                ? 0
                : current.bookmarkIndex,
            bookmarkIndexes: current.bookmarkIndexes
                .where((i) => i != index)
                .toList(),
          ),
        );
        break;
      }
    }
  }

  Future<void> _removeAll() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAllBookmarks),
        content: Text(l10n.deleteAllBookmarksConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteItem),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _load();
    for (final row in List<Map<String, dynamic>>.of(_rows!)) {
      await _deleteRow(row);
    }
    await _load();
    if (!mounted) return;
    announceStatusMessage(context, l10n.noSavedBookmarks);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _listController.focusToReturnAfterStructureChange('empty');
    });
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
      appBar: SonarpadAppBar(
        title: Text(
          widget.includeDocuments
              ? l10n.manageAllBookmarks
              : l10n.podcastBookmarks,
        ),
      ),
      body: rows == null
          ? const Center(child: CircularProgressIndicator())
          : UniversalAccessibleList(
              controller: _listController,
              sections: [
                AccessibleListSection(
                  rows: [
                    if (rows.isNotEmpty)
                      AccessibleListRow(
                        id: 'delete_all_bookmarks',
                        title: l10n.deleteAllBookmarks,
                        kind: 'button',
                        onActivate: _removeAll,
                      ),
                    if (rows.isEmpty)
                      AccessibleListRow(
                        id: 'empty',
                        title: widget.includeDocuments
                            ? l10n.noSavedBookmarks
                            : l10n.podcastNoBookmarks,
                        kind: 'text',
                      ),
                    for (final row in rows)
                      AccessibleListRow(
                        id: row['id'] as String,
                        title: row['data']['title'] as String,
                        subtitle: row['document'] != null
                            ? l10n.documentBookmarkChoiceLabel(
                                1,
                                (row['index'] as int) + 1,
                              )
                            : _time(row['data']['position_seconds'] as int),
                        onActivate: row['mediaId'] == null
                            ? () => _open(row)
                            : null,
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
