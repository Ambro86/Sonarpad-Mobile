import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../l10n/app_localizations.dart';
import '../l10n/ticketone_strings.dart';
import '../services/ticketone_session.dart';
import '../services/ticketone_accessible_script.dart';
import '../utils/app_logger.dart';
import '../widgets/universal_accessible_view.dart';
import 'ticketone_native_page.dart';

/// One controller owns sign-in, event selection, cart and checkout. Never copy
/// browser cookies to a separate HTTP client or infer sign-in from a URL alone.
class TicketOneBrowserScreen extends StatefulWidget {
  const TicketOneBrowserScreen({
    super.key,
    required this.eventUrl,
    this.accountPath,
    this.controllerFactory,
    this.browserBuilder,
    this.logger,
  });
  final Uri eventUrl;
  final String? accountPath;
  final WebViewController Function()? controllerFactory;
  final Widget Function(WebViewController)? browserBuilder;
  final Future<void> Function(String)? logger;

  @override
  State<TicketOneBrowserScreen> createState() => _TicketOneBrowserScreenState();
}

class _TicketOneBrowserScreenState extends State<TicketOneBrowserScreen> {
  WebViewController? _controller;
  final _uiMessages = ValueNotifier<String?>(null);
  final _websiteFocusKey = GlobalKey(debugLabel: 'ticketone-website-focus');
  Timer? _poll, _timeout, _loadWatchdog;
  String? _requestId;
  TicketOneCart? _cart;
  bool _loading = true, _error = false, _checking = false;
  bool _panel = false, _canGoBack = false;
  bool _webOnly = false;
  late bool _waitingForLogin = widget.accountPath != null;
  late bool _resumePending = widget.accountPath == '/dashboard/login';
  int _generation = 0;
  TicketOneStrings get t =>
      TicketOneStrings(AppLocalizations.of(context).localeName);

