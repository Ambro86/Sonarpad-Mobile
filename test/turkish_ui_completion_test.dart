import 'package:sonarpad_mobile_starter/services/app_settings_service.dart';
import 'package:sonarpad_mobile_starter/screens/calendar_screen.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_lookup.dart';
import 'package:sonarpad_mobile_starter/models/calendar_event.dart';
import 'package:sonarpad_mobile_starter/screens/calendar_day_screen.dart';
import 'package:sonarpad_mobile_starter/screens/sonarmusic_screen.dart';
import 'package:sonarpad_mobile_starter/services/calendar/calendar_service.dart';
import 'package:sonarpad_mobile_starter/services/sonarmusic_service.dart';
import 'package:sonarpad_mobile_starter/services/sonartube_service.dart';
import 'package:sonarpad_mobile_starter/widgets/letter_jump_option_picker_screen.dart';
import 'package:sonarpad_mobile_starter/widgets/universal_accessible_view.dart';

const _letterOptions = <String>[
  'Ceyhan', 'Çorum', 'Gaziantep', 'Ğ', 'Isparta', 'ışık',
  'İstanbul', 'istanbul', 'Ordu', 'örnek', 'Samsun', 'şarkı',
  'Uşak', 'üzüm', 'Qatar', 'Wales', 'Xanten', 'Zonguldak',
];

Widget _localizedApp(Widget child, {String language = 'tr'}) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

List<AccessibleListRow> _visibleRows(WidgetTester tester) => tester
    .widget<UniversalAccessibleList>(find.byType(UniversalAccessibleList))
    .sections.expand((section) => section.rows).toList();

Widget _letterPicker({String language = 'tr'}) => _localizedApp(
  LetterJumpOptionPickerScreen<String>(
    title: 'Test options',
    options: _letterOptions,
    labelBuilder: (value) => value,
    selectLetterLabel: 'Choose a letter',
    selectLetterTitle: 'Test letters',
  ),
  language: language,
);

class _FailingMusicService extends SonarMusicService {
  _FailingMusicService() : super(directCatalog: false);
  int resolveCalls = 0;

  @override
  Future<List<String>> suggestions(String query) async => ['İstanbul şarkısı'];

  @override
  Future<SonarMusicPage> search(String query, {
    String type = 'all', String? token, int page = 1,
  }) async => const SonarMusicPage(items: [
    SonarMusicItem(kind: 'song', id: 'abcdefghijk', videoId: 'abcdefghijk',
      title: 'İstanbul şarkısı', artist: 'Şarkıcı'),
  ]);

  @override
  Future<SonarTubeResolvedMedia> resolve(SonarMusicItem song) async {
    resolveCalls++;
    throw StateError('Impossibile riprodurre il contenuto: fixture');
  }
}

class _PendingCalendarService extends CalendarService {
  final saints = <({DateTime date, String language,
    Completer<String?> result})>[];
  final events = <({DateTime date, Completer<List<CalendarEvent>> result})>[];

  @override
  String? getSaint(DateTime date, String languageCode) =>
      languageCode == 'tr' ? 'Türkçe aziz ${date.day}' : 'Santo ${date.day}';

  @override
  Future<String?> getSaintAsync(DateTime date, String languageCode) {
    final result = Completer<String?>();
    saints.add((date: date, language: languageCode, result: result));
    return result.future;
  }

