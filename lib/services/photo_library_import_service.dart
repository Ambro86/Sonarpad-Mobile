import 'dart:io';

import 'package:flutter/services.dart';

class PhotoLibraryImportService {
  static const MethodChannel _channel = MethodChannel(
    'sonarpad/photo_library_import',
  );

  const PhotoLibraryImportService();

  bool get isSupported => Platform.isIOS || Platform.isAndroid;

  Future<List<String>> pickVideos({bool allowMultiple = true}) async {
    if (!isSupported) return const <String>[];
    final paths = await _channel.invokeListMethod<String>(
      'pickVideos',
      <String, dynamic>{'allowMultiple': allowMultiple},
    );
    return (paths ?? const <String>[])
        .where((path) => path.trim().isNotEmpty)
        .toList(growable: false);
  }
}
