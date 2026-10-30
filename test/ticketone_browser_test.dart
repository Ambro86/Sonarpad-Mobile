import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:sonarpad_mobile_starter/screens/ticketone_browser_screen.dart';
import 'package:sonarpad_mobile_starter/services/ticketone_session.dart';
import 'package:sonarpad_mobile_starter/services/ticketone_accessible_script.dart';
import 'travel_browser_test.dart' show BrowserPlatform, BrowserController;
import 'travel_screen_test.dart' show app, row, rows;

class TicketController extends BrowserController {
  void Function(JavaScriptMessage)? channel;
  final loads = <Uri>[];
  final channels = <String>{};
  String readyState = 'complete';
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
    if (name == 'TicketOneSession') channel = onMessageReceived;
  }

  @override
  Future<Object> runJavaScriptReturningResult(String script) async {
    if (script == 'document.readyState') return readyState;
    if (script == ticketOneUiSnapshotScript) return '{"status":"unsupported"}';
    return super.runJavaScriptReturningResult(script);
  }

  @override
  Future<void> loadRequest(
    Uri uri, {
    LoadRequestMethod method = LoadRequestMethod.get,
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    expectSync(method, LoadRequestMethod.get);
    expectSync(channels, contains('TicketOneUi'));
    expectSync(channels, contains('TicketOneSession'));
    current = uri.toString();
    loads.add(uri);
  }

  @override
  Future<void> runJavaScript(String script) async {
    scripts.add(script);
  }

  Iterable<String> get probes =>
      scripts.where((s) => s.contains('const requestId = '));
  String get requestId =>
      jsonDecode(
            RegExp(
              r'const requestId = ("[a-f0-9]+");',
            ).firstMatch(probes.last)!.group(1)!,
          )
          as String;

  void reply({
    bool authenticated = true,
    int count = 0,
    int amountMilli = 0,
    String? id,
    String status = 'ok',
    int? http,
  }) {
    channel!(
      JavaScriptMessage(
        message: jsonEncode({
          'requestId': id ?? requestId,
          'status': status,
          'authenticated': authenticated,
          'count': count,
          'amountMilli': amountMilli,
          'http': http,
        }),
      ),
    );
  }
}