  void _log(String event) {
    // No URL queries, cookies, tokens, form data or customer identifiers.
    unawaited((widget.logger ?? AppLogger.log)('[TicketOne] $event'));
  }

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      if (!isTicketOneOrigin(widget.eventUrl.toString()) ||
          !widget.eventUrl.path.startsWith('/event/') ||
          (widget.accountPath != null &&
              ![
                '/dashboard/login',
                '/dashboard/login/register',
              ].contains(widget.accountPath))) {
        throw const FormatException('Invalid TicketOne destination');
      }
      // Use the platform's shared persistent WebView store. Do not copy cookies
      // or save an authenticated flag: the server must validate each reopening.
      _panel = _resumePending;
      final controller =
          widget.controllerFactory?.call() ?? WebViewController();
      _controller = controller;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.addJavaScriptChannel(
        'TicketOneSession',
        onMessageReceived: (message) => unawaited(_receive(message.message)),
      );
      // Android injects JavaScript interfaces on the next navigation only.
      // Register once before loading, including when resuming an existing login.
      await controller.addJavaScriptChannel(
        'TicketOneUi',
        onMessageReceived: (message) {
          if (mounted) {
            // Every acknowledgement is an event, including identical payloads.
            _uiMessages.value = null;
            _uiMessages.value = message.message;
          }
        },
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            // The identity and payment providers legitimately use other origins.
            // Session probes below are strictly restricted to www.ticketone.it.
            if (uri != null && uri.scheme == 'https' && uri.userInfo.isEmpty) {
              return NavigationDecision.navigate;
            }
            if (!request.isMainFrame &&
                ['about:blank', 'about:srcdoc'].contains(request.url)) {
              return NavigationDecision.navigate;
            }
            _log(
              'navigation_blocked main=${request.isMainFrame} scheme=${uri?.scheme ?? 'unknown'}',
            );
            return NavigationDecision.prevent;
          },
          onPageStarted: (_) {
            _generation++;
            _invalidateProbe();
            if (mounted) {
              setState(() {
                _loading = true;
                _error = false;
                _cart = null;
              });
            }
            _log('navigation_started generation=$_generation');
            _watchLoading();
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            _loadWatchdog?.cancel();
            setState(() => _loading = false);
            unawaited(_removeAds());
            if (_webOnly && !_panel) _scheduleWebsiteFocus();
            _log(
              isTicketOneOrigin(url)
                  ? 'page_loaded_ticketone'
                  : 'page_loaded_provider',
            );
            final generation = _generation;
            final back = await controller.canGoBack();
            if (!mounted || generation != _generation) return;
            setState(() => _canGoBack = back);
            if (_waitingForLogin && isTicketOneOrigin(url)) {
              await _check();
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              _loadWatchdog?.cancel();
              _invalidateProbe();
              setState(() {
                _loading = false;
                _error = true;
              });
              _log('main_frame_failed');
            }
          },
        ),
      );
      if (!mounted) return;
      setState(() {});
      _watchLoading();
      await controller.loadRequest(
        widget.accountPath == null || _resumePending
            ? widget.eventUrl
            : Uri.https('www.ticketone.it', widget.accountPath!),
      );
      _log('browser_started');
      if (_resumePending) _log('session_resume_started');
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
      _log('browser_start_failed');
    }
  }

  void _invalidateProbe() {
    _poll?.cancel();
    _timeout?.cancel();
    _requestId = null;
    _checking = false;
  }

  void _watchLoading() {
    _loadWatchdog?.cancel();
    final generation = _generation;
    _loadWatchdog = Timer(const Duration(seconds: 12), () async {
      if (!mounted || !_loading || generation != _generation) return;
      try {
        final url = await _controller!.currentUrl().timeout(
          const Duration(seconds: 5),
        );
        final uri = Uri.tryParse(url ?? '');
        final trusted =
            uri != null &&
            uri.scheme == 'https' &&
            uri.userInfo.isEmpty &&
            (!uri.hasPort || uri.port == 443) &&
            ['www.ticketone.it', 'auth.ticketone.it'].contains(uri.host);
        final ready = trusted
            ? await _controller!
                  .runJavaScriptReturningResult('document.readyState')
                  .timeout(const Duration(seconds: 5))
            : null;
        if (!mounted || !_loading || generation != _generation) return;
        final state = '$ready'.replaceAll('"', '');
        if (state == 'interactive' || state == 'complete') {
          setState(() => _loading = false);
          _log('navigation_recovered generation=$generation ready=$state');
          if (_waitingForLogin && isTicketOneOrigin(url)) await _check();
        } else {
          setState(() {
            _loading = false;
            _error = true;
          });
          _log('navigation_timeout generation=$generation');
        }
      } catch (_) {
        if (!mounted || !_loading || generation != _generation) return;
        setState(() {
          _loading = false;
          _error = true;
        });
        _log('navigation_probe_failed generation=$generation');
      }
    });
  }

  Future<void> _check({bool show = false}) async {
    if (!mounted || _checking || _controller == null) return;
    _poll?.cancel();
    setState(() => _checking = true);
    if (show) {
      setState(() {
        _panel = true;
        _cart = null;
      });
    }
    final generation = _generation;
    try {
      final current = await _controller!.currentUrl();
      if (!mounted || generation != _generation) return;
      if (!isTicketOneOrigin(current)) {
        setState(() {
          _checking = false;
          if (show) _error = true;
        });
        _log('session_probe_wrong_origin');
        return;
      }
      final random = Random.secure();
      final id = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      _requestId = id;
      setState(() {
        _checking = true;
        _error = false;
      });
      _timeout = Timer(const Duration(seconds: 10), () {
        if (mounted && _requestId == id) _probeFailed('timeout');
      });
      await _controller!.runJavaScript(ticketOneSessionScript(id));
    } catch (_) {
      if (mounted && generation == _generation) _probeFailed('unavailable');
    }
  }

  void _probeFailed(String reason) {
    _invalidateProbe();
    setState(() {
      _error = true;
      _cart = null;
    });
    _log('session_probe_$reason');
    // Do not retry challenges/denials or mutations. A user can retry explicitly.
  }

  Future<void> _receive(String message) async {
    if (!mounted || !_checking || message.length > 2048) return;
    try {
      final value = jsonDecode(message);
      if (value is! Map<String, dynamic> || value['requestId'] != _requestId) {
        return;
      }
      final id = _requestId;
      final generation = _generation;
      final current = await _controller!.currentUrl();
      if (!mounted ||
          id != _requestId ||
          generation != _generation ||
          !isTicketOneOrigin(current)) {
        return;
      }
      final cart = TicketOneCart.parse(value);
      if (cart == null) {
        final http = value['http'];
        _probeFailed(http is int ? 'http_$http' : 'unexpected');
        return;
      }
      _invalidateProbe();
      if (_resumePending) {
        _resumePending = false;
        if (!cart.authenticated) {
          _log('session_resume_login_required');
          await _navigate(Uri.https('www.ticketone.it', '/dashboard/login'));
          return;
        }
        _log('session_resumed');
      }
      final continueEvent = _waitingForLogin && cart.authenticated;
      setState(() {
        _cart = cart;
        _error = false;
        if (continueEvent) {
          _waitingForLogin = false;
          _panel = false;
        }
      });
      _log(cart.authenticated ? 'session_authenticated' : 'session_anonymous');
      if (continueEvent) {
        _log('session_continue_event');
        final uri = Uri.tryParse(current ?? '');
        if (uri?.path != widget.eventUrl.path) {
          await _navigate(widget.eventUrl);
        }
        return;
      }
      if (_waitingForLogin && !_panel) {
        // Login is a SPA: onPageFinished alone does not report every transition.
        _poll = Timer(const Duration(seconds: 5), () => unawaited(_check()));
      }
    } catch (_) {
      if (mounted) _probeFailed('invalid_response');
    }
  }

  Future<void> _navigate(Uri url) async {
    _invalidateProbe();
    setState(() {
      _panel = false;
      _loading = true;
      _webOnly = false;
      _cart = null;
      _error = false;
    });
    _watchLoading();
    try {
      await _controller?.loadRequest(url);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _showWebsite() {
    setState(() => _webOnly = true);
    _scheduleWebsiteFocus();
    _log('native_website_revealed');
  }

  Future<void> _removeAds() async {
    try {
      await _controller?.runJavaScript(ticketOneRemoveAdsScript);
    } catch (_) {
      _log('website_ad_cleanup_unavailable');
    }
  }

  void _scheduleWebsiteFocus() {
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_webOnly || _panel || generation != _generation) return;
      try {
        await _removeAds();
        if (!mounted || !_webOnly || _panel || generation != _generation) {
          return;
        }
        FocusScope.of(context).unfocus();
        // Hand accessibility to the platform-view container first. DOM focus
        // alone does not move TalkBack away from Flutter's navigation bar.
        _websiteFocusKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
          const FocusSemanticEvent(),
        );
        await _controller?.runJavaScript(ticketOneWebsiteFocusScript);
        _log('native_website_focus_requested');
      } catch (_) {
        _log('native_website_focus_unavailable');
      }
    });
  }

  AccessibleListRow _text(String id, String title) => AccessibleListRow(
    id: id,
    title: title,
    kind: 'text',
    accessibilityButtonTrait: false,
  );
  AccessibleListRow _button(
    String id,
    String title,
    FutureOr<void> Function() action,
  ) => AccessibleListRow(
    id: id,
    title: title,
    kind: 'button',
    onActivate: action,
  );

  @override
  void dispose() {
    _loadWatchdog?.cancel();
    _generation++;
    _invalidateProbe();
    _uiMessages.dispose();
    super.dispose();
  }

  Widget _browser() {
    final controller = _controller!;
    if (widget.browserBuilder != null) {
      return widget.browserBuilder!(controller);
    }
    // The emulator's TalkBack keeps Flutter's Back focus with texture composition
    // even when DOM focus changes. Hybrid composition delivers that focus event.
    if (controller.platform is AndroidWebViewController) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: controller.platform,
          displayWithHybridComposition: true,
        ),
      );
    }
    return WebViewWidget(controller: controller);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), cart = _cart;
    return Scaffold(
      appBar: SonarpadAppBar(
        title: const Text('TicketOne'),
        actions: [
          if (_webOnly)
            IconButton(
              tooltip: t.t('nativeMode'),
              icon: const Icon(Icons.accessibility_new),
              onPressed: () => setState(() => _webOnly = false),
            ),
          IconButton(
            tooltip: t.t('check'),
            onPressed: _checking ? null : () => _check(show: true),
            icon: const Icon(Icons.account_circle),
          ),
          IconButton(
            tooltip: t.t('cart'),
            onPressed: _checking ? null : () => _check(show: true),
            icon: const Icon(Icons.shopping_cart),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_loading && !_panel && _webOnly)
              LinearProgressIndicator(semanticsLabel: l.loading),
            if (_error && !_panel)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(t.t('unavailable')),
              ),
            if (_controller != null)
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ExcludeSemantics(
                      excluding: _panel || !_webOnly,
                      child: ExcludeFocus(
                        excluding: _panel || !_webOnly,
                        child: IgnorePointer(
                          ignoring: _panel || !_webOnly,
                          // Keep the Android platform surface laid out and painted.
                          // The opaque native panel above covers it; Offstage can
                          // leave its accessibility surface with stale geometry.
                          child: Semantics(
                            key: _websiteFocusKey,
                            container: true,
                            explicitChildNodes: true,
                            label: t.t('websiteTitle'),
                            child: _browser(),
                          ),
                        ),
                      ),
                    ),
                    if (!_panel && !_webOnly)
                      ColoredBox(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: TicketOneNativePage(
                          controller: _controller!,
                          messages: _uiMessages,
                          generation: _generation,
                          loading: _loading,
                          log: _log,
                          showWebsite: _showWebsite,
                        ),
                      ),
                    if (_panel)
                      ColoredBox(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: UniversalAccessibleList(
                          key: ValueKey(
                            'ticketone-${_checking ? 'checking' : cart?.authenticated ?? false}-$_error',
                          ),
                          initialFocusId: 'status',
                          padding: const EdgeInsets.all(16),
                          sections: [
                            AccessibleListSection(
                              rows: [
                                _text(
                                  'status',
                                  _checking || _loading
                                      ? l.loading
                                      : _error
                                      ? t.t('unavailable')
                                      : cart?.authenticated == true
                                      ? t.t('signedIn')
                                      : t.t('signedOut'),
                                ),
                                if (!_checking && !_loading) ...[
                                  if (cart != null) ...[
                                    _text(
                                      'count',
                                      cart.count == 0
                                          ? t.t('empty')
                                          : '${t.t('tickets')}: ${cart.count}',
                                    ),
                                    if (cart.count > 0)
                                      _text(
                                        'total',
                                        '${t.t('total')}: ${NumberFormat.currency(locale: l.localeName, name: 'EUR').format(cart.amountMilli / 1000)}',
                                      ),
                                  ],
                                  _text('help', t.t('help')),
                                  if (cart?.authenticated == true)
                                    _button(
                                      'event',
                                      t.t('continue'),
                                      () => _navigate(widget.eventUrl),
                                    ),
                                  if ((cart?.count ?? 0) > 0)
                                    _button(
                                      'checkout',
                                      t.t('checkout'),
                                      () =>
                                          _navigate(
                                            Uri.https(
                                              'www.ticketone.it',
                                              '/checkout.html',
                                              {
                                                'affiliate': 'ITT',
                                                'doc': 'cart',
                                                'language': 'it',
                                              },
                                            ),
                                          ),
                                    ),
                                  _button(
                                    'retry',
                                    l.retry,
                                    () => _check(show: true),
                                  ),
                                ],
                                _button('site', t.t('site'), () {
                                  setState(() => _panel = false);
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: !_panel && _canGoBack
          ? SafeArea(
              child: TextButton.icon(
                onPressed: () => _controller?.goBack(),
                icon: const Icon(Icons.arrow_back),
                label: Text(l.back),
              ),
            )
          : null,
    );
  }
}
