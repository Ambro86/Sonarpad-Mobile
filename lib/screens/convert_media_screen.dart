import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../utils/app_logger.dart';
import '../utils/status_message.dart';

enum _MediaFormat {
  mp3('mp3', 'MP3'),
  aac('m4a', 'AAC (M4A)'),
  m4b('m4b', 'M4B'),
  mp4('mp4', 'MP4'),
  avi('avi', 'AVI'),
  mov('mov', 'MOV'),
  opus('opus', 'Opus'),
  ogg('ogg', 'OGG (Vorbis)'),
  flac('flac', 'FLAC'),
  wav('wav', 'WAV'),
  aiff('aiff', 'AIFF');

  const _MediaFormat(this.extension, this.label);

  final String extension;
  final String label;
}

enum _ConvertDoneAction { share, close }

enum _WavBitDepth {
  pcm16('pcm_s16le', '16-bit'),
  pcm24('pcm_s24le', '24-bit'),
  pcm32('pcm_s32le', '32-bit'),
  float32('pcm_f32le', '32-bit float');

  const _WavBitDepth(this.codec, this.label);

  final String codec;
  final String label;
}

class ConvertMediaScreen extends StatefulWidget {
  const ConvertMediaScreen({super.key});

  @override
  State<ConvertMediaScreen> createState() => _ConvertMediaScreenState();
}

class _ConvertMediaScreenState extends State<ConvertMediaScreen> {
  final _inputController = TextEditingController();
  final _outputController = TextEditingController();
  final _imageController = TextEditingController();
  final _bitrateController = TextEditingController(text: '192');
  String _inputPath = '';
  String _outputDirectory = '';
  String _imagePath = '';

  _MediaFormat _format = _MediaFormat.mp3;
  _WavBitDepth _wavBitDepth = _WavBitDepth.pcm16;
  int _oggQuality = 5;
  int _flacCompression = 5;
  bool _running = false;
  String? _status;

  static const _mediaExtensions = [
    'mp3',
    'm4a',
    'mp4',
    'aac',
    'mkv',
    'avi',
    'mov',
    'm4v',
    'webm',
    'mpg',
    'mpeg',
    'ts',
    'm2ts',
    'mts',
    'wmv',
    'asf',
    'flv',
    'vob',
    '3gp',
    'flac',
    'ogg',
    'opus',
    'wma',
    'aiff',
    'm4b',
    'wav',
  ];

