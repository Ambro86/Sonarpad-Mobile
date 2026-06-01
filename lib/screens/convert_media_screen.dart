import 'dart:io';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';

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

  _MediaFormat _format = _MediaFormat.mp3;
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
    final path = result == null || result.files.isEmpty
        ? null
        : result.files.first.path;
    if (path == null || path.isEmpty) return;

    setState(() {
      _inputController.text = path;
      if (_outputController.text.trim().isEmpty) {
        _outputController.text = _defaultOutputPath(path);
      }
    });
  }

  Future<void> _pickOutput() async {
    final l10n = AppLocalizations.of(context);
    final fileName = _inputController.text.trim().isEmpty
        ? 'converted.${_format.extension}'
        : p.basename(_defaultOutputPath(_inputController.text.trim()));
    final path = await FilePicker.saveFile(
      dialogTitle: l10n.convertMediaOutput,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [_format.extension],
    );
    if (path == null || path.isEmpty) return;
    setState(() => _outputController.text = path);
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _imageExtensions,
    );
    final path = result == null || result.files.isEmpty
        ? null
        : result.files.first.path;
    if (path == null || path.isEmpty) return;
    setState(() => _imageController.text = path);
  }

  Future<void> _convert() async {
    final l10n = AppLocalizations.of(context);
    final input = _inputController.text.trim();
    final output = _outputController.text.trim();

    if (input.isEmpty) {
      _showSnack(l10n.convertMediaNoInput);
      return;
    }
    if (output.isEmpty) {
      _showSnack(l10n.convertMediaNoOutput);
      return;
    }
    if (p.equals(input, output)) {
      _showSnack(l10n.convertMediaSamePath);
      return;
    }
    if (!await File(input).exists()) {
      _showSnack(l10n.fileInaccessible(p.basename(input)));
      return;
    }
    if (_requiresImage(input)) {
      final image = _imageController.text.trim();
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
      final arguments = await _buildArguments(input, output, bitrate ?? 192);
      final session = await FFmpegKit.executeWithArguments(arguments);
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getAllLogsAsString() ?? '';
        throw logs.trim().isEmpty ? returnCode?.getValue() ?? 'FFmpeg' : logs;
      }

      if (!mounted) return;
      setState(() => _status = l10n.convertMediaDone);
      _showSnack(l10n.convertMediaDone);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = l10n.convertMediaReady);
      _showSnack(l10n.convertMediaFailed(error));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<List<String>> _buildArguments(
    String input,
    String output,
    int bitrate,
  ) async {
    final audioInputToVideo = _isVideoFormat(_format) && !_isVideoInput(input);
    final coverPath = audioInputToVideo ? _imageController.text.trim() : null;

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
      _MediaFormat.wav || _MediaFormat.aiff => ['-c:a', 'pcm_s16le'],
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
    final extension = p.extension(inputPath).toLowerCase().replaceFirst('.', '');
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
      _isVideoFormat(_format) && inputPath.isNotEmpty && !_isVideoInput(inputPath);

  bool get _canConvert {
    if (_running) return false;
    if (_requiresImage(_inputController.text.trim()) &&
        _imageController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  String _defaultOutputPath(String inputPath) {
    final dir = p.dirname(inputPath);
    final stem = p.basenameWithoutExtension(inputPath);
    return p.join(dir, '${stem}_converted.${_format.extension}');
  }

  void _onFormatChanged(_MediaFormat? value) {
    if (value == null) return;
    final oldSuggested = _inputController.text.trim().isEmpty
        ? ''
        : _defaultOutputPath(_inputController.text.trim());
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
      if (_inputController.text.trim().isNotEmpty &&
          (_outputController.text.trim().isEmpty ||
              _outputController.text.trim() == oldSuggested)) {
        _outputController.text = _defaultOutputPath(_inputController.text.trim());
      }
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                  icon: const Icon(Icons.save_as),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_requiresImage(_inputController.text.trim())) ...[
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
                onChanged:
                    _running ? null : (value) => setState(() => _oggQuality = value ?? 5),
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
