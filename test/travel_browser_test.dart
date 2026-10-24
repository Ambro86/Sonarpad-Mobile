import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:sonarpad_mobile_starter/screens/travel_browser_screen.dart';
import 'package:sonarpad_mobile_starter/services/travel_cookie_script.dart';
import 'package:sonarpad_mobile_starter/services/travel_payment_script.dart';
import 'package:sonarpad_mobile_starter/services/travel_checkout_diagnostics.dart';
import 'travel_screen_test.dart' show app, row;

class BrowserPlatform extends WebViewPlatform {
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => BrowserDelegate(params);
}

class BrowserDelegate extends PlatformNavigationDelegate {
  BrowserDelegate(super.params) : super.implementation();
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {}
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {}
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
}

class BrowserController extends Fake implements WebViewController {
  NavigationDelegate? delegate;
  final scripts = <String>[];
  String bannerStatus = 'banner-closed';
  String paymentStatus = '{"status":"ready","methods":["PayPal","card"]}';
  String current = 'https://www.omio.com/app/booking/test/checkout';
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setNavigationDelegate(NavigationDelegate value) async {
    delegate = value;
  }

  @override
  Future<String?> currentUrl() async => current;
  @override
  Future<bool> canGoBack() async => false;
  @override
  Future<Object> runJavaScriptReturningResult(String script) async {
    scripts.add(script);
    if (script == travelCheckoutDiagnosticsScript) {
      return '{"scope":"checkout","controls":[],"events":[]}';
    }
    if (script == travelNoProtectionScript() ||
        script == travelNoProtectionScript(verifyOnly: true))
      return 'selected';
    if (script == travelPaymentScript()) return paymentStatus;
    if (script == travelPaymentScript(select: 'PayPal')) {
      return '{"status":"selected","methods":["PayPal","card"]}';
    }
    return script == travelCookieBannerStatusScript
        ? bannerStatus
        : 'selected-necessary';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #loadRequest) return Future<void>.value();
    return super.noSuchMethod(invocation);
  }
}

