import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:sonarpad_mobile_starter/screens/ticketone_native_page.dart';
import 'package:sonarpad_mobile_starter/services/ticketone_page_diagnostics.dart';
import 'travel_screen_test.dart' show app, row, rows;

Map<String, dynamic> field(
  String id,
  String label, {
  String type = 'email',
  bool secret = false,
}) => {
  'id': id,
  'label': label,
  'kind': 'text',
  'type': type,
  'secret': secret,
  'value': '',
  'enabled': true,
  'required': true,
  'options': [],
};
Map<String, dynamic> action(String id, String label, {bool submit = true}) => {
  'id': id,
  'label': label,
  'enabled': true,
  'submit': submit,
};
Map<String, dynamic> snapshot(
  List<Map<String, dynamic>> fields,
  List<Map<String, dynamic>> actions,
) => {
  'status': 'ready',
  'stage': 'login',
  'revision': 'fixture',
  'title': 'TicketOne',
  'fields': fields,
  'actions': actions,
  'errors': [],
  'notices': [],
};

class NativeController extends Fake implements WebViewController {
  String url = 'https://auth.ticketone.it/identity/auth/';
  Map<String, dynamic> page = snapshot(
    [field('f0', 'Indirizzo Email')],
    [action('a0', 'Continua')],
  );
  final scripts = <String>[];
  void Function(JavaScriptMessage)? receive;
  final channels = <String>{};
  Completer<Object>? pendingSnapshot;
  int captures = 0;
  @override
  Future<void> removeJavaScriptChannel(String name) async {
    channels.remove(name);
  }

  @override
  Future<void> addJavaScriptChannel(
    String name, {
    required void Function(JavaScriptMessage) onMessageReceived,
  }) async {
    if (!channels.add(name)) throw ArgumentError('Channel already exists');
    receive = onMessageReceived;
  }

  @override
  Future<String?> currentUrl() async => url;
  @override
  Future<Object> runJavaScriptReturningResult(String script) async {
    if (script == ticketOnePageDiagnosticsScript) {
      captures++;
      return jsonEncode({'version': 1, 'html': '<form id="test"></form>'});
    }
    return pendingSnapshot == null
        ? jsonEncode(page)
        : await pendingSnapshot!.future;
  }

  @override
  Future<void> runJavaScript(String script) async {
    scripts.add(script);
  }

  void reply(String status, {String? field}) {
    final id = jsonDecode(
      RegExp(r'id:("[^"]+")').firstMatch(scripts.last)!.group(1)!,
    );
    receive!(
      JavaScriptMessage(
        message: jsonEncode({'id': id, 'status': status, 'field': ?field}),
      ),
    );
  }
}

