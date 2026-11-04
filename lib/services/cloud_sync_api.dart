import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/app_logger.dart';

enum CloudSyncAction {
  create,
  join,
  code,
  state,
  sync,
  devices,
  revoke,
  disconnect,
  delete,
}

class CloudSyncApiException implements Exception {
  final int? status;
  final String code;
  const CloudSyncApiException(this.code, {this.status});

  @override
  String toString() => 'CloudSyncApiException($code, status=$status)';
}

/// The only HTTP entry point for cloud sync. Diagnostic metadata is allowlisted:
/// never log credentials, codes, collection data or raw transport exceptions.
class CloudSyncApi {
  static final endpoint = Uri.parse('https://sonarpad.com/synk/index.php');
  final http.Client _client;
  final Future<void> Function(String) _log;
  final Duration timeout;

  CloudSyncApi({
    http.Client? client,
    Future<void> Function(String)? logger,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _log = logger ?? AppLogger.log;

  Future<Map<String, dynamic>> request(
    CloudSyncAction action,
    String token,
    Map<String, dynamic> body,
  ) async {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
      throw const CloudSyncApiException('invalid_credentials');
    }
    final encoded = jsonEncode(body);
    if (utf8.encode(encoded).length > 2 * 1024 * 1024) {
      throw const CloudSyncApiException('request_too_large');
    }
    final watch = Stopwatch()..start();
    await _safeLog('[CloudSync] action=${action.name} started');
    int? status;
    String requestId = '-';
    try {
      final request =
          http.Request(
              'POST',
              endpoint.replace(queryParameters: {'action': action.name}),
            )
            ..followRedirects = false
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            })
            ..body = encoded;
      final response = await (() async {
        final streamed = await _client.send(request);
        status = streamed.statusCode;
        final id = streamed.headers['x-request-id'] ?? '';
        if (RegExp(r'^[a-f0-9]{16}$').hasMatch(id)) requestId = id;
        final bytes = <int>[];
        await for (final chunk in streamed.stream) {
          if (bytes.length + chunk.length > 5 * 1024 * 1024) {
            throw const CloudSyncApiException('response_too_large');
          }
          bytes.addAll(chunk);
        }
        return utf8.decode(bytes);
      })().timeout(timeout);
      final decoded = jsonDecode(response);
      if (decoded is! Map<String, dynamic>) {
        throw const CloudSyncApiException('invalid_response');
      }
      if (status != 200) {
        const errors = {
          'unauthorized',
          'invalid_or_expired_code',
          'invalid_code',
          'device_limit',
          'rate_limited',
          'sequence_conflict',
          'sequence_reused',
          'storage_limit',
          'request_too_large',
          'service_unavailable',
          'invalid_state',
          'invalid_collection',
          'invalid_item',
        };
        final code = decoded['error'];
        throw CloudSyncApiException(
          errors.contains(code) ? code as String : 'http_error',
          status: status,
        );
      }
      await _safeLog(
        '[CloudSync] action=${action.name} status=$status '
        'duration_ms=${watch.elapsedMilliseconds} request_id=$requestId completed',
      );
      return decoded;
    } catch (error) {
      final safe = error is CloudSyncApiException
          ? error
          : CloudSyncApiException(
              error is TimeoutException
                  ? 'timeout'
                  : error is FormatException
                  ? 'invalid_response'
                  : 'network_error',
              status: status,
            );
      await _safeLog(
        '[CloudSync] action=${action.name} status=${status ?? 0} '
        'duration_ms=${watch.elapsedMilliseconds} request_id=$requestId error=${safe.code}',
      );
      throw safe;
    }
  }

  Future<void> _safeLog(String line) async {
    try {
      await _log(line);
    } catch (_) {
      /* Logging must not block sync. */
    }
  }

  void close() => _client.close();
}
