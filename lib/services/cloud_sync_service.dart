import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_sync_api.dart';
import 'cloud_sync_state.dart';
import 'cloud_sync_collections.dart';
import '../utils/app_logger.dart';

class CloudSyncService {
  static const _key = 'sonarpad_cloud_sync_v1';
  static const _tokenKey = 'sonarpad_cloud_sync_token';
  static bool _busy = false;
  static final changes = ValueNotifier<int>(0);
  static bool automaticPending = false;
  static bool automaticFailed = false;
  static bool get busy => _busy;
  bool _checking = false;
  bool _started = false;
  int _failures = 0;
  DateTime? _nextAttempt;
  final DateTime Function() clock;
  final CloudSyncApi api;
  final CloudSyncCollections collections;
  final FlutterSecureStorage credentials;

  CloudSyncService({
    CloudSyncApi? api,
    CloudSyncCollections? collections,
    FlutterSecureStorage? credentials,
    DateTime Function()? clock,
  }) : api = api ?? CloudSyncApi(),
       collections = collections ?? CloudSyncCollections(),
       credentials = credentials ?? const FlutterSecureStorage(),
       clock = clock ?? DateTime.now;

  void wake() => _started = false;

  // Compare objects independently of JSON map key order. Collection order is
  // meaningful; preference order is not.
  String _fingerprint(CloudState state) {
    Object? canonical(Object? value) {
      if (value is Map) {
        final keys = value.keys.cast<String>().toList()..sort();
        return {for (final key in keys) key: canonical(value[key])};
      }
      if (value is List) return value.map(canonical).toList();
      return value;
    }

    final copy = {...state};
    if (copy.containsKey('preferences')) {
      copy['preferences'] = [...copy['preferences']!]
        ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    }
    return jsonEncode(canonical(copy));
  }

  /// Called only while the app is active. Uses the same journal, credentials,
  /// merge and lock as manual sync. Errors are logged, never shown as dialogs.
  Future<void> automaticTick() async {
    if (_checking || _busy) return;
    // Also back off if reading local storage failed; foreground events cannot
    // turn a persistent failure into a stream of retries/log entries.
    if (_failures != 0 &&
        _nextAttempt != null &&
        clock().isBefore(_nextAttempt!)) {
      return;
    }
    _checking = true;
    try {
      final meta = await metadata();
      if (meta['group_id'] == null) {
        _started = false;
        _nextAttempt = null;
        _failures = 0;
        automaticPending = automaticFailed = false;
        return;
      }
      if (meta['sync_preferences'] == false &&
          meta['sync_collections'] == false) {
        return;
      }
      final local = _selected(await collections.read(), meta);
      final baseline = _selected(
        collections.project(parseCloudState(meta['baseline'] ?? {})),
        meta,
      );
      final dirty =
          meta['pending'] != null ||
          _fingerprint(local) != _fingerprint(baseline);
      if (automaticPending != dirty) {
        automaticPending = dirty;
        changes.value++;
      }
      final now = clock();
      if (_nextAttempt != null && now.isBefore(_nextAttempt!)) return;
      final last = DateTime.tryParse(meta['last_sync'] as String? ?? '');
      if (_started &&
          !dirty &&
          last != null &&
          now.difference(last).inSeconds < 180) {
        return;
      }
      if (_busy) return;
      _started = true;
      _nextAttempt = now.add(const Duration(seconds: 30));
      await synchronize();
      _failures = 0;
      automaticFailed = false;
    } catch (error) {
      // Manual sync may have acquired the lock while collections were read.
      if (error is CloudSyncApiException && error.code == 'busy') return;
      automaticFailed = true;
      _failures = min(_failures + 1, 5);
      _nextAttempt = clock().add(
        Duration(seconds: min(30 << (_failures - 1), 300)),
      );
      await AppLogger.log(
        '[CloudSync] automatic_retry type=${error.runtimeType} delay_seconds=${min(30 << (_failures - 1), 300)}',
      );
    } finally {
      _checking = false;
      changes.value++;
    }
  }

  Future<Map<String, dynamic>> metadata() async {
    final prefs = await SharedPreferences.getInstance();
    return Map<String, dynamic>.from(
      jsonDecode(prefs.getString(_key) ?? '{}') as Map,
    );
  }