void main() {
  Future<void> start(
    WidgetTester tester,
    NativeController c,
    List<String> logs,
  ) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TicketOneNativePage(
            controller: c,
            generation: 0,
            loading: false,
            showWebsite: () {},
            log: logs.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every unrecognized page captures its structure in the log', (
    tester,
  ) async {
    final c = NativeController()..page = {'status': 'unsupported'};
    final logs = <String>[];
    await start(tester, c, logs);
    expect(c.captures, 1);
    expect(logs.any((l) => l.startsWith('page_capture_begin')), isTrue);
    expect(
      logs.any(
        (l) => l.contains('form id=') && l.contains('page_capture_part'),
      ),
      isTrue,
    );
    expect(logs.any((l) => l.startsWith('page_capture_end')), isTrue);
    // A new document is independently captured, even with the same failure.
    await tester.pumpWidget(const SizedBox());
    await start(tester, c, logs);
    expect(c.captures, 2);
    expect(c.scripts, isEmpty);
  });

  testWidgets(
    'waiting page captures both initial and exhausted recovery state',
    (tester) async {
      final c = NativeController()..page = {'status': 'waiting'};
      final logs = <String>[];
      await start(tester, c, logs);
      for (var i = 0; i < 13; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }
      expect(c.captures, 2);
      expect(
        logs.any(
          (l) =>
              l.startsWith('page_capture_end') &&
              l.contains('unrecognized_initial'),
        ),
        isTrue,
      );
      expect(
        logs.any(
          (l) =>
              l.startsWith('page_capture_end') &&
              l.contains('unrecognized_final'),
        ),
        isTrue,
      );
      expect(logs, contains('native_unsupported'));
    },
  );

  testWidgets('identity denial is immediate and never resubmits', (
    tester,
  ) async {
    final c = NativeController();
    c.page = {'status': 'access-denied'};
    await start(tester, c, []);
    expect(
      row(tester, 'message').title,
      contains('server TicketOne ha rifiutato'),
    );
    expect(rows(tester).any((r) => r.id == 'loading'), isFalse);
    expect(c.scripts, isEmpty);
  });

  testWidgets(
    'cancel loading returns to previous screen and ignores late read',
    (tester) async {
      final c = NativeController()..pendingSnapshot = Completer<Object>();
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: TicketOneNativePage(
                        controller: c,
                        generation: 0,
                        loading: false,
                        showWebsite: () {},
                        log: (_) {},
                      ),
                    ),
                  ),
                ),
                child: const Text('Apri prova'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri prova'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TicketOneLoadingView), findsOneWidget);
      expect(find.text('Torna alla pagina TicketOne'), findsNothing);
      await tester.tap(find.byKey(const Key('cancel-ticketone-loading')));
      await tester.pumpAndSettle();
      c.pendingSnapshot!.complete(jsonEncode(c.page));
      await tester.pump();
      expect(find.text('Apri prova'), findsOneWidget);
      expect(find.byType(TicketOneNativePage), findsNothing);
      expect(tester.takeException(), isNull);
      expect(c.scripts, isEmpty);
    },
  );

  testWidgets('unanswered snapshot exits loading without submitting anything', (
    tester,
  ) async {
    final c = NativeController()..pendingSnapshot = Completer<Object>();
    final logs = <String>[];
    await start(tester, c, logs);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();
    expect(logs, contains('native_read_timeout'));
    expect(rows(tester).any((r) => r.id == 'loading'), isFalse);
    expect(row(tester, 'refresh').title, isNotEmpty);
    expect(c.scripts, isEmpty);
    c.pendingSnapshot!.complete(jsonEncode(c.page));
    await tester.pump();
    expect(rows(tester).any((r) => r.id == 'loading'), isFalse);
  });

  testWidgets(
    'unavailable event categories remain native with a refresh action',
    (tester) async {
      final c = NativeController();
      c.page = {
        ...snapshot([], []),
        'stage': 'event',
        'unavailableCategories': [
          {'category': 'Poltronissima', 'message': 'Non disponibile'},
          {'category': 'Galleria B', 'message': ''},
        ],
      };
      await start(tester, c, []);
      expect(
        row(tester, 'unavailable-Poltronissima').title,
        'Poltronissima: Non disponibile',
      );
      expect(
        row(tester, 'unavailable-Galleria B').title,
        contains('attualmente non disponibili'),
      );
      expect(row(tester, 'refresh').title, isNotEmpty);
      expect(rows(tester).any((r) => r.id == 'consent'), isFalse);
      expect(
        rows(tester).any(
          (r) => r.title.contains(
            'non è ancora disponibile in modalità accessibile',
          ),
        ),
        isFalse,
      );
    },
  );

  testWidgets('OTP digits have Italian labels', (tester) async {
    final c = NativeController();
    final logs = <String>[];
    c.page = snapshot(
      [
        for (final name in [
          'First',
          'Second',
          'Third',
          'Fourth',
          'Fifth',
          'Sixth',
        ])
          field(name, '$name Digit', type: 'text', secret: true),
      ],
      [action('a0', 'Accedi')],
    );
    await start(tester, c, logs);
    expect(row(tester, 'otp-heading').title, 'Codice monouso');
    expect(row(tester, 'First').title, 'Cifra 1');
    expect(row(tester, 'Sixth').title, 'Cifra 6');
    await row(tester, 'First').onValueChanged!('123 456');
    await tester.pump();
    expect(logs, contains('native_otp_complete digits=6'));
    expect(logs.join(), isNot(contains('123456')));
    await tester.pump(const Duration(milliseconds: 300));
    final ids = ['First', 'Second', 'Third', 'Fourth', 'Fifth', 'Sixth'];
    for (var i = 0; i < 6; i++) {
      expect(row(tester, ids[i]).value, '${i + 1}');
      expect(row(tester, ids[i]).textRevision, 1);
    }
    expect(
      c.scripts,
      isEmpty,
    ); // Pasting never submits the login automatically.
    await row(tester, 'Third').onValueChanged!('654321');
    await tester.pump();
    expect(row(tester, 'First').value, '6');
    expect(row(tester, 'Sixth').value, '1');
    await row(tester, 'Third').onValueChanged!('');
    await tester.pump();
    expect(row(tester, 'Third').value, '');
    expect(row(tester, 'Fourth').value, '3');
    await row(tester, 'Third').onValueChanged!('9');
    await tester.pump();
    await row(tester, 'a0').onActivate!();
    expect(c.scripts.last, contains('"Third":"9"'));
    expect(c.scripts.last, isNot(contains('654321')));
    c.reply('submitted');
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('security check stops the ticket form without submitting again', (
    tester,
  ) async {
    final c = NativeController();
    c.page = {
      'status': 'security-check',
      'diagnostics': {'reason': 'security_check'},
    };
    final logs = <String>[];
    await start(tester, c, logs);
    expect(row(tester, 'message').title, contains('controllo di sicurezza'));
    expect(row(tester, 'website').title, 'Torna alla pagina TicketOne');
    expect(c.scripts, isEmpty);
    expect(logs, contains('native_security_check'));
  });

  testWidgets('persistent host channel works after native page recreation', (
    tester,
  ) async {
    final c = NativeController(), messages = ValueNotifier<String?>(null);
    c.channels.add('TicketOneUi');
    Future<void> mountPage() async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: TicketOneNativePage(
              controller: c,
              generation: 0,
              loading: false,
              messages: messages,
              showWebsite: () {},
              log: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await mountPage();
    await row(tester, 'a0').onActivate!();
    final oldId = jsonDecode(
      RegExp(r'id:("[^"]+")').firstMatch(c.scripts.last)!.group(1)!,
    );
    await tester.pumpWidget(const SizedBox());
    await mountPage();
    expect(
      c.receive,
      isNull,
      reason:
          'The host owns registration; never replace it on an already loaded document.',
    );
    await row(tester, 'a0').onActivate!();
    await tester.pump();
    final id = jsonDecode(
      RegExp(r'id:("[^"]+")').firstMatch(c.scripts.last)!.group(1)!,
    );
    expect(
      id,
      isNot(oldId),
      reason:
          'Replies from the previous native page must not acknowledge a new action.',
    );
    messages.value = jsonEncode({
      'id': oldId,
      'status': 'invalid',
      'field': 'f0',
    });
    await tester.pump();
    expect(find.byType(TicketOneLoadingView), findsOneWidget);
    expect(find.byKey(const Key('cancel-ticketone-loading')), findsOneWidget);
    messages.value = jsonEncode({'id': id, 'status': 'invalid', 'field': 'f0'});
    await tester.pumpAndSettle();
    expect(rows(tester).any((r) => r.id == 'f0'), isTrue);
    await tester.pumpWidget(const SizedBox());
    messages.dispose();
  });

  testWidgets('typed email survives keyboard and list rebuilds', (
    tester,
  ) async {
    final c = NativeController();
    await start(tester, c, []);
    await tester.enterText(
      find.byType(TextFormField).first,
      'person@example.test',
    );
    await tester.pump();
    expect(row(tester, 'f0').value, 'person@example.test');
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      'person@example.test',
    );
    await row(tester, 'a0').onActivate!();
    await tester.pump();
    expect(c.scripts.single, contains('person@example.test'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('structural diagnostics redact untrusted content', (
    tester,
  ) async {
    final c = NativeController(), logs = <String>[];
    c.page = {
      'status': 'unsupported',
      'diagnostics': {
        'reason': 'custom_control',
        'page': 'event',
        'ready': 'complete',
        'root': true,
        'customCombos': 2,
        'controls': 4,
        'password': 'PRIVATE',
        'url': 'https://secret/',
        'forms': 'PRIVATE',
      },
    };
    await start(tester, c, logs);
    expect(logs.join(), contains('custom_control'));
    expect(logs.join(), contains('customCombos'));
    expect(logs.join(), isNot(contains('PRIVATE')));
    expect(logs.join(), isNot(contains('https://secret')));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('registration snapshot is accepted by native page', (
    tester,
  ) async {
    final c = NativeController(), logs = <String>[];
    c.url = 'https://www.ticketone.it/dashboard/login/register';
    c.page['stage'] = 'registration';
    await start(tester, c, logs);
    expect(row(tester, 'f0').keyboardType, 'email');
    expect(logs, isNot(contains('native_schema')));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'same WebView can reopen native controls after the account panel',
    (tester) async {
      final c = NativeController(), logs = <String>[];
      c.channels.add('TicketOneSession');
      await start(tester, c, logs);
      await tester.pumpWidget(const SizedBox());
      expect(c.channels, contains('TicketOneUi'));
      await start(tester, c, logs);
      expect(row(tester, 'f0').keyboardType, 'email');
      expect(c.channels, contains('TicketOneSession'));
      expect(logs, isNot(contains('native_channel_failed')));
      await row(tester, 'a0').onActivate!();
      await tester.pump();
      c.reply('invalid', field: 'f0');
      await tester.pumpAndSettle();
      expect(rows(tester).any((r) => r.id == 'f0'), isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'native email submits once with explicit cookie consent then password/OTP choice',
    (tester) async {
      final c = NativeController(), logs = <String>[];
      await start(tester, c, logs);
      expect(row(tester, 'f0').keyboardType, 'email');
      row(tester, 'f0').onValueChanged!('person@example.test');
      final send = row(tester, 'a0').onActivate!;
      await send();
      await send();
      await tester.pump();
      expect(c.scripts.length, 1);
      expect(c.scripts.single, contains('"acceptCookies":true'));
      expect(c.scripts.single, contains('person@example.test'));
      expect(find.byType(TicketOneLoadingView), findsOneWidget);
      expect(find.byKey(const Key('cancel-ticketone-loading')), findsOneWidget);
      c.page = snapshot(
        [field('f0', 'Password', type: 'password', secret: true)],
        [
          action('a0', 'Accedi'),
          action('a1', 'Accedi con un codice monouso', submit: false),
        ],
      );
      c.reply('submitted');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(row(tester, 'f0').secure, isTrue);
      expect(row(tester, 'f0').value, '');
      await row(tester, 'a1').onActivate!();
      await tester.pump();
      c.page = snapshot(
        [field('f0', 'Codice', type: 'text', secret: true)],
        [action('a0', 'Conferma')],
      );
      c.reply('submitted');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(row(tester, 'f0').keyboardType, 'number');
      expect(logs.join(), isNot(contains('person@example.test')));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failed cookie consent preserves native email and does not resend',
    (tester) async {
      final c = NativeController();
      await start(tester, c, []);
      row(tester, 'f0').onValueChanged!('person@example.test');
      await row(tester, 'a0').onActivate!();
      c.reply('cookies-visible');
      await tester.pumpAndSettle();
      expect(row(tester, 'message').title, contains('Nessun modulo inviato'));
      expect(row(tester, 'f0').value, 'person@example.test');
      await tester.pump(const Duration(seconds: 20));
      expect(c.scripts.length, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('invalid field is announced and no automatic mutation follows', (
    tester,
  ) async {
    final c = NativeController();
    await start(tester, c, []);
    await row(tester, 'a0').onActivate!();
    c.reply('invalid', field: 'f0');
    await tester.pumpAndSettle();
    expect(row(tester, 'message').title, contains('Indirizzo Email'));
    expect(c.scripts.length, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('lost acknowledgement never repeats the submission', (
    tester,
  ) async {
    final c = NativeController();
    await start(tester, c, []);
    await row(tester, 'a0').onActivate!();
    await tester.pump(const Duration(seconds: 13));
    expect(row(tester, 'message').title, contains('Non reinvio i dati'));
    await tester.pump(const Duration(seconds: 30));
    expect(c.scripts.length, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('foreign payment provider is not inspected', (tester) async {
    final c = NativeController()..url = 'https://www.paypal.com/checkout';
    final logs = <String>[];
    await start(tester, c, logs);
    expect(logs, contains('native_foreign'));
    expect(rows(tester).any((r) => r.id == 'f0'), isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