void main() {
  setUp(() => WebViewPlatform.instance = BrowserPlatform());
  final event = Uri.parse('https://www.ticketone.it/event/selected-123/');
  Future<void> start(
    WidgetTester tester,
    TicketController controller,
    List<String> logs, {
    String accountPath = '/dashboard/login',
    Uri? eventUrl,
  }) async {
    await tester.pumpWidget(
      app(
        TicketOneBrowserScreen(
          eventUrl: eventUrl ?? event,
          accountPath: accountPath,
          controllerFactory: () => controller,
          browserBuilder: (_) => const Text('Website'),
          logger: (line) async {
            logs.add(line);
          },
        ),
      ),
    );
    await tester.pump();
    controller.delegate!.onPageFinished!(controller.current);
    await tester.pump();
  }

  testWidgets(
    'diagnostics include the public event without query or fragment',
    (tester) async {
      final c = TicketController(), logs = <String>[];
      await start(
        tester,
        c,
        logs,
        eventUrl: event.replace(
          query: 'session=PRIVATE_QUERY',
          fragment: 'PRIVATE_FRAGMENT',
        ),
      );
      expect(logs, contains('[TicketOne] event_selected url=$event'));
      expect(logs.join(), isNot(contains('PRIVATE_QUERY')));
      expect(logs.join(), isNot(contains('PRIVATE_FRAGMENT')));
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final path in ['/dashboard/login', '/dashboard/login/register']) {
    testWidgets('$path keeps the controller through login, event and cart', (
      tester,
    ) async {
      final controller = TicketController(), logs = <String>[];
      await start(tester, controller, logs, accountPath: path);
      expect(
        controller.loads.single.path,
        path == '/dashboard/login' ? event.path : path,
      );
      controller.reply();
      await tester.pumpAndSettle();
      expect(
        rows(tester).any((r) => r.id == 'event' || r.id == 'retry'),
        isFalse,
      );
      expect(controller.loads.last, event);
      expect(find.text('Website'), findsOneWidget);
      controller.delegate!.onPageFinished!(controller.current);
      await tester.pump();
      await tester.tap(find.byTooltip('Carrello TicketOne'));
      await tester.pump();
      controller.reply(count: 1, amountMilli: 24000);
      await tester.pumpAndSettle();
      expect(row(tester, 'total').title, contains('24,00'));
      expect(row(tester, 'total').title, isNot(contains('240,00')));
      await row(tester, 'checkout').onActivate!();
      await tester.pump();
      expect(controller.loads.last.path, '/checkout.html');
      expect(controller.loads.last.queryParameters['doc'], 'cart');
      expect(controller.loads.length, path == '/dashboard/login' ? 2 : 3);
      expect(logs, contains('[TicketOne] session_authenticated'));
      expect(logs.join(), isNot(contains(controller.requestId)));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'missing finish after login probes the existing page and resumes the event',
    (tester) async {
      final c = TicketController(), logs = <String>[];
      await start(tester, c, logs, accountPath: '/dashboard/login/register');
      c.current = 'https://www.ticketone.it/dashboard/';
      c.delegate!.onPageStarted!(c.current);
      await tester.pump();
      final loads = c.loads.length;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(
        c.loads.length,
        loads,
      ); // Watchdog only reads; never resubmits login.
      expect(logs.any((l) => l.contains('navigation_recovered')), isTrue);
      c.reply();
      await tester.pump();
      expect(c.loads.last, event);
      expect(logs, contains('[TicketOne] session_continue_event'));
      c.delegate!.onPageFinished!(c.current);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'unfinished document stops the spinner without replaying navigation',
    (tester) async {
      final c = TicketController(), logs = <String>[];
      await start(tester, c, logs);
      c.readyState = 'loading';
      c.delegate!.onPageStarted!(c.current);
      await tester.pump();
      final loads = c.loads.length;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }
      expect(c.loads.length, loads);
      expect(logs.any((l) => l.contains('navigation_timeout')), isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'loading page is checked each second and recovers as soon as ready',
    (tester) async {
      final c = TicketController(), logs = <String>[];
      await start(tester, c, logs);
      c.readyState = 'loading';
      c.delegate!.onPageStarted!(c.current);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(logs.any((l) => l.contains('navigation_timeout')), isFalse);
      expect(logs.any((l) => l.contains('navigation_recovered')), isFalse);
      c.readyState = 'interactive';
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(logs.any((l) => l.contains('navigation_recovered')), isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('revealing website moves focus into it without navigating back', (
    tester,
  ) async {
    final c = TicketController();
    await start(tester, c, []);
    c.reply();
    await tester.pumpAndSettle();
    final before = c.loads.length;
    await row(tester, 'website').onActivate!();
    await tester.pumpAndSettle();
    expect(c.scripts.last, ticketOneWebsiteFocusScript);
    expect(c.loads.length, before);
    expect(find.byTooltip('Modalità accessibile Sonarpad'), findsOneWidget);
    c.delegate!.onPageFinished!(c.current);
    await tester.pumpAndSettle();
    expect(c.scripts.where((s) => s == ticketOneWebsiteFocusScript).length, 2);
  });

  testWidgets('anonymous SPA login is detected later without a new browser', (
    tester,
  ) async {
    final controller = TicketController(), logs = <String>[];
    await start(tester, controller, logs);
    controller.reply(authenticated: false);
    await tester.pumpAndSettle();
    expect(
      controller.loads.last.path,
      '/dashboard/login',
      reason: logs.join(';'),
    );
    controller.delegate!.onPageFinished!(controller.current);
    await tester.pump();
    controller.reply(authenticated: false);
    await tester.pump();
    expect(find.text('Website'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    controller.reply();
    await tester.pumpAndSettle();
    expect(controller.loads.last, event);
    expect(controller.loads.length, 3);
    expect(
      rows(tester).any((r) => r.id == 'event' || r.id == 'retry'),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reopening validates stored session without opening login', (
    tester,
  ) async {
    final logs = <String>[];
    for (var visit = 0; visit < 2; visit++) {
      final controller = TicketController();
      await start(tester, controller, logs);
      expect(controller.loads.single, event);
      expect(controller.probes.single, contains("credentials: 'same-origin'"));
      expect(controller.scripts, contains(ticketOneRemoveAdsScript));
      controller.reply();
      await tester.pumpAndSettle();
      expect(controller.loads.length, 1);
      expect(
        rows(tester).any((r) => r.id == 'event' || r.id == 'retry'),
        isFalse,
      );
      expect(controller.loads.any((u) => u.path.contains('/login')), isFalse);
      await tester.pumpWidget(const SizedBox());
    }
    expect(logs.where((s) => s == '[TicketOne] session_resumed').length, 2);
  });

  testWidgets('403 and timeout stop polling and allow explicit retry', (
    tester,
  ) async {
    final controller = TicketController(), logs = <String>[];
    await start(tester, controller, logs);
    controller.reply(status: 'http', http: 403);
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(controller.probes.length, 1);
    expect(logs, contains('[TicketOne] session_probe_http_403'));
    await tester.tap(find.byTooltip('Carrello TicketOne'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    expect(logs, contains('[TicketOne] session_probe_timeout'));
    expect(rows(tester).any((r) => r.id == 'checkout'), isFalse);
    expect(row(tester, 'status').title, contains('Non riesco'));
    await row(tester, 'retry').onActivate!();
    await tester.pump();
    controller.reply();
    await tester.pumpAndSettle();
    expect(logs, contains('[TicketOne] session_continue_event'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'navigation invalidates old replies and never probes auth provider',
    (tester) async {
      final controller = TicketController();
      await start(tester, controller, []);
      final old = controller.requestId;
      controller.current = 'https://auth.ticketone.it/identity/auth/';
      controller.delegate!.onPageStarted!(controller.current);
      controller.delegate!.onPageFinished!(controller.current);
      controller.reply(id: old);
      await tester.pump();
      await tester.pump(const Duration(seconds: 12));
      expect(controller.probes.length, 1);
      await tester.tap(find.byTooltip('Carrello TicketOne'));
      await tester.pumpAndSettle();
      expect(controller.probes.length, 1);
      expect(rows(tester).any((r) => r.id == 'event'), isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a later anonymous response clears the authenticated state', (
    tester,
  ) async {
    final controller = TicketController();
    await start(tester, controller, []);
    controller.reply();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Carrello TicketOne'));
    await tester.pump();
    controller.reply(authenticated: false);
    await tester.pumpAndSettle();
    expect(row(tester, 'status').title, contains('Accedi'));
    expect(rows(tester).any((r) => r.id == 'event'), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  test('exact origin and cart schema validation', () {
    expect(isTicketOneOrigin('https://www.ticketone.it/dashboard/'), isTrue);
    for (final url in [
      'http://www.ticketone.it/',
      'https://www.ticketone.it.evil.test/',
      'https://www.ticketone.it:444/',
      'https://user@www.ticketone.it/',
      'https://auth.ticketone.it/',
    ]) {
      expect(isTicketOneOrigin(url), isFalse);
    }
    expect(
      TicketOneCart.parse({
        'status': 'ok',
        'authenticated': true,
        'count': 1,
        'amountMilli': 24000,
      })!.amountMilli,
      24000,
    );
    expect(
      TicketOneCart.parse({
        'status': 'ok',
        'authenticated': 'true',
        'count': 1,
        'amountMilli': 24000,
      }),
      isNull,
    );
    expect(
      TicketOneCart.parse({
        'status': 'ok',
        'authenticated': true,
        'count': -1,
        'amountMilli': 24000,
      }),
      isNull,
    );
  });

  testWidgets(
    'utility blank frames work but top-level unsafe navigation is blocked',
    (tester) async {
      final c = TicketController();
      await start(tester, c, []);
      final navigate = c.delegate!.onNavigationRequest!;
      expect(
        await navigate(
          const NavigationRequest(url: 'about:blank', isMainFrame: false),
        ),
        NavigationDecision.navigate,
      );
      expect(
        await navigate(
          const NavigationRequest(url: 'about:blank', isMainFrame: true),
        ),
        NavigationDecision.prevent,
      );
      expect(
        await navigate(
          const NavigationRequest(
            url: 'javascript:alert(1)',
            isMainFrame: true,
          ),
        ),
        NavigationDecision.prevent,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