  Future<void> _save(Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key, jsonEncode(value))) {
      throw const CloudSyncApiException('storage_error');
    }
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_busy) throw const CloudSyncApiException('busy');
    _busy = true;
    changes.value++;
    try {
      return await action();
    } catch (error) {
      await AppLogger.log(
        '[CloudSync] operation_failed type=${error.runtimeType}',
      );
      rethrow;
    } finally {
      _busy = false;
      changes.value++;
    }
  }

  Future<String> _token({bool create = false}) async {
    var value = await credentials.read(key: _tokenKey);
    if (value == null && create) {
      final random = Random.secure();
      value = List.generate(
        32,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await credentials.write(key: _tokenKey, value: value);
    }
    if (value == null) throw const CloudSyncApiException('unauthorized');
    return value;
  }

  Future<void> connect({String? code}) => _exclusive(() async {
    final meta = await metadata();
    if (meta['group_id'] != null) {
      await _sync(meta);
      return;
    }
    final token = await _token(create: true);
    final result = await api.request(
      code == null ? CloudSyncAction.create : CloudSyncAction.join,
      token,
      {
        'device_name': 'Sonarpad ${Platform.operatingSystem}',
        if (code != null) 'code': code.replaceAll(RegExp(r'\s'), ''),
      },
    );
    if (result['group_id'] is! String || result['sequence'] is! int) {
      throw const CloudSyncApiException('invalid_response');
    }
    meta.addAll({
      'group_id': result['group_id'],
      'device_id': result['device_id'],
      'sequence': result['sequence'],
      'baseline': <String, dynamic>{},
    });
    await _save(meta);
    await _sync(meta);
  });

  Future<void> synchronize() => _exclusive(() async => _sync(await metadata()));

  Future<void> setScope({required bool preferences, required bool enabled}) =>
      _exclusive(() async {
        final meta = await metadata();
        if (meta['pending'] != null) {
          throw const CloudSyncApiException('pending_sync');
        }
        meta[preferences ? 'sync_preferences' : 'sync_collections'] = enabled;
        await _save(meta);
      });

  CloudState _selected(CloudState state, Map<String, dynamic> meta) => {
    for (final entry in state.entries)
      if (meta[entry.key == 'preferences'
              ? 'sync_preferences'
              : 'sync_collections'] !=
          false)
        entry.key: entry.value,
  };

  Future<void> _sync(Map<String, dynamic> meta) async {
    if (meta['group_id'] == null) {
      throw const CloudSyncApiException('unauthorized');
    }
    final token = await _token();
    var pending = meta['pending'] as Map?;
    if (pending == null) {
      final local = _selected(await collections.read(), meta);
      if (local.isEmpty) throw const CloudSyncApiException('empty_scope');
      pending = {
        'schema_version': 1,
        'sequence': (meta['sequence'] as int? ?? 0) + 1,
        'baseline': _selected(parseCloudState(meta['baseline'] ?? {}), meta),
        'state': local,
      };
      meta['pending'] = pending;
      await _save(meta);
    }
    final response = meta['response'] is Map
        ? Map<String, dynamic>.from(meta['response'] as Map)
        : await api.request(
            CloudSyncAction.sync,
            token,
            Map<String, dynamic>.from(pending),
          );
    if (response['group_id'] != meta['group_id'] ||
        response['sequence'] != pending['sequence']) {
      throw const CloudSyncApiException('invalid_response');
    }
    final sent = parseCloudState(pending['state']);
    final projected = collections.project(parseCloudState(response['state']));
    final remote = <String, List<Map<String, dynamic>>>{
      for (final key in sent.keys) key: projected[key] ?? [],
    };
    meta['response'] = response;
    await _save(meta);
    // Capture edits made during the request. Journal makes partial local writes
    // recoverable: on retry the same response and original snapshot are used.
    final allCurrent = await collections.read();
    final current = <String, List<Map<String, dynamic>>>{
      for (final key in sent.keys) key: allCurrent[key] ?? [],
    };
    final applied = mergeCloudState(
      remote,
      parseCloudState(pending['state']),
      current,
    );
    await collections.write(applied);
    meta.addAll({
      'sequence': response['sequence'],
      'baseline': {...parseCloudState(meta['baseline'] ?? {}), ...remote},
      'last_sync': clock().toUtc().toIso8601String(),
    });
    meta.remove('pending');
    meta.remove('response');
    await _save(meta);
    automaticPending = _fingerprint(applied) != _fingerprint(remote);
    automaticFailed = false;
  }

  Future<String> invitation() => _exclusive(() async {
    final result = await api.request(CloudSyncAction.code, await _token(), {});
    final code = result['code'];
    if (code is! String || !RegExp(r'^\d{8}$').hasMatch(code)) {
      throw const CloudSyncApiException('invalid_response');
    }
    return code;
  });

  Future<void> disconnect() => _exclusive(() async {
    try {
      await api.request(CloudSyncAction.disconnect, await _token(), {});
    } on CloudSyncApiException catch (e) {
      if (e.code != 'unauthorized') rethrow;
    }
    // Keep all collections locally; only remove sync credentials/checkpoints.
    await credentials.delete(key: _tokenKey);
    await _save({});
    automaticPending = automaticFailed = false;
  });
}
