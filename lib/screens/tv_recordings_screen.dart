import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/podcast.dart';
import '../services/radio_recording_service.dart';
import 'podcast_episode_player_screen.dart';

class TvRecordingsScreen extends StatefulWidget {
  const TvRecordingsScreen({super.key});

  @override
  State<TvRecordingsScreen> createState() => _TvRecordingsScreenState();
}

class _TvRecordingsScreenState extends State<TvRecordingsScreen> {
  final _service = RadioRecordingService(
    directoryName: 'TV Registrazioni',
    includeVideo: true,
  );
  late Future<List<File>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.listRecordings();
  }

  void _reload() {
    setState(() {
      _future = _service.listRecordings();
    });
  }

  void _openRecording(File file) {
    final basename = p.basename(file.path);
    final uri = file.uri.toString();
    final isAudioOnly = p.extension(file.path).toLowerCase() == '.m4a';
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
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      subject: p.basenameWithoutExtension(file.path),
    ));
  }

  Future<void> _deleteRecording(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
    _reload();
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
            icon: const Icon(Icons.refresh),
            tooltip: l10n.update,
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<File>>(
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
          return ListView.separated(
            itemCount: files.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final file = files[index];
              final name = p.basenameWithoutExtension(file.path);
              return Semantics(
                key: ValueKey('tv_recording_semantics_${file.path}'),
                customSemanticsActions: {
                  CustomSemanticsAction(label: _openLabel(l10n.localeName)): () =>
                      _openRecording(file),
                  CustomSemanticsAction(label: l10n.share): () =>
                      _shareRecording(file),
                  CustomSemanticsAction(label: _deleteLabel(l10n.localeName)): () =>
                      _deleteRecording(file),
                },
                child: ListTile(
                  key: ValueKey('tv_recording_${file.path}'),
                  leading: const Icon(Icons.videocam),
                  title: Text(name),
                  subtitle: Text(file.path),
                  trailing: PopupMenuButton<_RecordingAction>(
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
