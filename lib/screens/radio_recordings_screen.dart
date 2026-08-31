import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/global_recording_service.dart';
import '../services/radio_recording_service.dart';
import '../services/app_settings_service.dart';
import '../services/raiplay_service.dart';
import '../services/raiplay_sound_service.dart';
import '../services/tv_service.dart';
import '../utils/status_message.dart';
import '../widgets/recording_selection_dialog.dart';
import '../widgets/universal_accessible_view.dart';
import 'podcast_episode_player_screen.dart';
import 'recording_rename_screen.dart';

class RadioRecordingsScreen extends StatefulWidget {
  const RadioRecordingsScreen({super.key});

  @override
  State<RadioRecordingsScreen> createState() => _RadioRecordingsScreenState();
}

class _RadioRecordingsScreenState extends State<RadioRecordingsScreen> {
  final _globalRecordingService = GlobalRecordingService.instance;
  final _service = RadioRecordingService();
  final _settings = AppSettingsService();
  late Future<List<File>> _future;
  bool _isAccessChecked = false;
  bool _isAccessAllowed = false;

  @override
  void initState() {
    super.initState();
    _future = _service.listRecordings();
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

  Future<void> _checkAccess() async {
    final code = await _settings.getTvSecretCode();
    final trimmed = code.trim();
    final isAllowed = trimmed.isNotEmpty &&
        (TvService().isSecretCodeValid(trimmed) ||
            RaiPlayService().isSecretCodeValid(trimmed) ||
            RaiPlaySoundService().isSecretCodeValid(trimmed));
    if (!mounted) return;
    setState(() {
      _isAccessAllowed = isAllowed;
      _isAccessChecked = true;
    });
  }

  void _reload() {
    setState(() {
      _future = _service.listRecordings();
    _checkAccess();
    });
  }

  GlobalRecordingOutputState _recordingState(File file) =>
      _globalRecordingService.outputStateFor(file);

  String? _recordingStatus(File file, AppLocalizations l10n) {
    return switch (_recordingState(file)) {
      GlobalRecordingOutputState.recording => l10n.recordingInProgressStatus,
      GlobalRecordingOutputState.scheduledRecording =>
        l10n.scheduledRecordingInProgressStatus,
      GlobalRecordingOutputState.none => null,
    };
  }

  void _openRecording(File file) {
    if (_recordingState(file) != GlobalRecordingOutputState.none) {
      showStatusMessage(
        context,
        AppLocalizations.of(context).recordingCannotOpenWhileInProgress,
      );
      return;
    }
    final basename = p.basename(file.path);
    final episode = PodcastEpisode(
      id: basename,
      title: p.basenameWithoutExtension(basename),
      description: '',
      audioUrl: file.uri.toString(),
      publishedAt: file.lastModifiedSync(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/radio/recordings/player'),
        builder: (_) => PodcastEpisodePlayerScreen(episode: episode),
      ),
    );
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
      routeName: '/radio/recordings/rename',
    );
    if (renamed != null && mounted) _reload();
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
      final recordings = await _future;
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
        showStatusMessage(context, AppLocalizations.of(context).error(AppLocalizations.of(context).technicalErrorGeneric));
      }
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
            return Center(child: Text(l10n.error(l10n.technicalErrorGeneric)));
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
                      .map((entry) => AccessibleListRow(
                            id: 'recording_${entry.key}',
                            title: p.basenameWithoutExtension(entry.value.path),
                            value: _recordingStatus(entry.value, l10n),
                            actions: [
                              AccessibleCustomAction(id: 'open', label: l10n.openItem),
                              AccessibleCustomAction(id: 'share', label: l10n.share),
                              AccessibleCustomAction(id: 'rename', label: l10n.rename),
                              AccessibleCustomAction(id: 'delete', label: l10n.deleteItem),
                            ],
                            visualActions: [
                              AccessibleVisualAction(
                                id: 'rename',
                                label: l10n.rename,
                                icon: 'edit',
                              ),
                            ],
                          ))
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
              return Semantics(
                key: ValueKey('radio_recording_semantics_${file.path}'),
                customSemanticsActions: {
                  CustomSemanticsAction(label: l10n.openItem): () =>
                      _openRecording(file),
                  CustomSemanticsAction(label: l10n.share): () =>
                      _shareRecording(file),
                  CustomSemanticsAction(label: l10n.rename): () =>
                      _renameRecording(file),
                  CustomSemanticsAction(label: l10n.deleteItem): () =>
                      _deleteRecording(file),
                },
                child: ListTile(
                  key: ValueKey('radio_recording_${file.path}'),
                  leading: const Icon(Icons.mic),
                  title: Text(name),
                  subtitle: status == null ? null : Text(status),
                  trailing: ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: ValueKey('radio_recording_rename_${file.path}'),
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
