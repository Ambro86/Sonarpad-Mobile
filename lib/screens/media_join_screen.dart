import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/media_export_destination_service.dart';
import '../services/media_join_service.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

enum _MediaJoinDoneAction { saveDocuments, share }

class MediaJoinScreen extends StatefulWidget {
  const MediaJoinScreen({super.key});

  @override
  State<MediaJoinScreen> createState() => _MediaJoinScreenState();
}

class _MediaJoinScreenState extends State<MediaJoinScreen> {
  final MediaJoinService _service = MediaJoinService();
  final List<MediaJoinItemInfo> _items = <MediaJoinItemInfo>[];
  bool _loadingFiles = false;
  bool _processing = false;
  MediaJoinOutputFormat _outputFormat = MediaJoinOutputFormat.mp3;

  final AccessibleListController _accessibleListController =
      AccessibleListController(debugName: 'media_join');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasVideo = _items.any((item) => item.hasVideo);
    final availableFormats = _availableOutputFormats();

    return Scaffold(
      appBar: SonarpadAppBar(title: Text(l10n.joinMediaTitle)),
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? _buildSharedAccessibleJoinForm(l10n)
            : _buildLegacyJoinForm(l10n, hasVideo, availableFormats),
      ),
    );
  }

  Widget _buildSharedAccessibleJoinForm(AppLocalizations l10n) {
    final hasVideo = _items.any((item) => item.hasVideo);
    final availableFormats = _availableOutputFormats();
    final rows = <AccessibleListRow>[
      AccessibleListRow(
        id: 'description',
        kind: 'text',
        title: l10n.joinMediaDescription,
      ),
      AccessibleListRow(
        id: 'add_files',
        kind: 'button',
        title: l10n.joinMediaAddFiles,
        enabled: !_loadingFiles && !_processing,
      ),
      if (_loadingFiles)
        AccessibleListRow(
          id: 'loading_files',
          kind: 'text',
          title: l10n.joinMediaLoadingFiles,
        ),
      AccessibleListRow(
        id: 'files_header',
        kind: 'header',
        title: l10n.joinMediaFilesTitle,
      ),
      if (_items.isEmpty)
        AccessibleListRow(
          id: 'no_files',
          kind: 'text',
          title: l10n.joinMediaNoFiles,
        )
      else
        ..._items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final fileName = p.basename(item.path);
          final typeLabel = item.hasVideo
              ? l10n.joinMediaVideoLabel
              : l10n.joinMediaAudioLabel;
          return AccessibleListRow(
            id: _accessibleRowId(index),
            title: _itemTitle(index, fileName),
            subtitle: _itemSubtitle(typeLabel, _formatDuration(item.duration)),
            accessibilityLabel: _itemAccessibilityLabel(
              index,
              fileName,
              typeLabel,
              _formatDuration(item.duration),
            ),
            hint: l10n.joinMediaActionsHint,
            kind: 'action',
            accessibilityButtonTrait: false,
            enabled: !_processing,
            mergeFlutterCustomActions: true,
            actions: [
              if (index > 0)
                AccessibleCustomAction(id: 'move_up', label: l10n.moveUp),
              if (index < _items.length - 1)
                AccessibleCustomAction(id: 'move_down', label: l10n.moveDown),
              AccessibleCustomAction(
                id: 'remove',
                label: l10n.joinMediaRemove,
              ),
            ],
            visualActions: [
              if (index > 0)
                AccessibleVisualAction(
                  id: 'move_up',
                  label: l10n.moveUp,
                  icon: 'move_up',
                ),
              if (index < _items.length - 1)
                AccessibleVisualAction(
                  id: 'move_down',
                  label: l10n.moveDown,
                  icon: 'move_down',
                ),
              AccessibleVisualAction(
                id: 'remove',
                label: l10n.joinMediaRemove,
                icon: 'remove',
              ),
            ],
          );
        }),
      if (_items.isNotEmpty)
        AccessibleListRow(
          id: 'format',
          title: l10n.joinMediaFormat,
          kind: 'picker',
          value: _outputFormat.extension,
          valueLabel: _outputFormat.label,
          enabled: !_processing && !_loadingFiles,
          options: [
            for (final format in availableFormats)
              AccessibleOption(value: format.extension, label: format.label),
          ],
        ),
      if (_items.isNotEmpty)
        AccessibleListRow(
          id: 'format_hint',
          kind: 'text',
          title: hasVideo
              ? l10n.joinMediaVideoFormatHint
              : l10n.joinMediaAudioFormatHint,
        ),
      AccessibleListRow(
        id: 'join',
        kind: 'button',
        title: l10n.joinMediaJoin,
        enabled: !_processing && !_loadingFiles && _items.length >= 2,
      ),
    ];

    return UniversalAccessibleList(
      controller: _accessibleListController,
      debugTag: 'media_join',
      sections: [AccessibleListSection(rows: rows)],
      onEvent: (event) async {
        if (event.id == 'add_files' && event.type == 'activate') {
          await _pickFiles();
          return;
        }
        if (event.id == 'format' && event.type == 'picker') {
          final extension = event.value?.toString();
          if (extension == null) return;
          final matches = availableFormats.where(
            (format) => format.extension == extension,
          );
          if (matches.isEmpty || matches.first == _outputFormat) return;
          setState(() => _outputFormat = matches.first);
          await AppLogger.log(
            'Media join: output format selected format=${matches.first.extension}',
          );
          return;
        }
        if (event.id == 'join' && event.type == 'activate') {
          await _joinFiles();
          return;
        }
        if (event.type != 'customAction') return;
        final id = event.id;
        if (id == null || !id.startsWith('join_item_')) return;
        final index = int.tryParse(id.substring('join_item_'.length));
        if (index == null || index < 0 || index >= _items.length) return;
        switch (event.action) {
          case 'move_up':
            if (index > 0) _moveItem(index, index - 1);
            break;
          case 'move_down':
            if (index < _items.length - 1) _moveItem(index, index + 1);
            break;
          case 'remove':
            _removeItem(index);
            break;
        }
      },
    );
  }

  Widget _buildLegacyJoinForm(
    AppLocalizations l10n,
    bool hasVideo,
    List<MediaJoinOutputFormat> availableFormats,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.joinMediaDescription),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loadingFiles || _processing ? null : _pickFiles,
          icon: const Icon(Icons.add),
          label: Text(l10n.joinMediaAddFiles),
        ),
        if (_loadingFiles) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            label: l10n.joinMediaLoadingFiles,
            child: ExcludeSemantics(
              child: Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.joinMediaLoadingFiles)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          l10n.joinMediaFilesTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          Text(l10n.joinMediaNoFiles)
        else
          ...List<Widget>.generate(
            _items.length,
            (index) => _buildMediaItem(l10n, index),
          ),
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _processing || _loadingFiles
                ? null
                : () => _chooseOutputFormat(availableFormats),
            child: Text(
              '${l10n.joinMediaFormat}: ${_outputFormat.label}',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasVideo
                ? l10n.joinMediaVideoFormatHint
                : l10n.joinMediaAudioFormatHint,
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _processing || _loadingFiles || _items.length < 2
              ? null
              : _joinFiles,
          child: Text(l10n.joinMediaJoin),
        ),
      ],
    );
  }

  String _itemTitle(int index, String fileName) =>
      <String>[(index + 1).toString(), fileName].join('. ');

  String _itemSubtitle(String typeLabel, String duration) =>
      <String>[typeLabel, duration].join(' · ');

  String _itemAccessibilityLabel(
    int index,
    String fileName,
    String typeLabel,
    String duration,
  ) =>
      <String>[(index + 1).toString(), fileName, typeLabel, duration].join('. ');

  String _accessibleRowId(int index) => 'join_item_$index';

  Widget _buildMediaItem(AppLocalizations l10n, int index) {
    final item = _items[index];
    final fileName = p.basename(item.path);
    final typeLabel = item.hasVideo
        ? l10n.joinMediaVideoLabel
        : l10n.joinMediaAudioLabel;
    final moveUpAction = CustomSemanticsAction(label: l10n.moveUp);
    final moveDownAction = CustomSemanticsAction(label: l10n.moveDown);
    final removeAction = CustomSemanticsAction(label: l10n.joinMediaRemove);

    final actions = <CustomSemanticsAction, VoidCallback>{
      if (index > 0) moveUpAction: () => _moveItem(index, index - 1),
      if (index < _items.length - 1)
        moveDownAction: () => _moveItem(index, index + 1),
      removeAction: () => _removeItem(index),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        container: true,
        button: false,
        label: _itemAccessibilityLabel(
          index,
          fileName,
          typeLabel,
          _formatDuration(item.duration),
        ),
        hint: l10n.joinMediaActionsHint,
        customSemanticsActions: _processing
            ? const <CustomSemanticsAction, VoidCallback>{}
            : actions,
        child: ExcludeSemantics(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _itemTitle(index, fileName),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(_itemSubtitle(typeLabel, _formatDuration(item.duration))),
                      ],
                    ),
                  ),
                  ExcludeSemantics(
                    child: IconButton(
                      tooltip: l10n.moveUp,
                      onPressed: _processing || index == 0
                          ? null
                          : () => _moveItem(index, index - 1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                  ),
                  ExcludeSemantics(
                    child: IconButton(
                      tooltip: l10n.moveDown,
                      onPressed: _processing || index == _items.length - 1
                          ? null
                          : () => _moveItem(index, index + 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                  ),
                  ExcludeSemantics(
                    child: IconButton(
                      tooltip: l10n.joinMediaRemove,
                      onPressed: _processing ? null : () => _removeItem(index),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: MediaJoinService.supportedExtensions,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    setState(() => _loadingFiles = true);
    var added = 0;
    try {
      for (final picked in result.files) {
        final path = picked.path;
        if (path == null || path.trim().isEmpty) {
          await AppLogger.log(
            'Media join: picked file has no accessible path name="${picked.name}"',
          );
          if (mounted) showStatusMessage(context, l10n.joinMediaFileSkipped);
          continue;
        }
        try {
          final info = await _service.probe(path);
          if (!mounted) return;
          setState(() {
            _items.add(info);
            _syncOutputFormatForItems();
          });
          added++;
          await AppLogger.log(
            'Media join: file added index=${_items.length - 1} '
            'name="${p.basename(path)}" ${info.logSummary}',
          );
        } catch (error) {
          await AppLogger.log(
            'Media join: file rejected path="$path" error=$error',
          );
          if (mounted) showStatusMessage(context, l10n.joinMediaFileSkipped);
        }
      }
      if (mounted && added > 0) {
        announceStatusMessage(context, l10n.joinMediaFilesAdded);
      }
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  void _moveItem(int from, int to) {
    if (_processing ||
        from < 0 ||
        from >= _items.length ||
        to < 0 ||
        to >= _items.length ||
        from == to) {
      return;
    }
    setState(() {
      final item = _items.removeAt(from);
      _items.insert(to, item);
    });
    unawaited(
      AppLogger.log(
        'Media join: item moved from=${from + 1} to=${to + 1} '
        'name="${p.basename(_items[to].path)}"',
      ),
    );
    announceStatusMessage(
      context,
      '${to + 1}. ${p.basename(_items[to].path)}',
    );
    if (useSharedAccessibleViewModel) {
      unawaited(
        _restoreAccessibleFocusAfterStructureChange(_accessibleRowId(to)),
      );
    }
  }

  void _removeItem(int index) {
    if (_processing || index < 0 || index >= _items.length) return;
    final removed = _items[index];
    setState(() {
      _items.removeAt(index);
      _syncOutputFormatForItems();
    });
    unawaited(
      AppLogger.log(
        'Media join: item removed index=${index + 1} '
        'name="${p.basename(removed.path)}"',
      ),
    );
    showStatusMessage(context, AppLocalizations.of(context).joinMediaRemoved);
    if (useSharedAccessibleViewModel && _items.isNotEmpty) {
      final targetIndex = index < _items.length ? index : _items.length - 1;
      unawaited(
        _restoreAccessibleFocusAfterStructureChange(
          _accessibleRowId(targetIndex),
        ),
      );
    }
  }

  Future<void> _restoreAccessibleFocusAfterStructureChange(String id) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _accessibleListController.focusToReturnAfterStructureChange(
      id,
      animated: false,
    );
  }

  List<MediaJoinOutputFormat> _availableOutputFormats() {
    final hasVideo = _items.any((item) => item.hasVideo);
    if (hasVideo) {
      return const <MediaJoinOutputFormat>[
        MediaJoinOutputFormat.mp4,
        MediaJoinOutputFormat.mkv,
        MediaJoinOutputFormat.mov,
        MediaJoinOutputFormat.avi,
        MediaJoinOutputFormat.wmv,
        MediaJoinOutputFormat.mpg,
        MediaJoinOutputFormat.flv,
        MediaJoinOutputFormat.threeGp,
        MediaJoinOutputFormat.ts,
      ];
    }
    return const <MediaJoinOutputFormat>[
      MediaJoinOutputFormat.mp3,
      MediaJoinOutputFormat.m4a,
      MediaJoinOutputFormat.wav,
      MediaJoinOutputFormat.flac,
      MediaJoinOutputFormat.ogg,
      MediaJoinOutputFormat.opus,
      MediaJoinOutputFormat.aac,
      MediaJoinOutputFormat.wma,
      MediaJoinOutputFormat.aiff,
    ];
  }

  void _syncOutputFormatForItems() {
    final formats = _availableOutputFormats();
    if (_items.isEmpty) {
      _outputFormat = MediaJoinOutputFormat.mp3;
      return;
    }
    if (!formats.contains(_outputFormat)) {
      _outputFormat = _items.any((item) => item.hasVideo)
          ? MediaJoinOutputFormat.mp4
          : MediaJoinOutputFormat.mp3;
    }
  }

  Future<void> _chooseOutputFormat(
    List<MediaJoinOutputFormat> availableFormats,
  ) async {
    if (_processing || _loadingFiles || availableFormats.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final selected = await showDialog<MediaJoinOutputFormat>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.joinMediaChooseFormat),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final format in availableFormats)
              ListTile(
                title: Text(format.label),
                selected: format == _outputFormat,
                leading: Icon(
                  format == _outputFormat
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                onTap: () => Navigator.pop(dialogContext, format),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (!mounted || selected == null || selected == _outputFormat) return;
    setState(() => _outputFormat = selected);
    await AppLogger.log(
      'Media join: output format selected format=${selected.extension}',
    );
  }

  Future<void> _joinFiles() async {
    if (_items.length < 2 || _processing) {
      if (mounted) {
        showStatusMessage(
          context,
          AppLocalizations.of(context).joinMediaNeedTwoFiles,
        );
      }
      return;
    }

    final l10n = AppLocalizations.of(context);
    final cancellation = MediaJoinCancellationToken();
    final progress = ValueNotifier<MediaJoinProgress>(
      const MediaJoinProgress(
        fraction: 0,
        stage: MediaJoinStage.preparing,
      ),
    );
    var cancelling = false;
    var confirmingCancel = false;
    BuildContext? dialogContext;
    setState(() => _processing = true);

    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return StatefulBuilder(
          builder: (dialogBuilderContext, setDialogState) {
            return PopScope(
              canPop: false,
              child: AlertDialog(
                title: Text(l10n.joinMediaProcessing),
                content: ValueListenableBuilder<MediaJoinProgress>(
                  valueListenable: progress,
                  builder: (context, value, _) {
                    final percent = (value.fraction * 100).round();
                    final stage = cancelling
                        ? l10n.joinMediaCancelling
                        : _stageLabel(l10n, value);
                    return Semantics(
                      liveRegion: true,
                      container: true,
                      label: stage,
                      value: cancelling ? l10n.joinMediaCancelling : '$percent%',
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(stage),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: cancelling ? null : value.fraction,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cancelling ? l10n.joinMediaCancelling : '$percent%',
                              textAlign: TextAlign.center,
                            ),
                            if (confirmingCancel && !cancelling) ...[
                              const SizedBox(height: 16),
                              Text(
                                l10n.joinMediaCancelConfirmTitle,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.joinMediaCancelConfirmMessage,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                actions: [
                  if (cancelling)
                    TextButton(
                      onPressed: null,
                      child: Text(l10n.joinMediaCancelling),
                    )
                  else if (confirmingCancel) ...[
                    TextButton(
                      onPressed: () {
                        setDialogState(() => confirmingCancel = false);
                      },
                      child: Text(l10n.joinMediaKeepWorking),
                    ),
                    FilledButton(
                      onPressed: () async {
                        setDialogState(() {
                          confirmingCancel = false;
                          cancelling = true;
                        });
                        await AppLogger.log(
                          'Media join UI: cancellation confirmed by user',
                        );
                        await cancellation.cancel();
                      },
                      child: Text(l10n.joinMediaConfirmCancel),
                    ),
                  ] else
                    TextButton(
                      onPressed: () {
                        setDialogState(() => confirmingCancel = true);
                      },
                      child: Text(l10n.cancel),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    await WidgetsBinding.instance.endOfFrame;
    MediaJoinResult? result;
    try {
      result = await _service.join(
        List<MediaJoinItemInfo>.unmodifiable(_items),
        cancellationToken: cancellation,
        outputFormat: _outputFormat,
        onProgress: (value) {
          if (!mounted) return;
          progress.value = value;
        },
      );
    } on MediaJoinCancelled {
      await AppLogger.log('Media join: operation cancelled by user');
      if (mounted) showStatusMessage(context, l10n.joinMediaCancelled);
    } catch (error, stackTrace) {
      await AppLogger.log(
        'Media join: operation failed error=$error stack=$stackTrace',
      );
      if (mounted) showStatusMessage(context, l10n.joinMediaFailed);
    } finally {
      final activeDialog = dialogContext;
      if (activeDialog != null && activeDialog.mounted) {
        try {
          Navigator.of(activeDialog).pop();
        } catch (_) {}
      }
      try {
        await dialogFuture;
      } catch (_) {}
      progress.dispose();
      if (mounted) setState(() => _processing = false);
    }

    if (result != null && mounted) {
      await _showDoneDialog(result.path);
    }
  }

  String _stageLabel(AppLocalizations l10n, MediaJoinProgress progress) {
    return switch (progress.stage) {
      MediaJoinStage.preparing => l10n.joinMediaPreparing,
      MediaJoinStage.normalizing => progress.total > 0
          ? '${l10n.joinMediaNormalizing} ${progress.current}/${progress.total}'
          : l10n.joinMediaNormalizing,
      MediaJoinStage.merging => l10n.joinMediaMerging,
      MediaJoinStage.verifying => l10n.joinMediaVerifying,
      MediaJoinStage.completing => l10n.joinMediaCompleting,
    };
  }

  Future<void> _showDoneDialog(String filePath) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final destinationService = MediaExportDestinationService();

    while (true) {
      if (!mounted) return;
      final action = await showDialog<_MediaJoinDoneAction>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Text(l10n.joinMediaCompleted),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _MediaJoinDoneAction.share),
                child: Text(l10n.share),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _MediaJoinDoneAction.saveDocuments,
                ),
                child: Text(l10n.saveInSonarpadDocuments),
              ),
            ],
          ),
        ),
      );

      if (!mounted || action == null) continue;
      if (action == _MediaJoinDoneAction.share) {
        try {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(filePath)],
              text: p.basename(filePath),
            ),
          );
          await _cleanupOutput(filePath);
          return;
        } catch (error) {
          await AppLogger.log('Media join: share failed error=$error');
          if (mounted) showStatusMessage(context, l10n.technicalErrorGeneric);
          continue;
        }
      }

      try {
        await destinationService.saveInSonarpadDocuments(
          filePath,
          originalName: p.basename(filePath),
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PopScope(
            canPop: false,
            child: AlertDialog(
              content: Text(l10n.exportSavedInSonarpad),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.ok),
                ),
              ],
            ),
          ),
        );
        await _cleanupOutput(filePath);
        return;
      } catch (error) {
        await AppLogger.log(
          'Media join: save in Sonarpad Documents failed error=$error',
        );
        if (mounted) showStatusMessage(context, l10n.technicalErrorGeneric);
      }
    }
  }

  Future<void> _cleanupOutput(String filePath) async {
    try {
      final file = File(filePath);
      final parent = file.parent;
      if (await file.exists()) await file.delete();
      if (await parent.exists()) await parent.delete(recursive: true);
    } catch (error) {
      await AppLogger.log(
        'Media join: staged output cleanup failed path="$filePath" error=$error',
      );
    }
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
