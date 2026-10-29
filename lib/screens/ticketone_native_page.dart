import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../l10n/app_localizations.dart';
import '../l10n/ticketone_strings.dart';
import '../services/ticketone_accessible_script.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

/// Native presentation of controls observed on the current TicketOne page.
/// The WebView stays mounted behind this widget and owns every site operation.
class TicketOneNativePage extends StatefulWidget {
  const TicketOneNativePage({
    super.key,
    required this.controller,
    required this.generation,
    required this.loading,
    required this.showWebsite,
    required this.log,
  });
  final WebViewController controller;
  final int generation;
  final bool loading;
  final VoidCallback showWebsite;
  final void Function(String) log;
  @override
  State<TicketOneNativePage> createState() => _TicketOneNativePageState();
}

class _TicketOneNativePageState extends State<TicketOneNativePage> {
  final _focus = AccessibleListController(debugName: 'ticketone-form');
  final Map<String, dynamic> _draft = {};
  Map<String, dynamic>? _page;
  Timer? _timer;
  String? _message, _pending;
  bool _busy = true;
  int _serial = 0, _attempt = 0;
  TicketOneStrings get t =>
      TicketOneStrings(AppLocalizations.of(context).localeName);
  List<Map<String, dynamic>> get _fields =>
      (_page?['fields'] as List? ?? []).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get _actions =>
      (_page?['actions'] as List? ?? []).cast<Map<String, dynamic>>();

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      // The WebView survives the account panel and website/native switches.
      // iOS rejects registering the same channel again on that controller.
      await widget.controller.removeJavaScriptChannel('TicketOneUi');
      if (!mounted) return;
      await widget.controller.addJavaScriptChannel(
        'TicketOneUi',
        onMessageReceived: (m) => unawaited(_receive(m.message)),
      );
      if (mounted && !widget.loading) await _read();
    } catch (_) {
      if (mounted) _unavailable('channel_failed');
    }
  }

  @override
  void didUpdateWidget(covariant TicketOneNativePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation ||
        oldWidget.loading != widget.loading) {
      _serial++;
      _timer?.cancel();
      _pending = null;
      _draft.clear();
      _page = null;
      _message = null;
      _busy = true;
      _attempt = 0;
      if (!widget.loading) unawaited(_read());
    }
  }

  Future<void> _read() async {
    if (!mounted || widget.loading) return;
    final serial = ++_serial;
    try {
      final current = Uri.tryParse(await widget.controller.currentUrl() ?? '');
      if (!mounted || serial != _serial) return;
      if (current == null ||
          current.scheme != 'https' ||
          current.userInfo.isNotEmpty ||
          !['www.ticketone.it', 'auth.ticketone.it'].contains(current.host) ||
          (current.hasPort && current.port != 443)) {
        _unavailable('foreign');
        return;
      }
      dynamic value = await widget.controller.runJavaScriptReturningResult(
        ticketOneUiSnapshotScript,
      );
      for (var i = 0; i < 2 && value is String; i++) {
        value = jsonDecode(value);
      }
      if (!mounted || serial != _serial) return;
      if (value is! Map<String, dynamic> || value['status'] != 'ready') {
        if (value is Map && value['status'] == 'waiting' && _attempt++ < 12) {
          _timer = Timer(const Duration(seconds: 1), () => unawaited(_read()));
          return;
        }
        _unavailable('unsupported');
        return;
      }
      final fields = value['fields'], actions = value['actions'];
      if (fields is! List ||
          actions is! List ||
          fields.length > 60 ||
          actions.length > 30 ||
          value['revision'] is! String ||
          !['login', 'event', 'checkout', 'review'].contains(value['stage'])) {
        _unavailable('schema');
        return;
      }
      if (value['title'] is! String ||
          fields.any(
            (f) =>
                f is! Map<String, dynamic> ||
                f['id'] is! String ||
                f['label'] is! String ||
                f['enabled'] is! bool ||
                !['text', 'select', 'checkbox', 'radio'].contains(f['kind']) ||
                f['options'] is! List ||
                (f['options'] as List).any(
                  (o) =>
                      o is! Map ||
                      o['value'] is! String ||
                      o['label'] is! String,
                ),
          ) ||
          actions.any(
            (a) =>
                a is! Map<String, dynamic> ||
                a['id'] is! String ||
                a['label'] is! String ||
                a['enabled'] is! bool ||
                a['submit'] is! bool,
          )) {
        _unavailable('controls_schema');
        return;
      }
      setState(() {
        _page = value;
        _busy = false;
      });
      widget.log(
        'native_page_${value['stage']} fields=${fields.length} actions=${actions.length}',
      );
    } catch (_) {
      if (mounted && serial == _serial) _unavailable('read_failed');
    }
  }

  void _unavailable(String reason) {
    setState(() {
      _busy = false;
      _page = null;
      _message = t.t(
        reason == 'action_timeout_no_retry'
            ? 'actionUncertain'
            : 'nativeUnavailable',
      );
    });
    widget.log('native_$reason');
  }

  Future<void> _act(String action, {int? quantity, bool submit = false}) async {
    if (_busy || _page == null) return;
    final revision = _page!['revision'];
    final id = '${widget.generation}-${++_serial}';
    _pending = id;
    _timer?.cancel();
    final values = Map<String, dynamic>.from(_draft);
    setState(() {
      _busy = true;
      _message = null;
    });
    _timer = Timer(const Duration(seconds: 12), () {
      if (mounted && _pending == id) {
        _pending = null;
        _draft.removeWhere(
          (id, _) => _fields.any((f) => f['id'] == id && f['secret'] == true),
        );
        _unavailable('action_timeout_no_retry');
      }
    });
    try {
      await widget.controller.runJavaScript(
        ticketOneUiActionScript({
          'revision': revision,
          'action': action,
          'values': values,
          'acceptCookies': submit,
          'quantity': ?quantity,
        }, id),
      );
      widget.log('native_action_dispatched');
    } catch (_) {
      if (mounted && _pending == id) {
        _pending = null;
        _timer?.cancel();
        _unavailable('action_failed');
      }
    }
  }

  Future<void> _receive(String text) async {
    if (!mounted || _pending == null || text.length > 2048) return;
    try {
      final v = jsonDecode(text);
      if (v is! Map || v['id'] != _pending) return;
      final id = _pending;
      final current = Uri.tryParse(await widget.controller.currentUrl() ?? '');
      if (!mounted ||
          id != _pending ||
          current == null ||
          current.scheme != 'https' ||
          current.userInfo.isNotEmpty ||
          (current.hasPort && current.port != 443) ||
          !['www.ticketone.it', 'auth.ticketone.it'].contains(current.host)) {
        return;
      }
      _pending = null;
      _timer?.cancel();
      final status = v['status'];
      if (status == 'submitted' || status == 'changed') {
        // Navigation may destroy the JS callback. Never submit twice to recover it.
        _draft.clear();
        _attempt = 0;
        _timer = Timer(
          const Duration(milliseconds: 500),
          () => unawaited(_read()),
        );
        widget.log(
          status == 'submitted'
              ? 'native_action_submitted'
              : 'native_control_changed',
        );
      } else if (status == 'invalid' && v['field'] is String) {
        final id = v['field'] as String;
        final field = _fields.where((f) => f['id'] == id).firstOrNull;
        setState(() {
          _busy = false;
          _message = '${t.t('invalidField')} ${field?['label'] ?? ''}';
        });
        announceStatusMessage(context, _message!);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(
              _focus.focusAccessibleRow(
                id,
                mode: AccessibleFocusMode.screenEntry,
              ),
            );
          }
        });
        widget.log('native_validation_failed');
      } else {
        setState(() {
          _busy = false;
          _message =
              status == 'cookies-visible' || status == 'cookies-unavailable'
              ? t.t('cookiesFailed')
              : t.t('nativeUnavailable');
          if (status != 'cookies-visible' && status != 'cookies-unavailable') {
            _page = null;
          }
        });
        widget.log(
          status == 'stale'
              ? 'native_page_changed_before_action'
              : 'native_action_not_confirmed',
        );
      }
    } catch (_) {
      _unavailable('invalid_ack');
    }
  }

  AccessibleListRow _text(String id, String text) => AccessibleListRow(
    id: id,
    title: text,
    kind: 'text',
    accessibilityButtonTrait: false,
  );
  AccessibleListRow _button(
    String id,
    String text,
    FutureOr<void> Function() run,
  ) => AccessibleListRow(
    id: id,
    title: text,
    kind: 'button',
    onActivate: run,
    finishEditingOnActivate: true,
  );
  AccessibleListRow _field(Map<String, dynamic> f) {
    final id = f['id'] as String, label = f['label'] as String;
    final value = _draft[id] ?? f['value'];
    final enabled = f['enabled'] == true;
    if (!enabled && f['kind'] == 'text') {
      return _text(id, '$label: ${value ?? ''}');
    }
    if (f['kind'] == 'checkbox' || f['kind'] == 'radio') {
      return AccessibleListRow(
        id: id,
        title: label,
        kind: 'toggle',
        toggleValue: value == true,
        enabled: enabled,
        onValueChanged: (v) {
          if (f['kind'] == 'radio' && v != true) return;
          _draft[id] = v == true;
          unawaited(_act('change'));
        },
      );
    }
    if (f['kind'] == 'select') {
      final options = (f['options'] as List).cast<Map<String, dynamic>>();
      if (options.isEmpty) return _text(id, label);
      final index = options
          .indexWhere((o) => o['value'] == value)
          .clamp(0, options.length - 1);
      return AccessibleListRow(
        id: id,
        title: label,
        kind: 'slider',
        enabled: enabled,
        value: '$index',
        valueLabel: options[index]['label'] as String,
        sliderValue: index.toDouble(),
        sliderMin: 0,
        sliderMax: (options.length - 1).toDouble(),
        sliderStep: 1,
        sliderIncreasedValueLabel:
            options[(index + 1).clamp(0, options.length - 1)]['label']
                as String,
        sliderDecreasedValueLabel:
            options[(index - 1).clamp(0, options.length - 1)]['label']
                as String,
        onValueChanged: (v) {
          final n = double.tryParse('$v');
          if (n == null || !n.isFinite) return;
          _draft[id] = options[n.round().clamp(0, options.length - 1)]['value'];
          unawaited(_act('change'));
        },
      );
    }
    return AccessibleListRow(
      id: id,
      title: label,
      kind: 'textField',
      value: '${value ?? ''}',
      enabled: enabled,
      secure: f['type'] == 'password',
      keyboardType: f['keyboard'] is String
          ? f['keyboard'] as String
          : f['type'] == 'email'
          ? 'email'
          : f['type'] == 'tel'
          ? 'phone'
          : f['type'] == 'number' ||
                f['secret'] == true && f['type'] != 'password'
          ? 'number'
          : null,
      onValueChanged: (v) => _draft[id] = v?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _serial++;
    _timer?.cancel();
    _draft.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final qty = _page?['quantity'];
    final rows = <AccessibleListRow>[
      if (_busy)
        _text('loading', l.loading)
      else ...[
        if (_message != null) _text('message', _message!),
        if (_page != null) ...[
          _text('heading', '${_page!['title']}'),
          if (_page!['stage'] == 'event' && qty is Map)
            _text('best-seat-help', t.t('bestSeatHelp')),
          for (final item in (_page!['summary'] as List? ?? []))
            _text('summary-${item.hashCode}', '$item'),
          for (final e in (_page!['errors'] as List? ?? []))
            _text('error-${e.hashCode}', '$e'),
          for (final f in _fields) ...[
            _field(f),
            if (f['hint'] is String && (f['hint'] as String).isNotEmpty)
              _text('${f['id']}-hint', f['hint'] as String),
          ],
          if (qty is Map &&
              qty['value'] is num &&
              qty['min'] is num &&
              qty['max'] is num &&
              qty['min'] >= 1 &&
              qty['max'] >= qty['min'] &&
              qty['max'] <= 100 &&
              qty['value'] >= qty['min'] &&
              qty['value'] <= qty['max'])
            AccessibleListRow(
              id: 'quantity',
              title: t.t('tickets'),
              kind: 'slider',
              value: '${qty['value']}',
              valueLabel: '${qty['value']}',
              sliderValue: (qty['value'] as num).toDouble(),
              sliderMin: (qty['min'] as num).toDouble(),
              sliderMax: (qty['max'] as num).toDouble(),
              sliderStep: 1,
              onValueChanged: (v) {
                final n = double.tryParse('$v');
                if (n != null && n.isFinite) {
                  unawaited(_act('quantity', quantity: n.round()));
                }
              },
            ),
          for (final n in (_page!['notices'] as List? ?? []))
            _text('notice-${n.hashCode}', '$n'),
          _text('consent', t.t('cookieConsent')),
          for (final a in _actions)
            AccessibleListRow(
              id: a['id'] as String,
              title: a['label'] as String,
              kind: 'button',
              enabled: a['enabled'] == true,
              finishEditingOnActivate: true,
              onActivate: () =>
                  _act(a['id'] as String, submit: a['submit'] == true),
            ),
        ],
        if (_page == null || _message != null)
          _button('refresh', l.retry, () {
            setState(() {
              _busy = true;
              _page = null;
              _message = null;
            });
            _draft.clear();
            _attempt = 0;
            return _read();
          }),
      ],
      _button(
        'website',
        _page?['paypal'] == true ? t.t('paypalContinue') : t.t('site'),
        widget.showWebsite,
      ),
    ];
    return UniversalAccessibleList(
      controller: _focus,
      key: ValueKey(
        'ticketone-native-${widget.generation}-${_busy ? 'loading' : _page?['stage'] ?? 'unavailable'}',
      ),
      initialFocusId: _busy
          ? 'loading'
          : _message != null
          ? 'message'
          : _page == null
          ? 'refresh'
          : _fields.isNotEmpty
          ? _fields.first['id'] as String
          : 'heading',
      padding: const EdgeInsets.all(16),
      sections: [AccessibleListSection(rows: rows)],
    );
  }
}