  @override
  Future<List<CalendarEvent>> getEventsForDate(DateTime date) {
    final result = Completer<List<CalendarEvent>>();
    events.add((date: date, result: result));
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // CalendarDayScreen formats day/month names with intl. Load its bundled
    // date symbols explicitly so this file also works when run on its own.
    await initializeDateFormatting();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    configureAccessibleRendererRuntime(useFlutterOnIos: true);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'),
      (_) async => 1);
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'), (_) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('wakelock_plus'),
      (call) async => call.method == 'isEnabled' ? false : null);
  });

  tearDown(() {
    configureAccessibleRendererRuntime(useFlutterOnIos: false);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'), null);
    messenger.setMockMethodCallHandler(const MethodChannel('wakelock_plus'), null);
  });

  testWidgets('Turkish letter index keeps dotted I separate and uses Turkish order',
    (tester) async {
      await tester.pumpWidget(_letterPicker());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a letter'));
      await tester.pumpAndSettle();

      expect(_visibleRows(tester).map((row) => row.title), [
        'C', 'Ç', 'G', 'Ğ', 'I', 'İ', 'O', 'Ö', 'Q',
        'S', 'Ş', 'U', 'Ü', 'W', 'X', 'Z',
      ]);
      await tester.tap(find.text('İ'));
      await tester.pumpAndSettle();
      expect(_visibleRows(tester).where((row) => row.id.startsWith('option_'))
        .map((row) => row.title), ['İstanbul', 'istanbul']);
      expect(find.text('Isparta'), findsNothing);
      expect(find.text('ışık'), findsNothing);

      Navigator.of(tester.element(find.byType(UniversalAccessibleList))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('I'));
      await tester.pumpAndSettle();
      expect(_visibleRows(tester).where((row) => row.id.startsWith('option_'))
        .map((row) => row.title), ['Isparta', 'ışık']);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
  );

  testWidgets('Other locales retain the previous Unicode letter order',
    (tester) async {
      await tester.pumpWidget(_letterPicker(language: 'en'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a letter'));
      await tester.pumpAndSettle();
      expect(_visibleRows(tester).map((row) => row.title), [
        'C', 'G', 'I', 'O', 'Q', 'S', 'U', 'W', 'X', 'Z',
        'Ç', 'Ö', 'Ü', 'Ğ', 'İ', 'Ş',
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Music suggestions use one accessible Back and the shared Home action',
    (tester) async {
      final service = _FailingMusicService();
      final l10n = lookupSupportedAppLocalizations('tr');
      await tester.pumpWidget(_localizedApp(SonarMusicScreen(service: service)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.sonarMusicSuggest), findsNothing);
      await tester.enterText(find.byType(TextField), 'İstanbul');
      await tester.pump(); // Suggestions appear after the empty-to-text change.
      final suggestions = find.text(l10n.sonarMusicSuggest);
      await tester.ensureVisible(suggestions);
      await tester.tap(suggestions);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(SonarpadAppBar), findsOneWidget);
      expect(find.byType(SonarpadBackButton), findsOneWidget);
      expect(find.byType(SonarpadBackSemantics), findsOneWidget);
      expect(find.byType(SonarpadVisualHomeButton), findsOneWidget);
      expect(find.text(l10n.cancel), findsNothing);
      expect(find.text('İstanbul şarkısı'), findsOneWidget);
      await tester.tap(find.byType(SonarpadBackButton));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'İstanbul');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
  );

  testWidgets('Music playback failures show Turkish text and restore the result',
    (tester) async {
      final service = _FailingMusicService();
      final l10n = lookupSupportedAppLocalizations('tr');
      await tester.pumpWidget(_localizedApp(
        SonarMusicScreen(service: service, searchQuery: 'İstanbul')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İstanbul şarkısı'));
      await tester.pumpAndSettle();
      expect(service.resolveCalls, 1);
      expect(find.text(l10n.error(l10n.technicalErrorGeneric)), findsOneWidget);
      expect(find.textContaining('Impossibile riprodurre'), findsNothing);
      expect(_visibleRows(tester).singleWhere((row) => row.id == 'item_0').enabled,
        isTrue);
      expect(find.text('İstanbul şarkısı'), findsOneWidget);
      // The error uses ScaffoldMessenger's timed SnackBar. Dispose it, along
      // with focus callbacks, before global teardown removes platform mocks.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  test('Calendar saints remain visible by default and the preference persists', () async {
    final settings = AppSettingsService();
    expect(await settings.isCalendarSaintsHidden(), isFalse);
    await settings.setCalendarSaintsHidden(true);
    expect(await AppSettingsService().isCalendarSaintsHidden(), isTrue);
    await settings.setCalendarSaintsHidden(false);
    expect(await AppSettingsService().isCalendarSaintsHidden(), isFalse);
  });

  testWidgets('Hidden saints are absent from calendar list and accessible day details', (tester) async {
    await AppSettingsService().setCalendarSaintsHidden(true);
    final l10n = lookupSupportedAppLocalizations('tr');
    await tester.pumpWidget(_localizedApp(const CalendarScreen()));
    await tester.pumpAndSettle();
    expect(_visibleRows(tester).any((row) => (row.subtitle ?? '').contains(l10n.saintOfTheDay)), isFalse);
    final service = _PendingCalendarService();
    await tester.pumpWidget(_localizedApp(CalendarDayScreen(date: DateTime(2026, 10, 13), service: service)));
    await tester.pumpAndSettle();
    expect(service.saints, isEmpty);
    expect(_visibleRows(tester).any((row) => row.id == 'saint'), isFalse);
    expect(find.textContaining(l10n.saintOfTheDay), findsNothing);
    expect(_visibleRows(tester).any((row) => row.title.contains(l10n.quoteOfTheDay)), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Reused calendar routes refresh Turkish saints and ignore stale results',
    (tester) async {
      final service = _PendingCalendarService();
      final firstDate = DateTime(2026, 10, 13);
      final nextDate = DateTime(2026, 10, 14);
      final l10n = lookupSupportedAppLocalizations('tr');
      Widget calendar(String language, DateTime date) => _localizedApp(
        CalendarDayScreen(key: const ValueKey('same-day-route'),
          date: date, service: service),
        language: language,
      );

      await tester.pumpWidget(calendar('it', firstDate));
      await tester.pumpAndSettle();
      expect(service.saints.single.language, 'it');
      await tester.pumpWidget(calendar('tr', firstDate));
      await tester.pumpAndSettle();
      expect(service.saints.last.language, 'tr');
      expect(_visibleRows(tester).singleWhere((row) => row.id == 'saint').title,
        '${l10n.saintOfTheDay}: Türkçe aziz 13');

      service.saints.last.result.complete('Türkçe tamamlandı');
      await tester.pumpAndSettle();
      service.saints.first.result.complete('Santo precedente');
      await tester.pumpAndSettle();
      expect(_visibleRows(tester).singleWhere((row) => row.id == 'saint').title,
        '${l10n.saintOfTheDay}: Türkçe tamamlandı');

      await tester.pumpWidget(calendar('tr', nextDate));
      await tester.pumpAndSettle();
      expect(service.saints.last.date, nextDate);
      expect(_visibleRows(tester).singleWhere((row) => row.id == 'saint').title,
        '${l10n.saintOfTheDay}: Türkçe aziz 14');
      service.events.first.result.complete([
        CalendarEvent(id: 'old', date: firstDate, text: 'Previous day reminder'),
      ]);
      service.events.last.result.complete([
        CalendarEvent(id: 'current', date: nextDate, text: 'Yeni gün hatırlatıcısı'),
      ]);
      service.saints.last.result.complete('Türkçe son gün');
      await tester.pumpAndSettle();
      expect(find.text('Previous day reminder'), findsNothing);
      expect(find.text('Yeni gün hatırlatıcısı'), findsOneWidget);
      expect(_visibleRows(tester).singleWhere((row) => row.id == 'saint').title,
        '${l10n.saintOfTheDay}: Türkçe son gün');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
