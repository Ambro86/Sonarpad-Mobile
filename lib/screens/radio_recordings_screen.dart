import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/radio_recording_service.dart';
import '../services/app_settings_service.dart';
import '../services/raiplay_service.dart';
import '../services/raiplay_sound_service.dart';
import '../services/tv_service.dart';
import '../utils/status_message.dart';
import '../widgets/recording_selection_dialog.dart';
import '../widgets/native_ios_accessible_view.dart';
import 'podcast_episode_player_screen.dart';

class RadioRecordingsScreen extends StatefulWidget {
  const RadioRecordingsScreen({super.key});

  @override
  State<RadioRecordingsScreen> createState() => _RadioRecordingsScreenState();
}

class _RadioRecordingsScreenState extends State<RadioRecordingsScreen> {
  final _service = RadioRecordingService();
  final _settings = AppSettingsService();
  late Future<List<File>> _future;
  bool _isAccessChecked = false;
  bool _isAccessAllowed = false;

  @override
  void initState() {
    super.initState();
    _future = _service.listRecordings();
    _checkAccess();
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

  void _openRecording(File file) {
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

  Future<void> _deleteRecording(File file) async {
    await _deleteRecordings([file]);
  }

  Future<void> _deleteRecordings(List<File> files) async {
    for (final file in files) {
      if (await file.exists()) {
        await file.delete();
      }
    }
    _reload();
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

  String _openLabel(String localeName) => switch (localeName) {
        'en' => 'Open',
        'es' => 'Abrir',
        'fr' => 'Ouvrir',
        'pt' => 'Abrir',
        'pl' => 'Otwórz',
        _ => 'Apri',
      };

  String _deleteLabel(String localeName) => switch (localeName) {
        'en' => 'Delete',
        'es' => 'Eliminar',
        'fr' => 'Supprimer',
        'pt' => 'Eliminar',
        'pl' => 'Usuń',
        _ => 'Elimina',
      };

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
          if (useNativeIosAccessibleViews) {
            return NativeIosAccessibleList(
              sections: [
                NativeIosListSection(
                  rows: files
                      .asMap()
                      .entries
                      .map((entry) => NativeIosListRow(
                            id: 'recording_${entry.key}',
                            title: p.basenameWithoutExtension(entry.value.path),
                            actions: [
                              NativeIosCustomAction(id: 'open', label: _openLabel(l10n.localeName)),
                              NativeIosCustomAction(id: 'share', label: l10n.share),
                              NativeIosCustomAction(id: 'delete', label: _deleteLabel(l10n.localeName)),
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
              return Semantics(
                key: ValueKey('radio_recording_semantics_${file.path}'),
                customSemanticsActions: {
                  CustomSemanticsAction(label: _openLabel(l10n.localeName)): () =>
                      _openRecording(file),
                  CustomSemanticsAction(label: l10n.share): () =>
                      _shareRecording(file),
                  CustomSemanticsAction(label: _deleteLabel(l10n.localeName)): () =>
                      _deleteRecording(file),
                },
                child: ListTile(
                  key: ValueKey('radio_recording_${file.path}'),
                  leading: const Icon(Icons.mic),
                  title: Text(name),
                  trailing: ExcludeSemantics(
                    child: PopupMenuButton<_RecordingAction>(
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
                          child: Text(_openLabel(l10n.localeName)),
                        ),
                        PopupMenuItem(
                          value: _RecordingAction.share,
                          child: Text(l10n.share),
                        ),
                        PopupMenuItem(
                          value: _RecordingAction.delete,
                          child: Text(_deleteLabel(l10n.localeName)),
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
