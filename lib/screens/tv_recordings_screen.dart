import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/global_recording_service.dart';
import '../services/radio_recording_service.dart';
import '../services/recording_feature_access.dart';
import '../utils/status_message.dart';
import '../widgets/recording_selection_dialog.dart';
import '../widgets/universal_accessible_view.dart';
import 'podcast_episode_player_screen.dart';
import 'create_ai_audiodescription_screen.dart';
import 'recording_rename_screen.dart';

class TvRecordingsScreen extends StatefulWidget {
  const TvRecordingsScreen({super.key});

  @override
  State<TvRecordingsScreen> createState() => _TvRecordingsScreenState();
}

class _TvRecordingsScreenState extends State<TvRecordingsScreen> {
  final _globalRecordingService = GlobalRecordingService.instance;
  final _service = RadioRecordingService(
    directoryName: 'TV Registrazioni',
    includeVideo: true,
  );
  late Future<List<File>> _future;
  bool _isAccessChecked = false;
  bool _isAccessAllowed = false;

  @override
  void initState() {
    super.initState();
    _future = _loadRecordings();
    _globalRecordingService.addListener(_onGlobalRecordingChanged);
    _checkAccess();
  }

  @override
  void dispose() {
    _globalRecordingService.removeListener(_onGlobalRecordingChanged);
    super.dispose();
  }