  static const _imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'bmp',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _outputController.dispose();
    _imageController.dispose();
    _bitrateController.dispose();
    super.dispose();
  }

  Future<void> _pickInput() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _mediaExtensions,
    );
    final path =
        result == null || result.files.isEmpty ? null : result.files.first.path;
    if (path == null || path.isEmpty) return;

    setState(() {
      _inputPath = path;
      _inputController.text = _shortPath(path, parentCount: 1);
    });
    if (_outputDirectory.isEmpty) {
      final outputDirectory = await _defaultOutputDirectory();
      if (!mounted) return;
      setState(() {
        _outputDirectory = outputDirectory;
        _outputController.text = _defaultOutputDirectoryDisplayPath(
          outputDirectory,
        );
      });
    }
  }

  Future<void> _pickOutput() async {
    final l10n = AppLocalizations.of(context);
    final initialDirectory = _outputDirectory.isEmpty
        ? await _defaultOutputDirectory()
        : _outputDirectory;
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: l10n.convertMediaOutput,
      initialDirectory: initialDirectory,
    );
    if (path == null || path.isEmpty) return;

    final writable = await _isWritableOutputDirectory(path);
    if (!mounted) return;
    if (!writable) {
      await AppLogger.log(
        'Convert media: selected output directory is not writable, '
        'path="$path"; using default app folder',
      );
      final fallback = await _defaultOutputDirectory();
      if (!mounted) return;
      setState(() {
        _outputDirectory = fallback;
        _outputController.text = _defaultOutputDirectoryDisplayPath(fallback);
      });
      _showSnack(l10n.convertMediaOutputNotWritable);
      return;
    }

    setState(() {
      _outputDirectory = path;
      _outputController.text = _shortPath(path, parentCount: 2);
    });
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _imageExtensions,
    );
    final path =
        result == null || result.files.isEmpty ? null : result.files.first.path;
    if (path == null || path.isEmpty) return;
    setState(() {
      _imagePath = path;
      _imageController.text = _shortPath(path, parentCount: 1);
    });
  }

  Future<bool> _isWritableOutputDirectory(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) return false;
      final testFile = File(
        p.join(
          path,
          '.sonarpad_write_test_${DateTime.now().microsecondsSinceEpoch}.tmp',
        ),
      );
      await testFile.writeAsString('test', flush: true);
      if (await testFile.exists()) {
        await testFile.delete();
      }
      return true;
    } catch (error) {
      await AppLogger.log(
        'Convert media: output directory write test failed path="$path" '
        'error=$error',
      );
      return false;
    }
  }

  Future<void> _convert() async {
    final l10n = AppLocalizations.of(context);
    final input = _inputPath;
    final outputDirectory = _outputDirectory;

    if (input.isEmpty) {
      _showSnack(l10n.convertMediaNoInput);
      return;
    }
    if (outputDirectory.isEmpty) {
      _showSnack(l10n.convertMediaNoOutput);
      return;
    }
    if (!await File(input).exists()) {
      _showSnack(l10n.fileInaccessible(p.basename(input)));
      return;
    }
    if (_requiresImage(input)) {
      final image = _imagePath;
      if (image.isEmpty) {
        _showSnack(l10n.convertMediaNoImage);
        return;
      }
      if (!await File(image).exists()) {
        _showSnack(l10n.fileInaccessible(p.basename(image)));
        return;
      }
    }

    final bitrate = int.tryParse(_bitrateController.text.trim());
    if (_usesBitrate(_format) &&
        (bitrate == null || bitrate < 64 || bitrate > 320)) {
      _showSnack(l10n.convertMediaInvalidBitrate);
      return;
    }

    setState(() {
      _running = true;
      _status = l10n.convertMediaRunning;
    });

    try {
      var effectiveOutputDirectory = outputDirectory;
      if (!await _isWritableOutputDirectory(effectiveOutputDirectory)) {
        await AppLogger.log(
          'Convert media: output directory not writable at conversion time, '
          'path="$effectiveOutputDirectory"; using default app folder',
        );
        effectiveOutputDirectory = await _defaultOutputDirectory();
        if (!mounted) return;
        setState(() {
          _outputDirectory = effectiveOutputDirectory;
          _outputController.text = _defaultOutputDirectoryDisplayPath(
            effectiveOutputDirectory,
          );
        });
        _showSnack(l10n.convertMediaOutputNotWritable);
      }
      final effectiveOutput = _buildOutputPath(input, effectiveOutputDirectory);
      if (p.equals(input, effectiveOutput)) {
        _showSnack(l10n.convertMediaSamePath);
        setState(() => _running = false);
        return;
      }

      await _runWithProgressDialog(l10n, () async {
        final arguments = await _buildArguments(
          input,
          effectiveOutput,
          bitrate ?? 192,
        );
        await AppLogger.log(
          'Convert media: start input="$input" output="$effectiveOutput" '
          'format=${_format.label} bitrate=${bitrate ?? 192} '
          'wavBitDepth=${_format == _MediaFormat.wav ? _wavBitDepth.label : ''} '
          'image="${_requiresImage(input) ? _imagePath : ''}" '
          'args=${arguments.map(_quoteLogArg).join(' ')}',
        );
        final session = await FFmpegKit.executeWithArguments(arguments);
        final returnCode = await session.getReturnCode();
        final logs = await session.getAllLogsAsString() ?? '';
        if (!ReturnCode.isSuccess(returnCode)) {
          await AppLogger.log(
            'Convert media: failed returnCode=${returnCode?.getValue()} '
            'output="$effectiveOutput" logs="${_compactLog(logs)}"',
          );
          throw logs.trim().isEmpty ? returnCode?.getValue() ?? 'FFmpeg' : logs;
        }

        final outputFile = File(effectiveOutput);
        final exists = await outputFile.exists();
        final length = exists ? await outputFile.length() : 0;
        await AppLogger.log(
          'Convert media: completed output="$effectiveOutput" exists=$exists bytes=$length '
          'returnCode=${returnCode?.getValue()}',
        );
      });
      if (!mounted) return;
      setState(() {
        _running = false;
        _status = l10n.convertMediaDone;
      });
      await _showDoneDialog(l10n.convertMediaDone, filePath: effectiveOutput);
    } catch (error) {
      await AppLogger.log('Convert media: error $error');
      if (!mounted) return;
      setState(() => _status = l10n.convertMediaReady);
      _showSnack(l10n.convertMediaFailed(error));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _runWithProgressDialog(
    AppLocalizations l10n,
    Future<void> Function() task,
  ) async {
    final taskFuture = task();
    var closeAttached = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        void closeDialog() {
          if (!dialogContext.mounted) return;
          Navigator.of(dialogContext).pop();
        }

        if (!closeAttached) {
          closeAttached = true;
          taskFuture.then(
            (_) => closeDialog(),
            onError: (error, stackTrace) => closeDialog(),
          );
        }

        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.convertMediaRunning),
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ),
          ),
        );
      },
    );

    await taskFuture;
  }

  String _quoteLogArg(String value) {
    if (!value.contains(' ')) return value;
    return '"${value.replaceAll('"', r'\"')}"';
  }

  String _compactLog(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 1200) return compact;
    return '${compact.substring(0, 1200)}...';
  }

  Future<void> _showDoneDialog(String message, {String? filePath}) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final action = await showDialog<_ConvertDoneAction>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          if (filePath != null)
            TextButton(
              onPressed: () => Navigator.pop(context, _ConvertDoneAction.share),
              child: Text(l10n.share),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _ConvertDoneAction.close),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );

    if (!mounted || action != _ConvertDoneAction.share || filePath == null) {
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        text: p.basename(filePath),
      ),
    );
  }

  Future<List<String>> _buildArguments(
    String input,
    String output,
    int bitrate,
  ) async {
    final audioInputToVideo = _isVideoFormat(_format) && !_isVideoInput(input);
    final coverPath = audioInputToVideo ? _imagePath : null;

    return [
      '-y',
      if (coverPath != null) ...[
        '-loop',
        '1',
        '-i',
        coverPath,
      ],
      '-i',
      input,
      if (coverPath != null) ...[
        '-map',
        '0:v:0',
        '-map',
        '1:a:0',
      ],
      if (_audioOnly(_format)) '-vn',
      ..._codecArguments(bitrate, input),
      if (coverPath != null) ...[
        '-shortest',
        '-pix_fmt',
        'yuv420p',
      ],
      output,
    ];
  }

  List<String> _codecArguments(int bitrate, String input) {
    return switch (_format) {
      _MediaFormat.mp3 => ['-c:a', 'libmp3lame', '-b:a', '${bitrate}k'],
      _MediaFormat.aac || _MediaFormat.m4b => [
          '-c:a',
          'aac',
          '-b:a',
          '${bitrate}k',
        ],
      _MediaFormat.mp4 || _MediaFormat.mov => [
          '-c:v',
          _isVideoInput(input) ? 'mpeg4' : 'libx264',
          if (_isVideoInput(input)) ...[
            '-q:v',
            '4',
          ] else ...[
            '-tune',
            'stillimage',
          ],
          '-c:a',
          'aac',
          '-b:a',
          '${bitrate}k',
        ],
      _MediaFormat.avi => [
          '-c:v',
          'mpeg4',
          '-q:v',
          '4',
          '-c:a',
          'libmp3lame',
          '-b:a',
          '${bitrate}k',
        ],
      _MediaFormat.opus => ['-c:a', 'libopus', '-b:a', '${bitrate}k'],
      _MediaFormat.ogg => ['-c:a', 'libvorbis', '-q:a', '$_oggQuality'],
      _MediaFormat.flac => [
          '-c:a',
          'flac',
          '-compression_level',
          '$_flacCompression',
        ],
      _MediaFormat.wav => ['-c:a', _wavBitDepth.codec],
      _MediaFormat.aiff => ['-c:a', 'pcm_s16le'],
    };
  }

  bool _usesBitrate(_MediaFormat format) {
    return switch (format) {
      _MediaFormat.mp3 ||
      _MediaFormat.aac ||
      _MediaFormat.m4b ||
      _MediaFormat.mp4 ||
      _MediaFormat.avi ||
      _MediaFormat.mov ||
      _MediaFormat.opus =>
        true,
      _ => false,
    };
  }

  bool _audioOnly(_MediaFormat format) {
    return switch (format) {
      _MediaFormat.mp4 || _MediaFormat.avi || _MediaFormat.mov => false,
      _ => true,
    };
  }

  bool _isVideoFormat(_MediaFormat format) {
    return switch (format) {
      _MediaFormat.mp4 || _MediaFormat.avi || _MediaFormat.mov => true,
      _ => false,
    };
  }

  bool _isVideoInput(String inputPath) {
    final extension =
        p.extension(inputPath).toLowerCase().replaceFirst('.', '');
    return const {
      'mp4',
      'avi',
      'mov',
      'mkv',
      'm4v',
      'webm',
      'mpg',
      'mpeg',
      'ts',
      'm2ts',
      'mts',
      'wmv',
      'asf',
      'flv',
      'vob',
      '3gp',
    }.contains(extension);
  }

  bool _requiresImage(String inputPath) =>
      _isVideoFormat(_format) &&
      inputPath.isNotEmpty &&
      !_isVideoInput(inputPath);

  bool get _canConvert {
    if (_running) return false;
    if (_requiresImage(_inputPath) && _imagePath.isEmpty) {
      return false;
    }
    return true;
  }

  Future<String> _defaultOutputDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(documentsDir.path, 'media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir.path;
  }

  String _buildOutputPath(String inputPath, String outputDirectory) {
    final stem = p.basenameWithoutExtension(inputPath);
    return p.join(outputDirectory, '${stem}_converted.${_format.extension}');
  }

  Future<void> _onFormatChanged(_MediaFormat? value) async {
    if (value == null) return;
    setState(() {
      _format = value;
      if (_format == _MediaFormat.opus &&
          (_bitrateController.text.trim().isEmpty ||
              _bitrateController.text.trim() == '192')) {
        _bitrateController.text = '160';
      } else if (_format != _MediaFormat.opus &&
          _bitrateController.text.trim() == '160') {
        _bitrateController.text = '192';
      }
    });
  }

  String _defaultOutputDirectoryDisplayPath(String path) {
    if (p.basename(path) == 'media') return ['Sonarpad', 'media'].join('/');
    return _shortPath(path, parentCount: 2);
  }

  String _shortPath(String path, {required int parentCount}) {
    final normalized = p.normalize(path);
    final parts = p.split(normalized);
    final fileName = parts.isEmpty ? path : parts.last;
    final parents = parts.length <= 1
        ? const <String>[]
        : parts
            .sublist(0, parts.length - 1)
            .reversed
            .take(parentCount)
            .toList()
            .reversed;
    return [...parents, fileName].join('/');
  }

  void _showSnack(String message) {
        showStatusMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.convertMediaTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _inputController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: l10n.convertMediaInput,
                suffixIcon: IconButton(
                  tooltip: l10n.convertMediaBrowse,
                  onPressed: _running ? null : _pickInput,
                  icon: const Icon(Icons.folder_open),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _outputController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: l10n.convertMediaOutput,
                suffixIcon: IconButton(
                  tooltip: l10n.convertMediaBrowse,
                  onPressed: _running ? null : _pickOutput,
                  icon: const Icon(Icons.drive_folder_upload),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_requiresImage(_inputPath)) ...[
              TextField(
                controller: _imageController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: l10n.convertMediaImage,
                  suffixIcon: IconButton(
                    tooltip: l10n.convertMediaBrowse,
                    onPressed: _running ? null : _pickImage,
                    icon: const Icon(Icons.image),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<_MediaFormat>(
              initialValue: _format,
              decoration: InputDecoration(labelText: l10n.convertMediaFormat),
              items: _MediaFormat.values
                  .map(
                    (format) => DropdownMenuItem(
                      value: format,
                      child: Text(format.label),
                    ),
                  )
                  .toList(),
              onChanged: _running ? null : _onFormatChanged,
            ),
            const SizedBox(height: 12),
            if (_usesBitrate(_format))
              TextFormField(
                controller: _bitrateController,
                decoration: InputDecoration(
                  labelText: l10n.convertMediaBitrate,
                ),
                keyboardType: TextInputType.number,
                enabled: !_running,
              )
            else if (_format == _MediaFormat.ogg)
              DropdownButtonFormField<int>(
                initialValue: _oggQuality,
                decoration: InputDecoration(
                  labelText: l10n.convertMediaOggQuality,
                ),
                items: List.generate(11, (index) => index)
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('q$value'),
                      ),
                    )
                    .toList(),
                onChanged: _running
                    ? null
                    : (value) => setState(() => _oggQuality = value ?? 5),
              )
            else if (_format == _MediaFormat.flac)
              DropdownButtonFormField<int>(
                initialValue: _flacCompression,
                decoration: InputDecoration(
                  labelText: l10n.convertMediaFlacCompression,
                ),
                items: List.generate(13, (index) => index)
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value'),
                      ),
                    )
                    .toList(),
                onChanged: _running
                    ? null
                    : (value) => setState(() => _flacCompression = value ?? 5),
              )
            else if (_format == _MediaFormat.wav)
              DropdownButtonFormField<_WavBitDepth>(
                initialValue: _wavBitDepth,
                decoration: InputDecoration(
                  labelText: l10n.convertMediaWavBitDepth,
                ),
                items: _WavBitDepth.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: _running
                    ? null
                    : (value) => setState(
                          () => _wavBitDepth = value ?? _WavBitDepth.pcm16,
                        ),
              ),
            const SizedBox(height: 16),
            Text(_status ?? l10n.convertMediaReady),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _canConvert ? _convert : null,
              icon: const Icon(Icons.sync),
              label: Text(l10n.convertMediaButton),
            ),
          ],
        ),
      ),
    );
  }
}
