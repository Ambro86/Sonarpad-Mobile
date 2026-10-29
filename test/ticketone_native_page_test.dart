import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:sonarpad_mobile_starter/screens/ticketone_native_page.dart';
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
  Future<Object> runJavaScriptReturningResult(String script) async =>
      jsonEncode(page);
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

  testWidgets('OTP digits have Italian labels', (tester) async {
    final c = NativeController();
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
    await start(tester, c, []);
    expect(row(tester, 'First').title, 'Codice monouso, cifra 1 di 6');
    expect(row(tester, 'Sixth').title, 'Codice monouso, cifra 6 di 6');
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
    expect(rows(tester).any((r) => r.id == 'loading'), isTrue);
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
      expect(rows(tester).any((r) => r.id == 'f0'), isFalse);
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
