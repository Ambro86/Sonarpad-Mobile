import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../l10n/app_localizations.dart';
import '../l10n/ticketone_strings.dart';
import '../services/ticketone_session.dart';
import '../utils/app_logger.dart';
import '../widgets/universal_accessible_view.dart';

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
  Timer? _poll, _timeout;
  String? _requestId;
  TicketOneCart? _cart;
  bool _loading = true, _error = false, _checking = false;
  bool _panel = false, _canGoBack = false;
  late bool _waitingForLogin = widget.accountPath != null;
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
      final controller =
          widget.controllerFactory?.call() ?? WebViewController();
      _controller = controller;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.addJavaScriptChannel(
        'TicketOneSession',
        onMessageReceived: (message) => unawaited(_receive(message.message)),
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
            _log('navigation_blocked');
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
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            setState(() => _loading = false);
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
      await controller.loadRequest(
        widget.accountPath == null
            ? widget.eventUrl
            : Uri.https('www.ticketone.it', widget.accountPath!),
      );
      _log('browser_started');
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
      setState(() {
        _cart = cart;
        _error = false;
        if (_waitingForLogin && cart.authenticated) {
          _waitingForLogin = false;
          _panel = true;
        }
      });
      _log(cart.authenticated ? 'session_authenticated' : 'session_anonymous');
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
      _cart = null;
      _error = false;
    });
    try {
      await _controller?.loadRequest(url);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
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
    _generation++;
    _invalidateProbe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), cart = _cart;
    return Scaffold(
      appBar: SonarpadAppBar(
        title: const Text('TicketOne'),
        actions: [
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
            if (_loading && !_panel)
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
                      excluding: _panel,
                      child: ExcludeFocus(
                        excluding: _panel,
                        child: IgnorePointer(
                          ignoring: _panel,
                          child: Opacity(
                            opacity: _panel ? 0 : 1,
                            child:
                                widget.browserBuilder?.call(_controller!) ??
                                WebViewWidget(controller: _controller!),
                          ),
                        ),
                      ),
                    ),
                    if (_panel)
                      UniversalAccessibleList(
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
                                _checking
                                    ? l.loading
                                    : _error
                                    ? t.t('unavailable')
                                    : cart?.authenticated == true
                                    ? t.t('signedIn')
                                    : t.t('signedOut'),
                              ),
                              if (!_checking) ...[
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
                                    () => _navigate(
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