void main() {
  setUp(() {
    WebViewPlatform.instance = BrowserPlatform();
  });
  for (final status in ['banner-closed', 'banner-visible']) {
    testWidgets(
      'cookie log verifies $status instead of assuming clicking worked',
      (tester) async {
        final controller = BrowserController()..bannerStatus = status;
        final logs = <String>[];
        await tester.pumpWidget(
          app(
            TravelBrowserScreen(
              url: controller.current,
              controllerFactory: () => controller,
              browserBuilder: (_) => const SizedBox(),
              logger: (line) async {
                logs.add(line);
              },
            ),
          ),
        );
        await tester.pump();
        controller.delegate!.onPageFinished!(controller.current);
        await tester.pumpAndSettle();
        expect(logs, contains('[Travel] cookies_necessary_selected'));
        expect(logs.any((s) => s.contains('cookie_banner_closed')), isFalse);
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
        }
        expect(
          logs,
          contains(
            status == 'banner-closed'
                ? '[Travel] cookie_banner_closed'
                : '[Travel] cookie_banner_still_visible',
          ),
        );
        expect(logs.join(' '), isNot(contains(controller.current)));
        expect(
          controller.scripts
              .where((s) => s == travelNecessaryCookiesScript)
              .length,
          1,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  test('only exact HTTPS Omio origins can open the travel browser', () {
    expect(isTravelOmioUrl('https://www.omio.com/app/booking/example'), isTrue);
    for (final url in [
      'http://www.omio.com/',
      'https://www.omio.com.example.org/',
      'https://user@omio.com/',
      'javascript:alert(1)',
      'https://omio.com:8080/',
    ]) {
      expect(isTravelOmioUrl(url), isFalse);
    }
  });
  testWidgets('embedded browser loads and limits consent automation to Omio', (
    tester,
  ) async {
    final controller = BrowserController();
    await tester.pumpWidget(
      app(
        TravelBrowserScreen(
          url: controller.current,
          controllerFactory: () => controller,
          browserBuilder: (_) => const SizedBox(key: Key('embedded-browser')),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('embedded-browser')), findsOneWidget);
    controller.delegate!.onPageFinished!(controller.current);
    await tester.pumpAndSettle();
    expect(
      controller.scripts,
      unorderedEquals([travelNecessaryCookiesScript, travelPaymentScript()]),
    );
    expect(
      await controller.delegate!.onNavigationRequest!(
        NavigationRequest(
          url: 'https://www.paypal.com/checkout',
          isMainFrame: true,
        ),
      ),
      NavigationDecision.navigate,
    );
    controller.current = 'https://www.paypal.com/checkout';
    controller.delegate!.onPageStarted!(controller.current);
    controller.delegate!.onPageFinished!(controller.current);
    await tester.pumpAndSettle();
    expect(controller.scripts.length, 2);
    expect(
      await controller.delegate!.onNavigationRequest!(
        NavigationRequest(url: 'javascript:alert(1)', isMainFrame: true),
      ),
      NavigationDecision.prevent,
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('native payment choice hides browser until explicit selection', (
    tester,
  ) async {
    final controller = BrowserController();
    final logs = <String>[];
    await tester.pumpWidget(
      app(
        TravelBrowserScreen(
          url: controller.current,
          controllerFactory: () => controller,
          browserBuilder: (_) => const Text('Provider page'),
          logger: (line) async {
            logs.add(line);
          },
        ),
      ),
    );
    await tester.pump();
    controller.delegate!.onPageFinished!(controller.current);
    await tester.pumpAndSettle();
    expect(find.text('PayPal'), findsOneWidget);
    final hidden = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.text('Provider page'),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(hidden.opacity, 0);
    expect(row(tester, 'payment-no-protection').toggleValue, isTrue);
    expect(controller.scripts, isNot(contains(travelNoProtectionScript())));
    expect(
      controller.scripts,
      isNot(contains(travelPaymentScript(select: 'PayPal'))),
    );
    await tester.tap(find.text('PayPal'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('PayPal'), findsNothing);
    expect(
      controller.scripts
          .where((s) => s == travelPaymentScript(select: 'PayPal'))
          .length,
      1,
    );
    expect(logs, contains('[Travel] payment_method_selected'));
    expect(logs.any((s) => s.contains('stage=before-selection')), isTrue);
    expect(logs.any((s) => s.contains('stage=after-protection-click')), isTrue);
    expect(logs.any((s) => s.contains('stage=after-payment-click')), isTrue);
    expect(logs.any((s) => s.contains('stage=browser-revealed')), isTrue);
    expect(
      controller.scripts,
      containsAllInOrder([
        travelNoProtectionScript(),
        travelPaymentScript(select: 'PayPal'),
        travelNoProtectionScript(verifyOnly: true),
      ]),
    );
    expect(logs.join(), isNot(contains(controller.current)));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('disabling no protection leaves Omio insurance unchanged', (
    tester,
  ) async {
    final controller = BrowserController();
    await tester.pumpWidget(
      app(
        TravelBrowserScreen(
          url: controller.current,
          controllerFactory: () => controller,
          browserBuilder: (_) => const SizedBox(),
          logger: (_) async {},
        ),
      ),
    );
    await tester.pump();
    controller.delegate!.onPageFinished!(controller.current);
    await tester.pumpAndSettle();
    row(tester, 'payment-no-protection').onValueChanged!(false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PayPal'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.scripts, isNot(contains(travelNoProtectionScript())));
    expect(
      controller.scripts,
      isNot(contains(travelNoProtectionScript(verifyOnly: true))),
    );
    expect(controller.scripts, contains(travelPaymentScript(select: 'PayPal')));
    await tester.pumpWidget(const SizedBox());
  });
}
