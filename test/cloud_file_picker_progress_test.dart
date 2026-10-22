import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_lookup.dart';
import 'package:sonarpad_mobile_starter/services/cloud_file_picker_service.dart';

const _commands = MethodChannel('sonarpad/cloud_file_picker');
const _eventName = 'sonarpad/cloud_file_picker_progress';
const _eventChannel = MethodChannel(_eventName);

class _Session {
  final response = Completer<List<dynamic>?>();
  late Future<FilePickerResult?> result;
  late BuildContext context;
  String? requestId;
  int cancels = 0;

  Future<void> start(WidgetTester tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_eventChannel, (_) async => null);
    messenger.setMockMethodCallHandler(_commands, (call) async {
      if (call.method == 'pickFiles') {
        requestId = (call.arguments as Map)['requestId'] as String;
        return response.future;
      }
      if (call.method == 'cancel') {
        cancels++;
        if (!response.isCompleted) response.complete(null);
        return null;
      }
      throw StateError('Unexpected picker method: ${call.method}');
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (ctx) {
        context = ctx;
        return const Scaffold(body: Text('Host'));
      }),
    ));
    result = CloudFilePicker.pickFiles(context: context);
    await tester.pump();
    expect(requestId, isNotNull);
    addTearDown(() {
      if (!response.isCompleted) response.complete(null);
    });
  }

  Future<void> emit(WidgetTester tester, String stage,
      {int copied = 0, int total = -1, String? eventRequest}) async {
    final delivered = Completer<void>();
    // Inject the platform event, rather than invoking the UI callback directly.
    // ignore: deprecated_member_use
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _eventName,
      const StandardMethodCodec().encodeSuccessEnvelope({
        'stage': stage,
        'copied': copied,
        'total': total,
        'requestId': eventRequest ?? requestId,
      }),
      (_) => delivered.complete(),
    );
    // Deliver the platform reply's microtasks before awaiting its completion.
    await tester.pump();
    await delivered.future;
    await tester.pump();
  }

  Future<FilePickerResult?> finish(WidgetTester tester) async {
    if (!response.isCompleted) {
      response.complete([
        {'path': '/fixture/cached.mp4', 'name': 'cached.mp4', 'size': 100},
      ]);
    }
    // The platform response and route disposal cross the real/FakeAsync
    // boundary. Pump animations while waiting for the operation itself;
    // pumpAndSettle cannot finish while a cancelling spinner is still active.
    final selected = await tester.runAsync(() async {
      var completed = false;
      final completion = result.whenComplete(() => completed = true);
      final elapsed = Stopwatch()..start();
      while (!completed) {
        if (elapsed.elapsed > const Duration(seconds: 5)) {
          throw StateError('Timed out waiting for the picker to finish');
        }
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      return completion;
    });
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    return selected;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => CloudFilePicker.debugUseNativePicker = true);
  tearDown(() {
    CloudFilePicker.debugUseNativePicker = null;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_commands, null);
    messenger.setMockMethodCallHandler(_eventChannel, null);
  });

  testWidgets('system picker waiting is not represented as download progress', (tester) async {
    final session = _Session();
    await session.start(tester);
    for (final stage in ['picker_presented', 'selection_received', 'picker_dismissed']) {
      await session.emit(tester, stage);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AlertDialog), findsNothing);
    }
    final selected = await session.finish(tester);
    expect(selected!.files.single.name, 'cached.mp4');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('fast completed copies never open a late 100 percent dialog', (tester) async {
    final session = _Session();
    await session.start(tester);
    await session.emit(tester, 'preparing');
    await session.emit(tester, 'copying', copied: 100, total: 100);
    await session.finish(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('unknown preparation and real copy progress remain distinct and cancellable', (tester) async {
    // testWidgets owns the semantics handle and disposes it before its checks.
    final session = _Session();
    await session.start(tester);
    await session.emit(tester, 'copying', copied: 90, total: 100, eventRequest: 'obsolete');
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsNothing);
    await session.emit(tester, 'preparing');
    await tester.pump(const Duration(milliseconds: 300));
    // Complete the dialog entrance before inspecting semantics or tapping.
    // Do not pumpAndSettle while the indeterminate indicator is animating.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, isNull);
    await session.emit(tester, 'copying', copied: 25, total: 100);
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.25);
    expect(find.bySemanticsLabel(RegExp('Copia del file in Sonarpad.*25%')), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Annulla'));
    await tester.pump();
    final selected = await session.finish(tester);
    expect(session.cancels, 1);
    expect(selected, isNull);
  });

  testWidgets('waiting for first bytes stays indeterminate then reports real percentages', (tester) async {
    final session = _Session();
    await session.start(tester);
    await session.emit(tester, 'copying', copied: 0, total: 100);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, isNull);
    for (final bytes in [25, 50, 75, 100]) {
      await session.emit(tester, 'copying', copied: bytes, total: 100);
      expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, bytes / 100);
      expect(find.bySemanticsLabel(RegExp('Copia del file in Sonarpad.*$bytes%')), findsOneWidget);
    }
    await session.finish(tester);
  });

  testWidgets('finishing a copy closes only its own modal route', (tester) async {
    final session = _Session();
    await session.start(tester);
    await session.emit(tester, 'preparing');
    await tester.pump(const Duration(milliseconds: 300));
    // Complete the dialog entrance before inspecting semantics or tapping.
    // Do not pumpAndSettle while the indeterminate indicator is animating.
    await tester.pump(const Duration(milliseconds: 300));
    final other = showDialog<void>(
      context: session.context,
      builder: (_) => const AlertDialog(content: Text('Other route')),
    );
    await tester.pump();
    await session.finish(tester);
    expect(find.text('Other route'), findsOneWidget);
    Navigator.of(session.context, rootNavigator: true).pop();
    await tester.pumpAndSettle();
    await other;
  });

  test('copy phase label matches the ARB for every language and regional variant', () {
    final arbs = Directory('lib/l10n').listSync().whereType<File>()
        .where((file) => file.path.endsWith('.arb')).toList();
    expect(arbs, isNotEmpty);
    for (final file in arbs) {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final basename = file.path.replaceAll('\\', '/').split('/').last;
      final locale = basename.substring(4, basename.length - 4);
      final expected = data['cloudFilePickerCopying'];
      expect(expected, isA<String>(), reason: basename);
      expect((expected as String).trim(), isNotEmpty, reason: basename);
      expect(lookupSupportedAppLocalizations(locale).cloudFilePickerCopying,
          expected, reason: basename);
    }
  });
}
