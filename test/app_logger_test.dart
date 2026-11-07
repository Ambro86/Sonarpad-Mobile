import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sonarpad_mobile_starter/services/developer_log_service.dart';
import 'package:sonarpad_mobile_starter/utils/app_logger.dart';

class _LogPaths extends PathProviderPlatform {
  _LogPaths(this.directory);
  final Directory directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory.path;
}

void main() {
  late Directory directory;
  late File current;
  late PathProviderPlatform originalPaths;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sonarpad-log-test-');
    current = File('${directory.path}/app_debug_log.txt');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _LogPaths(directory);
  });

  tearDown(() async {
    await AppLogger.readLogs(); // Drain pending operations before restoring paths.
    PathProviderPlatform.instance = originalPaths;
    await directory.delete(recursive: true);
  });

  test(
    'rotation preserves checkout start and ZIP contains the whole ordered snapshot',
    () async {
      final before =
          '${'[TravelCheckout] before-selection PayPal — città\n'.padRight(8 * 1024 * 1024 + 1, 'x')}\n'
          '[TravelCheckout] after-payment-click\n';
      await current.writeAsString(before);
      final write = AppLogger.log('[TravelCheckout] browser-revealed');
      final reading = AppLogger.readLogs();
      final later = AppLogger.log('[TravelCheckout] after-report-snapshot');
      final snapshot = await reading;
      await Future.wait([write, later]);

      expect(await File('${current.path}.1').readAsString(), before);
      expect(snapshot, startsWith(before));
      expect(snapshot, contains('log_rotated'));
      expect(snapshot, contains('oldest_discarded=false'));
      expect(snapshot, contains('browser-revealed'));
      expect(snapshot, isNot(contains('after-report-snapshot')));
      expect(await AppLogger.readLogs(), contains('after-report-snapshot'));

      final sent = await http.runWithClient(
        () => DeveloperLogService.sendReport(
          log: snapshot,
          report: 'checkout test',
        ),
        () => MockClient((request) async {
          final payload = jsonDecode(request.body) as Map;
          final zip = ZipDecoder().decodeBytes(
            base64Decode(payload['diagnostics_zip_base64'] as String),
          );
          expect(zip.files.single.name, 'sonarpad-log.txt');
          expect(utf8.decode(zip.files.single.content as List<int>), snapshot);
          return http.Response('{"ok":true,"attachment_received":true}', 200);
        }),
      );
      expect(sent, isTrue);
    },
  );

  test(
    'retained segments stay chronological and only the oldest expires at the limit',
    () async {
      await File('${current.path}.3').writeAsString('expired-entry\n');
      await File('${current.path}.2').writeAsString('older-entry\n');
      await File('${current.path}.1').writeAsString('recent-entry\n');
      final previous = 'current-entry\n'.padRight(8 * 1024 * 1024 + 1, 'x');
      await current.writeAsString(previous);

      await AppLogger.log('new-entry');
      expect(await File('${current.path}.3').readAsString(), 'older-entry\n');
      expect(await File('${current.path}.2').readAsString(), 'recent-entry\n');
      expect(await File('${current.path}.1').readAsString(), previous);
      final logs = await AppLogger.readLogs();
      expect(logs, startsWith('older-entry\nrecent-entry\ncurrent-entry\n'));
      expect(logs, isNot(contains('expired-entry')));
      expect(logs, contains('oldest_discarded=true'));
      expect(logs.indexOf('log_rotated'), lessThan(logs.indexOf('new-entry')));
      expect(await File('${current.path}.4').exists(), isFalse);

      await AppLogger.clearLogs();
      expect(await directory.list().toList(), isEmpty);
      expect(await AppLogger.readLogs(), 'Nessun log trovato.');
    },
  );

  test(
    'explicit clear is ordered between writes and deletes archived history too',
    () async {
      await File('${current.path}.1').writeAsString('archived-entry\n');
      final first = AppLogger.log('before-clear');
      final clearing = AppLogger.clearLogs();
      final second = AppLogger.log('after-clear');
      final logs = await AppLogger.readLogs();
      await Future.wait([first, clearing, second]);
      expect(logs, contains('after-clear'));
      expect(logs, isNot(contains('before-clear')));
      expect(logs, isNot(contains('archived-entry')));
      expect(await File('${current.path}.1').exists(), isFalse);
    },
  );
}
