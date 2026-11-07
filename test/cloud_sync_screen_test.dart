import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/cloud_sync_screen.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_service.dart';
import 'package:sonarpad_mobile_starter/services/cloud_sync_api.dart';

class FakeSync extends CloudSyncService {
  String? lastSync;
  bool connected = false;
  String? joinedCode;
  int connections = 0;
  bool needsDeletionReview = false;
  int approvals = 0;
  final review = <String, dynamic>{
    'direction': 'outgoing',
    'before': {
      'sonartube': [
        {
          'id': 'a',
          'data': {'title': 'A'},
        },
      ],
    },
    'after': {'sonartube': []},
  };
  @override
  Future<void> synchronize() async {
    if (needsDeletionReview) {
      throw const CloudSyncApiException('deletion_confirmation_required');
    }
  }

  @override
  Future<Map<String, dynamic>> metadata() async => {
    if (connected) 'group_id': 'test',
    if (needsDeletionReview) 'deletion_review': review,
    if (lastSync != null) 'last_sync': lastSync,
  };
  @override
  Future<void> connect({String? code}) async {
    connections++;
    joinedCode = code;
    connected = true;
  }

  @override
  Future<String> invitation() async => '12345678';
  @override
  Future<void> disconnect() async => connected = false;
}

void main() {
  setUp(() {
    CloudSyncService.automaticPending = false;
    CloudSyncService.automaticFailed = false;
  });
  Future<void> open(WidgetTester tester, FakeSync service) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CloudSyncScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'first device: two choices, then connected actions and separate options',
    (tester) async {
      final service = FakeSync();
      await open(tester, service);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.text('Sincronizza ora'), findsNothing);
      await tester.tap(find.text('Inizia da questo dispositivo'));
      await tester.pumpAndSettle();
      expect(service.connections, 1);
      expect(find.text('Inizia da questo dispositivo'), findsNothing);
      expect(find.text('Ho già un codice'), findsNothing);
      expect(find.text('Sincronizza ora'), findsOneWidget);
      expect(find.text('12345678'), findsOneWidget);
      expect(find.text('Scollega questo dispositivo'), findsNothing);
      await tester.tap(find.text('Opzioni di sincronizzazione'));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNWidgets(2));
      expect(find.text('Sincronizza ora'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Sincronizza ora'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
    },
  );

  testWidgets(
    'join code appears only when requested; incomplete code never connects',
    (tester) async {
      final service = FakeSync();
      await open(tester, service);
      await tester.tap(find.text('Ho già un codice'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Inizia da questo dispositivo'), findsNothing);
      await tester.enterText(find.byType(TextField), '123');
      await tester.tap(find.text('Collega con un codice'));
      await tester.pumpAndSettle();
      expect(service.connections, 0);
      await tester.enterText(find.byType(TextField), '87654321');
      await tester.tap(find.text('Collega con un codice'));
      await tester.pumpAndSettle();
      expect(service.joinedCode, '87654321');
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Sincronizza ora'), findsOneWidget);
    },
  );

  testWidgets(
    'automatic status shows last success and retries without an alert',
    (tester) async {
      final service = FakeSync()
        ..connected = true
        ..lastSync = '2026-11-04T12:00:00Z';
      await open(tester, service);
      expect(find.textContaining('Tutto sincronizzato.'), findsOneWidget);
      expect(find.textContaining('Ultima sincronizzazione:'), findsOneWidget);
      CloudSyncService.automaticFailed = true;
      CloudSyncService.changes.value++;
      await tester.pumpAndSettle();
      expect(find.textContaining('Riproverò automaticamente.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.textContaining('Sincronizzazione non riuscita'),
        findsNothing,
      );
      expect(find.text('Sincronizza ora'), findsOneWidget);
      CloudSyncService.automaticFailed = false;
    },
  );
  testWidgets(
    'Legacy removal review stays silent while protected sync retries',
    (tester) async {
      final service = FakeSync()
        ..connected = true
        ..needsDeletionReview = true;
      await open(tester, service);
      expect(find.textContaining('Rimozione inattesa bloccata'), findsNothing);
      await tester.tap(find.text('Sincronizza ora'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(service.needsDeletionReview, isTrue);
      expect(find.textContaining('Rimozione inattesa bloccata'), findsNothing);
      expect(find.textContaining('Riproverò automaticamente.'), findsWidgets);
      expect(find.text('Sincronizza ora'), findsOneWidget);
      expect(service.approvals, 0);
    },
  );
}
