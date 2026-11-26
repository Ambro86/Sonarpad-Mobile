import 'dart:io';
import 'dart:math';

import 'package:uuid/uuid.dart';

/// Exposes only the selected document on the interface connected to the receiver.
class ChromecastLocalFile {
  ChromecastLocalFile._(this._server, this.url);

  final HttpServer _server;
  final Uri url;

  static Future<ChromecastLocalFile> open(
    File file,
    String mime,
    InternetAddress address,
  ) async {
    final size = await file.length();
    final server = await HttpServer.bind(address, 0);
    final url = Uri(
      scheme: 'http',
      host: address.address,
      port: server.port,
      path: '/${const Uuid().v4()}',
    );
    server.listen((request) async {
      final response = request.response;
      try {
        if (request.uri.path != url.path) {
          response.statusCode = HttpStatus.notFound;
          return;
        }
        response.headers
          ..set('Access-Control-Allow-Origin', '*')
          ..set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
          ..set('Access-Control-Allow-Headers', 'Range')
          ..set(
            'Access-Control-Expose-Headers',
            'Content-Range, Accept-Ranges, Content-Length',
          );
        if (request.method == 'OPTIONS') {
          response.statusCode = HttpStatus.noContent;
          return;
        }
        if (request.method != 'GET' && request.method != 'HEAD') {
          response.statusCode = HttpStatus.methodNotAllowed;
          return;
        }
        response.headers
          ..set(HttpHeaders.contentTypeHeader, mime)
          ..set(HttpHeaders.acceptRangesHeader, 'bytes');
        var start = 0, end = size;
        final range = request.headers.value(HttpHeaders.rangeHeader);
        if (range != null) {
          final bounds = _range(range, size);
          if (bounds == null) {
            response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
            response.headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes */$size',
            );
            return;
          }
          (start, end) = bounds;
          response.statusCode = HttpStatus.partialContent;
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-${end - 1}/$size',
          );
        }
        response.contentLength = end - start;
        if (request.method == 'GET' && end > start) {
          await response.addStream(file.openRead(start, end));
        }
      } on IOException {
        // A receiver can abandon a request during a seek or disconnect.
      } finally {
        try {
          await response.close();
        } on IOException {
          // The receiver has already closed its end.
        }
      }
    });
    return ChromecastLocalFile._(server, url);
  }

  // Return an exclusive end so the interval can go directly to File.openRead.
  static (int, int)? _range(String header, int size) {
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.trim());
    if (match == null || size == 0) return null;
    final first = match[1]!, last = match[2]!;
    if (first.isEmpty) {
      final count = int.tryParse(last);
      return count == null || count <= 0 ? null : (max(0, size - count), size);
    }
    final start = int.tryParse(first);
    final end = last.isEmpty ? size - 1 : int.tryParse(last);
    if (start == null || end == null || start >= size || start > end) {
      return null;
    }
    return (start, min(size - 1, end) + 1);
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}
