import 'dart:async';
import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/models/calendar_event.dart';
import 'package:sonarpad_mobile_starter/services/calendar/calendar_service.dart';
import 'package:sonarpad_mobile_starter/widgets/calendar_reminder_dialog.dart';

const _calendarChannel = MethodChannel(
  'plugins.builttoroam.com/device_calendar',
);

Future<void> _openReminder(
  WidgetTester tester,
  void Function(CalendarEvent? event) onSaved,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              final event = await showDialog<CalendarEvent>(
                context: context,
                builder: (_) =>
                    CalendarReminderDialog(date: DateTime(2027, 1, 24)),
              );
              onSaved(event);
            },
            child: const Text('Apri promemoria'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Apri promemoria'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_calendarChannel, null);
  });

  test('old reminders remain untimed and explicit midnight survives JSON', () {
    final legacy = CalendarEvent.fromJson({
      'id': 'old',
      'date': '2027-01-24T00:00:00.000',
      'text': 'Promemoria precedente',
    });
    expect(legacy.hasTime, isFalse);
    expect(legacy.deviceCalendarId, isNull);
    expect(legacy.deviceEventId, isNull);

    final midnight = CalendarEvent(
      id: 'midnight',
      date: DateTime(2027, 1, 24),
      text: 'Mezzanotte',
      hasTime: true,
    );
    final restored = CalendarEvent.fromJson(midnight.toJson());
    expect(restored.hasTime, isTrue);
    expect(restored.date.hour, 0);
    expect(restored.date.minute, 0);
  });

  test(
    'timed reminders persist synchronize an alarm and remove its native event',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_calendarChannel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'hasPermissions' => true,
              'retrieveCalendars' => jsonEncode([
                {
                  'id': 'test-calendar',
                  'name': 'Calendario di prova',
                  'isDefault': true,
                  'isReadOnly': false,
                },
              ]),
              'createOrUpdateEvent' => 'native-event',
              'deleteEvent' => true,
              _ => throw StateError('Unexpected calendar call: ${call.method}'),
            };
          });
      final service = CalendarService();
      final date = DateTime(2027, 1, 24, 14, 5);
      await service.addEvent(
        CalendarEvent(id: 'timed', date: date, text: 'Visita', hasTime: true),
        deviceCalendarDescription: 'Promemoria',
      );
      final restored = (await service.getEventsForDate(
        DateTime(2027, 1, 24),
      )).single;
      expect(restored.date, date);
      expect(restored.hasTime, isTrue);
      expect(restored.deviceCalendarId, 'test-calendar');
      expect(restored.deviceEventId, 'native-event');
      final native = Map<Object?, Object?>.from(
        calls
                .singleWhere((call) => call.method == 'createOrUpdateEvent')
                .arguments
            as Map,
      );
      expect(native['eventStartDate'], date.millisecondsSinceEpoch);
      expect(
        native['eventEndDate'],
        date.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      );
      expect(native['eventAllDay'], isFalse);
      expect(native['reminders'], [
        {'minutes': 0},
      ]);

      await service.removeEvent(restored.id);
      expect(await service.getEvents(), isEmpty);
      expect(calls.last.method, 'deleteEvent');
      expect(calls.last.arguments, {
        'calendarId': 'test-calendar',
        'eventId': 'native-event',
      });

      calls.clear();
      await service.addEvent(
        CalendarEvent(
          id: 'untimed',
          date: DateTime(2027, 1, 24),
          text: 'Giornata',
        ),
        deviceCalendarDescription: 'Promemoria',
      );
      final allDay = Map<Object?, Object?>.from(
        calls
                .singleWhere((call) => call.method == 'createOrUpdateEvent')
                .arguments
            as Map,
      );
      expect(allDay['eventAllDay'], isTrue);
      expect(allDay['reminders'], isNull);
      expect((await service.getEvents()).single.hasTime, isFalse);
      expect((await service.getEvents()).single.deviceEventId, isNull);
    },
  );

  test(
    'denied calendar access still preserves the local reminder and its time',
    () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_calendarChannel, (call) async {
            calls.add(call.method);
            return false;
          });
      final service = CalendarService();
      await service.addEvent(
        CalendarEvent(
          id: 'local-only',
          date: DateTime(2027, 1, 24, 23, 59),
          text: 'Ricorda',
          hasTime: true,
        ),
        deviceCalendarDescription: 'Promemoria',
      );
      final stored = (await service.getEvents()).single;
      expect(stored.hasTime, isTrue);
      expect(stored.date.hour, 23);
      expect(stored.date.minute, 59);
      expect(stored.deviceEventId, isNull);
      expect(calls, ['hasPermissions', 'requestPermissions']);
    },
  );

  test(
    'concurrent saves across service instances preserve both native event IDs',
    () async {
      final pending = <String, Completer<String>>{};
      final bothPending = Completer<void>();
      final deleted = <Object?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_calendarChannel, (call) async {
            if (call.method == 'hasPermissions') return true;
            if (call.method == 'retrieveCalendars') {
              return jsonEncode([
                {'id': 'test-calendar', 'isDefault': true, 'isReadOnly': false},
              ]);
            }
            if (call.method == 'createOrUpdateEvent') {
              final title = (call.arguments as Map)['eventTitle'] as String;
              final response = Completer<String>();
              pending[title] = response;
              if (pending.length == 2) bothPending.complete();
              return response.future;
            }
            if (call.method == 'deleteEvent') {
              deleted.add(call.arguments);
              return true;
            }
            throw StateError('Unexpected calendar call: ${call.method}');
          });
      final firstService = CalendarService();
      final secondService = CalendarService();
      final firstSave = firstService.addEvent(
        CalendarEvent(
          id: 'first',
          date: DateTime(2027, 1, 24, 9),
          text: 'Primo',
          hasTime: true,
        ),
        deviceCalendarDescription: 'Promemoria',
      );
      final secondSave = secondService.addEvent(
        CalendarEvent(
          id: 'second',
          date: DateTime(2027, 1, 24, 10),
          text: 'Secondo',
          hasTime: true,
        ),
        deviceCalendarDescription: 'Promemoria',
      );
      await bothPending.future;
      expect(await firstService.getEvents(), hasLength(2));

      // Release both native writes together, after the local reminders exist.
      pending['Primo']!.complete('native-first');
      pending['Secondo']!.complete('native-second');
      await Future.wait([firstSave, secondSave]);
      final stored = {
        for (final event in await firstService.getEvents()) event.id: event,
      };
      expect(stored['first']?.deviceEventId, 'native-first');
      expect(stored['second']?.deviceEventId, 'native-second');

      await Future.wait([
        firstService.removeEvent('first'),
        secondService.removeEvent('second'),
      ]);
      expect(await firstService.getEvents(), isEmpty);
      expect(
        deleted,
        unorderedEquals([
          {'calendarId': 'test-calendar', 'eventId': 'native-first'},
          {'calendarId': 'test-calendar', 'eventId': 'native-second'},
        ]),
      );
    },
  );

  test(
    'removing a reminder during native save removes the late event too',
    () async {
      final nativeStarted = Completer<void>();
      final nativeResponse = Completer<String>();
      final deleted = <Object?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_calendarChannel, (call) async {
            if (call.method == 'hasPermissions') return true;
            if (call.method == 'retrieveCalendars') {
              return jsonEncode([
                {'id': 'test-calendar', 'isDefault': true, 'isReadOnly': false},
              ]);
            }
            if (call.method == 'createOrUpdateEvent') {
              nativeStarted.complete();
              return nativeResponse.future;
            }
            if (call.method == 'deleteEvent') {
              deleted.add(call.arguments);
              return true;
            }
            throw StateError('Unexpected calendar call: ${call.method}');
          });
      final saving = CalendarService().addEvent(
        CalendarEvent(
          id: 'removed-while-saving',
          date: DateTime(2027, 1, 24, 14),
          text: 'Da rimuovere',
          hasTime: true,
        ),
        deviceCalendarDescription: 'Promemoria',
      );
      await nativeStarted.future;
      final otherService = CalendarService();
      await otherService.removeEvent('removed-while-saving');
      expect(await otherService.getEvents(), isEmpty);
      expect(deleted, isEmpty);

      nativeResponse.complete('late-native-event');
      await saving;
      expect(await otherService.getEvents(), isEmpty);
      expect(deleted, [
        {'calendarId': 'test-calendar', 'eventId': 'late-native-event'},
      ]);
    },
  );

  testWidgets(
    'hour and minute sliders step by one and preserve text and semantics nodes',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        CalendarEvent? saved;
        await _openReminder(tester, (event) => saved = event);
        final text = find.byKey(const ValueKey('calendar_reminder_text'));
        final toggle = find.byKey(const ValueKey('calendar_reminder_has_time'));
        final hours = find.byKey(const ValueKey('calendar_reminder_hours'));
        final minutes = find.byKey(const ValueKey('calendar_reminder_minutes'));
        final hourSemantics = find.byKey(
          const ValueKey('calendar_reminder_hours_semantics'),
        );
        final minuteSemantics = find.byKey(
          const ValueKey('calendar_reminder_minutes_semantics'),
        );
        await tester.enterText(text, 'Visita dal dentista');
        expect(hours, findsNothing);
        expect(minutes, findsNothing);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byType(Slider), findsNWidgets(2));
        expect(find.byType(TimePickerDialog), findsNothing);
        expect(tester.widget<Slider>(hours).divisions, 23);
        expect(tester.widget<Slider>(minutes).divisions, 59);
        tester.widget<Slider>(hours).onChanged!(13);
        tester.widget<Slider>(minutes).onChanged!(4);
        await tester.pump();

        final hourNode = tester.getSemantics(hourSemantics);
        final minuteNode = tester.getSemantics(minuteSemantics);
        final l10n = AppLocalizations.of(tester.element(hours));
        expect(
          hourNode.getSemanticsData().label,
          l10n.radioScheduleSelectHours,
        );
        expect(
          minuteNode.getSemanticsData().label,
          l10n.radioScheduleSelectMinutes,
        );
        expect(hourNode.getSemanticsData().value, '13');
        expect(minuteNode.getSemanticsData().value, '04');
        final owner = tester.binding.renderViews.first.owner!.semanticsOwner!;
        owner.performAction(hourNode.id, SemanticsAction.increase);
        owner.performAction(minuteNode.id, SemanticsAction.increase);
        await tester.pump();
        expect(tester.widget<Slider>(hours).value, 14);
        expect(tester.widget<Slider>(minutes).value, 5);
        expect(tester.getSemantics(hourSemantics).id, hourNode.id);
        expect(tester.getSemantics(minuteSemantics).id, minuteNode.id);

        // Rapid gestures must read the current value, not a stale build value.
        owner.performAction(minuteNode.id, SemanticsAction.increase);
        owner.performAction(minuteNode.id, SemanticsAction.increase);
        await tester.pump();
        expect(tester.widget<Slider>(minutes).value, 7);
        owner.performAction(minuteNode.id, SemanticsAction.decrease);
        owner.performAction(minuteNode.id, SemanticsAction.decrease);
        await tester.pump();
        expect(tester.widget<Slider>(minutes).value, 5);

        await tester.tap(toggle);
        await tester.pump();
        expect(hours, findsNothing);
        await tester.tap(toggle);
        await tester.pump();
        expect(tester.widget<Slider>(hours).value, 14);
        expect(tester.widget<Slider>(minutes).value, 5);
        expect(
          tester.widget<TextField>(text).controller!.text,
          'Visita dal dentista',
        );
        await tester.tap(find.byKey(const ValueKey('calendar_reminder_save')));
        await tester.pumpAndSettle();
        expect(saved?.hasTime, isTrue);
        expect(saved?.date, DateTime(2027, 1, 24, 14, 5));
        expect(saved?.text, 'Visita dal dentista');
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  for (final time in [
    const TimeOfDay(hour: 0, minute: 0),
    const TimeOfDay(hour: 23, minute: 59),
  ]) {
    testWidgets(
      'time sliders save boundary $time without wrapping',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          CalendarEvent? saved;
          await _openReminder(tester, (event) => saved = event);
          await tester.enterText(
            find.byKey(const ValueKey('calendar_reminder_text')),
            'Limite',
          );
          await tester.tap(
            find.byKey(const ValueKey('calendar_reminder_has_time')),
          );
          await tester.pump();
          final hours = find.byKey(const ValueKey('calendar_reminder_hours'));
          final minutes = find.byKey(
            const ValueKey('calendar_reminder_minutes'),
          );
          tester.widget<Slider>(hours).onChanged!(time.hour.toDouble());
          tester.widget<Slider>(minutes).onChanged!(time.minute.toDouble());
          await tester.pump();
          final unavailableAction = time.hour == 0
              ? SemanticsAction.decrease
              : SemanticsAction.increase;
          for (final name in ['hours', 'minutes']) {
            final node = tester.getSemantics(
              find.byKey(ValueKey('calendar_reminder_${name}_semantics')),
            );
            expect(
              node.getSemanticsData().hasAction(unavailableAction),
              isFalse,
            );
          }
          await tester.tap(
            find.byKey(const ValueKey('calendar_reminder_save')),
          );
          await tester.pumpAndSettle();
          expect(saved?.hasTime, isTrue);
          expect(saved?.date, DateTime(2027, 1, 24, time.hour, time.minute));
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }

  testWidgets('turning time off saves a day reminder without losing its text', (
    tester,
  ) async {
    CalendarEvent? saved;
    await _openReminder(tester, (event) => saved = event);
    await tester.enterText(
      find.byKey(const ValueKey('calendar_reminder_text')),
      'Da fare',
    );
    final toggle = find.byKey(const ValueKey('calendar_reminder_has_time'));
    await tester.tap(toggle);
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump();
    expect(find.byType(Slider), findsNothing);
    await tester.tap(find.byKey(const ValueKey('calendar_reminder_save')));
    await tester.pumpAndSettle();
    expect(saved?.text, 'Da fare');
    expect(saved?.hasTime, isFalse);
    expect(saved?.date, DateTime(2027, 1, 24));
  });
}
