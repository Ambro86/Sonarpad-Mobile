import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../l10n/app_localizations.dart';
import '../l10n/travel_strings.dart';
import '../services/travel_cookie_script.dart';
import '../services/travel_payment_script.dart';
import '../utils/app_logger.dart';
import '../widgets/universal_accessible_view.dart';

bool isTravelOmioUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      uri.scheme == 'https' &&
      ['omio.com', 'www.omio.com'].contains(uri.host) &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443);
}

Future<void> openTravelBrowser(BuildContext context, String url) async {
  if (!isTravelOmioUrl(url)) throw const FormatException('Invalid travel URL');
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => TravelBrowserScreen(url: url)),
  );
}

/// A real embedded browser, without the news reader's extraction or accept-all scripts.
class TravelBrowserScreen extends StatefulWidget {
  const TravelBrowserScreen({
    super.key,
    required this.url,
    this.controllerFactory,
    this.browserBuilder,
    this.logger,
  });
  final String url;
  @visibleForTesting
  final Future<void> Function(String)? logger;
  @visibleForTesting
  final WebViewController Function()? controllerFactory;
  @visibleForTesting
  final Widget Function(WebViewController)? browserBuilder;
  @override
  State<TravelBrowserScreen> createState() => _TravelBrowserScreenState();
}

class _TravelBrowserScreenState extends State<TravelBrowserScreen> {
  Future<void> _log(String message) =>
      (widget.logger ?? AppLogger.log)(message);
  WebViewController? _controller;
  Timer? _cookieTimer;
  int _generation = 0;
  int? _cookieRunGeneration, _cookieSelectedGeneration;
  bool _loading = true, _error = false, _canGoBack = false;
  bool _cookieVerificationPending = false;
  bool _showBrowser = false, _paymentBusy = false;
  bool _noProtection = true;
  bool _paymentUnavailable = false;
  List<String> _paymentMethods = [];
  Timer? _paymentTimer;
  TravelStrings get t => TravelStrings(AppLocalizations.of(context).localeName);