  void _onGlobalRecordingChanged() {
    if (!mounted) return;
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _loadRecordings();
    });
    _checkAccess();
  }

  Future<List<File>> _loadRecordings() async {
    final recordings = await _service.listRecordings();
    final scheduled =
        _globalRecordingService.pendingScheduledOutput(includeVideo: true);
    if (scheduled == null) return recordings;
    return <File>[
      scheduled,
      ...recordings.where((file) => file.path != scheduled.path),
    ];
  }

  Future<void> _checkAccess() async {
    final isAllowed = await RecordingFeatureAccess.isUnlocked();
    if (!mounted) return;
    setState(() {
      _isAccessAllowed = isAllowed;
      _isAccessChecked = true;
    });
  }

  GlobalRecordingOutputState _recordingState(File file) =>
      _globalRecordingService.outputStateFor(file);

  String? _recordingStatus(File file, AppLocalizations l10n) {
    return switch (_recordingState(file)) {
      GlobalRecordingOutputState.scheduledPending =>
        l10n.scheduledRecordingPendingStatus(
          _formatScheduledStart(file, l10n),
        ),
      GlobalRecordingOutputState.recording => l10n.recordingInProgressStatus,
      GlobalRecordingOutputState.scheduledRecording =>
        l10n.scheduledRecordingInProgressStatus,
      GlobalRecordingOutputState.none => null,
    };
  }

  String _formatScheduledStart(File file, AppLocalizations l10n) {
    final start = _globalRecordingService.scheduledStartForOutput(file);
    if (start == null) return '';
    return DateFormat.yMMMMEEEEd(l10n.localeName).add_Hm().format(start);
  }

  void _openRecording(File file) {
    final state = _recordingState(file);
    final l10n = AppLocalizations.of(context);
    if (state == GlobalRecordingOutputState.scheduledPending) {
      showStatusMessage(
        context,
        l10n.recordingCannotOpenBeforeScheduledStart(
          _formatScheduledStart(file, l10n),
        ),
      );
      return;
    }
    if (state != GlobalRecordingOutputState.none) {
      showStatusMessage(
        context,
        l10n.recordingCannotOpenWhileInProgress,
      );
      return;
    }
    final basename = p.basename(file.path);
    final uri = file.uri.toString();
    final extension = p.extension(file.path).toLowerCase();
    final isAudioOnly = extension == '.m4a' || extension == '.aac';
    final episode = PodcastEpisode(
      id: basename,
      title: p.basenameWithoutExtension(basename),
      description: '',
      audioUrl: uri,
      videoUrl: isAudioOnly ? null : uri,
      publishedAt: file.lastModifiedSync(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/tv/recordings/player'),
        builder: (_) => PodcastEpisodePlayerScreen(
          episode: episode,
          isVideoSupported: !isAudioOnly,
          startWithVideo: !isAudioOnly,
        ),
      ),
    );
  }

  Future<void> _shareRecording(File file) async {
    await _shareRecordings([file]);
  }

  Future<void> _shareRecordings(List<File> files) async {
    if (files.isEmpty) return;
    await SharePlus.instance.share(ShareParams(
      files: files.map((file) => XFile(file.path)).toList(),
      subject: files.length == 1
          ? p.basenameWithoutExtension(files.single.path)
          : AppLocalizations.of(context).recordings,
    ));
  }

  Future<void> _selectAndShareRecordings() async {
    try {
      final recordings = (await _future)
          .where(
            (file) =>
                _recordingState(file) !=
                GlobalRecordingOutputState.scheduledPending,
          )
          .toList(growable: false);
      if (!mounted) return;
      final result = await showRecordingSelectionDialog(context, recordings);
      if (!mounted || result == null || result.recordings.isEmpty) return;
      switch (result.action) {
        case RecordingSelectionAction.share:
          await _shareRecordings(result.recordings);
          break;
        case RecordingSelectionAction.rename:
          await _renameRecording(result.recordings.single);
          break;
        case RecordingSelectionAction.delete:
          await _deleteRecordings(result.recordings);
          break;
      }
    } catch (error) {
      if (mounted) {
        showStatusMessage(context, AppLocalizations.of(context).error(error));
      }
    }
  }

  Future<void> _renameRecording(File file) async {
    if (_recordingState(file) != GlobalRecordingOutputState.none) {
      showStatusMessage(
        context,
        AppLocalizations.of(context).recordingCannotRenameWhileInProgress,
      );
      return;
    }

    final renamed = await showAndRenameRecording(
      context,
      file,
      routeName: '/tv/recordings/rename',
    );
    if (renamed != null && mounted) _reload();
  }

  Future<void> _createAiAudiodescription(File file) async {
    if (_recordingState(file) != GlobalRecordingOutputState.none) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/create_ai_audiodescription'),
        builder: (_) => CreateAiAudiodescriptionScreen(
          initialSourcePath: file.path,
        ),
      ),
    );
  }

  Future<void> _deleteRecording(File file) async {
    await _deleteRecordings([file]);
  }

  Future<void> _deleteRecordings(List<File> files) async {
    var deletedCount = 0;
    for (final file in files) {
      if (await file.exists()) {
        await file.delete();
        deletedCount++;
      }
    }
    if (!mounted) return;
    _reload();
    if (deletedCount > 0) {
      final l10n = AppLocalizations.of(context);
      showStatusMessage(
        context,
        deletedCount == 1 ? l10n.recordingDeleted : l10n.recordingsDeleted,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recordings),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check),
            tooltip: l10n.selectRecordings,
            onPressed: _isAccessAllowed ? _selectAndShareRecordings : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.update,
            onPressed: _reload,
          ),
        ],
      ),
      body: !_isAccessChecked
          ? Center(child: CircularProgressIndicator(semanticsLabel: l10n.loading))
          : !_isAccessAllowed
              ? Center(child: Text(l10n.noRecordings))
              : FutureBuilder<List<File>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.loading,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.error(snapshot.error!)));
          }
          final files = snapshot.data ?? const [];
          if (files.isEmpty) {
            return Center(child: Text(l10n.noRecordings));
          }
          if (useSharedAccessibleViewModel) {
            return UniversalAccessibleList(
              sections: [
                AccessibleListSection(
                  rows: files
                      .asMap()
                      .entries
                      .map((entry) {
                        final state = _recordingState(entry.value);
                        final isPending =
                            state == GlobalRecordingOutputState.scheduledPending;
                        final canCreateAi =
                            state == GlobalRecordingOutputState.none;
                        return AccessibleListRow(
                          id: 'recording_${entry.key}',
                          title: p.basenameWithoutExtension(entry.value.path),
                          value: _recordingStatus(entry.value, l10n),
                          actions: [
                            AccessibleCustomAction(
                              id: 'open',
                              label: l10n.openItem,
                            ),
                            if (!isPending) ...[
                              if (canCreateAi)
                                AccessibleCustomAction(
                                  id: 'ai_audiodescription',
                                  label: l10n.audioDescriptionCreateWithAi,
                                ),
                              AccessibleCustomAction(
                                id: 'share',
                                label: l10n.share,
                              ),
                              AccessibleCustomAction(id: 'rename', label: l10n.rename),
                              AccessibleCustomAction(
                                id: 'delete',
                                label: l10n.deleteItem,
                              ),
                            ],
                          ],
                          visualActions: isPending
                              ? const []
                              : [
                                  if (canCreateAi)
                                    AccessibleVisualAction(
                                      id: 'ai_audiodescription',
                                      label: l10n.audioDescriptionCreateWithAi,
                                      icon: 'ai',
                                    ),
                                  AccessibleVisualAction(
                                    id: 'rename',
                                    label: l10n.rename,
                                    icon: 'edit',
                                  ),
                                ],
                        );
                      })
                      .toList(growable: false),
                ),
              ],
              onEvent: (event) async {
                if (event.id?.startsWith('recording_') != true) return;
                final index = int.tryParse(event.id!.substring(10));
                if (index == null || index < 0 || index >= files.length) return;
                final file = files[index];
                if (event.type == 'activate' || (event.type == 'customAction' && event.action == 'open')) {
                  _openRecording(file);
                } else if (event.type == 'customAction' &&
                    event.action == 'ai_audiodescription') {
                  await _createAiAudiodescription(file);
                } else if (event.type == 'customAction' && event.action == 'share') {
                  await _shareRecording(file);
                } else if (event.type == 'customAction' && event.action == 'rename') {
                  await _renameRecording(file);
                } else if (event.type == 'customAction' && event.action == 'delete') {
                  await _deleteRecording(file);
                }
              },
            );
          }
          return ListView.separated(
            itemCount: files.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final file = files[index];
              final name = p.basenameWithoutExtension(file.path);
              final status = _recordingStatus(file, l10n);
              final state = _recordingState(file);
              final isPending =
                  state == GlobalRecordingOutputState.scheduledPending;
              final canCreateAi = state == GlobalRecordingOutputState.none;
              return Semantics(
                key: ValueKey('tv_recording_semantics_${file.path}'),
                customSemanticsActions: {
                  CustomSemanticsAction(label: l10n.openItem): () =>
                      _openRecording(file),
                  if (!isPending) ...{
                    if (canCreateAi)
                      CustomSemanticsAction(
                        label: l10n.audioDescriptionCreateWithAi,
                      ): () => _createAiAudiodescription(file),
                    CustomSemanticsAction(label: l10n.share): () =>
                        _shareRecording(file),
                    CustomSemanticsAction(label: l10n.rename): () =>
                        _renameRecording(file),
                    CustomSemanticsAction(label: l10n.deleteItem): () =>
                        _deleteRecording(file),
                  },
                },
                child: ListTile(
                  key: ValueKey('tv_recording_${file.path}'),
                  leading: const Icon(Icons.videocam),
                  title: Text(name),
                  subtitle: status == null ? null : Text(status),
                  trailing: isPending
                      ? null
                      : ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canCreateAi)
                          IconButton(
                            key: ValueKey(
                              'tv_recording_ai_audiodescription_${file.path}',
                            ),
                            icon: const Icon(Icons.auto_awesome),
                            tooltip: l10n.audioDescriptionCreateWithAi,
                            onPressed: () => _createAiAudiodescription(file),
                          ),
                        IconButton(
                          key: ValueKey('tv_recording_rename_${file.path}'),
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: l10n.rename,
                          onPressed: () => _renameRecording(file),
                        ),
                        PopupMenuButton<_RecordingAction>(
                          onSelected: (action) {
                            switch (action) {
                              case _RecordingAction.open:
                                _openRecording(file);
                                break;
                              case _RecordingAction.share:
                                _shareRecording(file);
                                break;
                              case _RecordingAction.delete:
                                _deleteRecording(file);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: _RecordingAction.open,
                              child: Text(l10n.openItem),
                            ),
                            PopupMenuItem(
                              value: _RecordingAction.share,
                              child: Text(l10n.share),
                            ),
                            PopupMenuItem(
                              value: _RecordingAction.delete,
                              child: Text(l10n.deleteItem),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  onTap: () => _openRecording(file),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

enum _RecordingAction { open, share, delete }