  @override
  void initState() {
    super.initState();
    _showBrowser = !Uri.parse(widget.url).path.endsWith('/checkout');
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      if (!isTravelOmioUrl(widget.url)) {
        throw const FormatException('Invalid travel URL');
      }
      final controller =
          widget.controllerFactory?.call() ?? WebViewController();
      _controller = controller;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            // Payment providers may redirect to their own HTTPS pages. Cookie automation
            // is still restricted independently to the exact Omio origin.
            if (uri != null && uri.scheme == 'https' && uri.userInfo.isEmpty) {
              return NavigationDecision.navigate;
            }
            if (request.isMainFrame && mounted) setState(() => _error = true);
            return NavigationDecision.prevent;
          },
          onPageStarted: (_) {
            _paymentTimer?.cancel();
            _paymentMethods = [];
            if (_cookieVerificationPending) {
              unawaited(_log('[Travel] cookie_verification_interrupted'));
              _cookieVerificationPending = false;
            }
            _generation++;
            _cookieTimer?.cancel();
            if (mounted) {
              setState(() {
                _loading = true;
                _error = false;
              });
            }
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() => _loading = false);
            unawaited(_updateBack());
            if (isTravelOmioUrl(url)) {
              unawaited(_necessaryCookies(_generation, 0));
            }
            if (!_showBrowser && isTravelOmioUrl(url)) {
              unawaited(_readPaymentMethods(_generation, 0));
            } else if (!_showBrowser) {
              _revealBrowser();
            }
            unawaited(_log('[Travel] browser_page_loaded'));
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _error = true;
                _loading = false;
              });
              unawaited(_log('[Travel] browser_load_failed'));
            }
          },
        ),
      );
      if (!mounted) return;
      setState(() {});
      await controller.loadRequest(Uri.parse(widget.url));
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
      unawaited(_log('[Travel] browser_start_failed'));
    }
  }

  Future<void> _updateBack() async {
    try {
      final canGoBack = await _controller!.canGoBack();
      if (mounted) setState(() => _canGoBack = canGoBack);
    } catch (_) {
      /* Navigation controls remain usable via the page. */
    }
  }

  Future<Map<String, dynamic>> _paymentScript({String? select}) async {
    dynamic value = await _controller!.runJavaScriptReturningResult(
      travelPaymentScript(select: select),
    );
    // Android may return a JSON-encoded string; iOS returns the string itself.
    for (var i = 0; i < 2 && value is String; i++) {
      value = jsonDecode(value);
    }
    return Map<String, dynamic>.from(value as Map);
  }

  Future<void> _readPaymentMethods(int generation, int attempt) async {
    if (!mounted || _showBrowser || generation != _generation) return;
    try {
      final data = await _paymentScript();
      if (!mounted || _showBrowser || generation != _generation) return;
      final methods = List<String>.from(data['methods'] as List);
      if (methods.isNotEmpty) {
        setState(() => _paymentMethods = methods);
        unawaited(
          _log('[Travel] payment_methods_available count=${methods.length}'),
        );
        return;
      }
    } catch (_) {
      // No speculative controls if the provider markup is unrecognized.
    }
    if (!mounted || _showBrowser || generation != _generation) return;
    if (attempt < 14) {
      _paymentTimer = Timer(
        const Duration(seconds: 1),
        () => unawaited(_readPaymentMethods(generation, attempt + 1)),
      );
    } else {
      setState(() => _paymentUnavailable = true);
      unawaited(_log('[Travel] payment_methods_unavailable'));
    }
  }

  Future<void> _selectPayment(String method) async {
    if (_paymentBusy) return;
    setState(() => _paymentBusy = true);
    var confirmed = false;
    var protectionConfirmed = !_noProtection;
    try {
      if (_noProtection) {
        await _controller!.runJavaScriptReturningResult(
          travelNoProtectionScript(),
        );
      }
      final data = await _paymentScript(select: method);
      confirmed = data['status'] == 'selected';
      if (_noProtection) {
        final result = await _controller!.runJavaScriptReturningResult(
          travelNoProtectionScript(verifyOnly: true),
        );
        protectionConfirmed =
            result.toString().replaceAll('"', '') == 'selected';
      }
    } catch (_) {
      // The original page remains available even after a provider change.
    }
    unawaited(
      _log(
        confirmed
            ? '[Travel] payment_method_selected'
            : '[Travel] payment_method_selection_unconfirmed',
      ),
    );
    if (_noProtection) {
      unawaited(
        _log(
          protectionConfirmed
              ? '[Travel] no_protection_selected'
              : '[Travel] no_protection_unconfirmed',
        ),
      );
    }
    if (!mounted) return;
    _revealBrowser();
    if (!confirmed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.t('paymentSelectOnSite'))));
    }
    if (!protectionConfirmed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.t('noProtectionUnconfirmed'))));
    }
  }

  void _revealBrowser() {
    _paymentTimer?.cancel();
    setState(() {
      _paymentBusy = false;
      _showBrowser = true;
    });
  }

  Future<void> _necessaryCookies(int generation, int attempt) async {
    if (!mounted || generation != _generation || _controller == null) return;
    if (_cookieRunGeneration == generation ||
        _cookieSelectedGeneration == generation) {
      return;
    }
    _cookieRunGeneration = generation;
    try {
      final url = await _controller!.currentUrl();
      if (!mounted ||
          generation != _generation ||
          url == null ||
          !isTravelOmioUrl(url)) {
        return;
      }
      final result = (await _controller!.runJavaScriptReturningResult(
        travelNecessaryCookiesScript,
      )).toString().replaceAll('"', '');
      if (!mounted || generation != _generation) return;
      if (result == 'selected-necessary') {
        _cookieSelectedGeneration = generation;
        _cookieTimer?.cancel();
        unawaited(_log('[Travel] cookies_necessary_selected'));
        _cookieVerificationPending = true;
        _cookieTimer = Timer(
          const Duration(seconds: 1),
          () => unawaited(_verifyCookieBanner(generation, 0)),
        );
        return;
      }
      if (!['action-not-found', 'banner-not-found'].contains(result)) return;
      if (attempt < 5) {
        _cookieTimer?.cancel();
        _cookieTimer = Timer(
          const Duration(seconds: 1),
          () => unawaited(_necessaryCookies(generation, attempt + 1)),
        );
      } else {
        unawaited(
          _log(
            result == 'action-not-found'
                ? '[Travel] cookie_banner_visible_action_not_found'
                : '[Travel] cookie_banner_not_found',
          ),
        );
      }
    } catch (_) {
      unawaited(_log('[Travel] cookie_action_failed'));
    } finally {
      if (_cookieRunGeneration == generation) _cookieRunGeneration = null;
    }
  }

  Future<void> _verifyCookieBanner(int generation, int attempt) async {
    if (!mounted || generation != _generation) return;
    try {
      final result = (await _controller!.runJavaScriptReturningResult(
        travelCookieBannerStatusScript,
      )).toString().replaceAll('"', '');
      if (!mounted || generation != _generation) return;
      if (result == 'banner-visible' && attempt < 2) {
        _cookieTimer = Timer(
          const Duration(seconds: 1),
          () => unawaited(_verifyCookieBanner(generation, attempt + 1)),
        );
        return;
      }
      _cookieVerificationPending = false;
      final outcome = switch (result) {
        'banner-closed' => 'cookie_banner_closed',
        'banner-visible' => 'cookie_banner_still_visible',
        _ => 'cookie_verification_unavailable',
      };
      unawaited(_log('[Travel] $outcome'));
    } catch (_) {
      _cookieVerificationPending = false;
      unawaited(_log('[Travel] cookie_verification_failed'));
    }
  }

  Future<void> _external() async {
    try {
      final current = await _controller?.currentUrl();
      final uri = Uri.parse(current ?? widget.url);
      if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) return;
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const FormatException('Browser unavailable');
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    if (_cookieVerificationPending) {
      unawaited(_log('[Travel] cookie_verification_interrupted'));
    }
    _generation++;
    _paymentTimer?.cancel();
    _cookieTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SonarpadAppBar(
      title: Text(t.t('omioBrowser')),
      actions: [
        IconButton(
          tooltip: t.t('externalBrowser'),
          onPressed: _external,
          icon: const Icon(Icons.open_in_browser),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (_loading)
            LinearProgressIndicator(semanticsLabel: t.t('browserLoading')),
          if (_error)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(t.t('browserError')),
            ),
          if (_controller != null)
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ExcludeSemantics(
                    excluding: !_showBrowser,
                    child: ExcludeFocus(
                      excluding: !_showBrowser,
                      child: IgnorePointer(
                        ignoring: !_showBrowser,
                        child: Opacity(
                          opacity: _showBrowser ? 1 : 0,
                          child:
                              widget.browserBuilder?.call(_controller!) ??
                              WebViewWidget(controller: _controller!),
                        ),
                      ),
                    ),
                  ),
                  if (!_showBrowser)
                    UniversalAccessibleList(
                      padding: const EdgeInsets.all(20),
                      sections: [
                        AccessibleListSection(
                          rows: [
                            AccessibleListRow(
                              id: 'payment-title',
                              title: t.t('paymentChoice'),
                              kind: 'text',
                              accessibilityButtonTrait: false,
                            ),
                            AccessibleListRow(
                              id: 'payment-help',
                              title: t.t('paymentChoiceHelp'),
                              kind: 'text',
                              accessibilityButtonTrait: false,
                            ),
                            AccessibleListRow(
                              id: 'payment-no-protection',
                              title: t.t('noProtection'),
                              kind: 'toggle',
                              toggleValue: _noProtection,
                              enabled: !_paymentBusy,
                              onValueChanged: (value) {
                                if (!_paymentBusy && value is bool) {
                                  setState(() => _noProtection = value);
                                }
                              },
                            ),
                            if (_paymentMethods.isEmpty)
                              AccessibleListRow(
                                id: 'payment-status',
                                title: t.t(
                                  _paymentUnavailable || _error
                                      ? 'paymentUnavailable'
                                      : 'browserLoading',
                                ),
                                kind: 'text',
                                accessibilityButtonTrait: false,
                              ),
                            for (final method in _paymentMethods)
                              AccessibleListRow(
                                id: 'payment-$method',
                                title: method == 'card'
                                    ? t.t('paymentCard')
                                    : method,
                                kind: 'button',
                                enabled: !_paymentBusy,
                                onActivate: () => _selectPayment(method),
                              ),
                            AccessibleListRow(
                              id: 'payment-open-site',
                              title: t.t('paymentOpenSite'),
                              kind: 'button',
                              onActivate: _revealBrowser,
                            ),
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
    bottomNavigationBar: _showBrowser && _canGoBack
        ? SafeArea(
            child: TextButton.icon(
              onPressed: () async {
                await _controller?.goBack();
                await _updateBack();
              },
              icon: const Icon(Icons.arrow_back),
              label: Text(t.t('webBack')),
            ),
          )
        : null,
  );
}
