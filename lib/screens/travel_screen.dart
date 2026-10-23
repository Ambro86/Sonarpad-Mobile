import 'dart:async';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:sealed_countries/sealed_countries.dart';
import '../l10n/app_localizations.dart';
import '../l10n/travel_strings.dart';
import '../services/travel_service.dart';
import '../utils/app_logger.dart';
import '../utils/country_name_helper.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';
import 'travel_browser_screen.dart';

part 'travel_passengers.dart';

TravelStrings _strings(BuildContext context) =>
    TravelStrings(AppLocalizations.of(context).localeName);
AccessibleListRow _action(
  String id,
  String title,
  FutureOr<void> Function() action, {
  bool enabled = true,
  String? subtitle,
}) => AccessibleListRow(
  id: id,
  title: title,
  subtitle: subtitle,
  kind: 'button',
  enabled: enabled,
  onActivate: action,
);
AccessibleListRow _info(String id, String text) => AccessibleListRow(
  id: id,
  title: text,
  kind: 'text',
  accessibilityButtonTrait: false,
);
Widget _page(String title, List<AccessibleListRow> rows) => Scaffold(
  appBar: SonarpadAppBar(title: Text(title)),
  body: SafeArea(
    child: UniversalAccessibleList(
      sections: [AccessibleListSection(rows: rows)],
      padding: const EdgeInsets.all(16),
    ),
  ),
);
String _error(TravelStrings t, Object e) {
  var key = 'error';
  if (e is TravelException) {
    if (e.code == 'configuration') key = 'configuration';
    if (e.status == 401 || e.status == 410) key = 'expired';
    return '${t.t(key)}${e.reference == null ? '' : ' ${t.t('reference')}: ${e.reference}'}';
  }
  return t.t(key);
}

String _plain(dynamic s) =>
    html
        .parseFragment(
          '$s'.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n'),
        )
        .text ??
    '';
String _money(dynamic value, String currency, TravelStrings t) {
  if (value is Map) {
    currency = value['currency']?.toString() ?? currency;
    value = value['valueInCents'] ?? value['lowestUnitValue'];
  }
  return value is num
      ? NumberFormat.currency(
          locale: t.locale,
          name: currency,
          symbol: currency,
          decimalDigits: 2,
        ).format(value / 100)
      : t.t('priceUnavailable');
}

String _fareDetails(Map<String, dynamic> offer) {
  final details = <String>{};
  void add(Object? value) {
    if (value is! String) return;
    final text = _plain(value).trim();
    if (text.isNotEmpty) details.add(text);
  }

  for (final amenity in offer['amenities'] as List? ?? []) {
    if (amenity is Map) add(amenity['name']);
  }
  for (final fare in offer['fare'] as List? ?? []) {
    if (fare is Map) {
      add(fare['description']);
      add(fare['cancellationDescription']);
    }
  }
  return details.join('\n');
}

String _time(dynamic value, TravelStrings t) {
  // Preserve station-local wall time from the provider; do not convert to phone timezone.
  final raw = value?.toString() ?? '';
  final match = RegExp(r'^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})').firstMatch(raw);
  if (match == null) return raw;
  final d = DateTime.tryParse(match[1]!);
  return d == null ? raw : '${DateFormat.yMd(t.locale).format(d)} ${match[2]}';
}

String _journey(Map<String, dynamic> item, String currency, TravelStrings t) =>
    '${_time(item['departureTime'], t)} – ${_time(item['arrivalTime'], t)}. '
    '${item['departureStationName'] ?? ''} – ${item['arrivalStationName'] ?? ''}. '
    '${item['carrierCode'] ?? ''}. ${_money(item['totalPrice'] ?? item['price'], item['currency']?.toString() ?? currency, t)}. '
    '${t.t('changes')}: ${item['stops'] ?? '?'}';

class TravelScreen extends StatefulWidget {
  const TravelScreen({super.key});
  @override
  State<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends State<TravelScreen> {
  final _consent = TravelWelcomeConsent();
  bool _accepted = false, _busy = true, _failed = false, _loaded = false;
  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    try {
      final accepted = await _consent.isAccepted();
      if (mounted) setState(() => _accepted = accepted);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loaded = true;
        });
      }
    }
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await _consent.accept();
      if (mounted) setState(() => _accepted = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _strings(context);
    if (!_loaded) {
      return _page(t.t('title'), [_info('loading', t.t('working'))]);
    }
    if (!_accepted) {
      return _page(t.t('welcomeTitle'), [
        if (_busy) _info('loading', t.t('working')),
        if (_failed) _info('error', t.t('welcomeSaveError')),
        for (var i = 1; i <= 5; i++) _info('welcome-$i', t.t('welcome$i')),
        _action('accept', t.t('accept'), _accept, enabled: !_busy),
        _action('decline', t.t('decline'), () async {
          await Navigator.of(context).maybePop();
        }, enabled: !_busy),
      ]);
    }
    return _page(t.t('title'), [
      _action(
        'new',
        t.t('new'),
        () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TravelSearchScreen()),
        ),
      ),
      _action(
        'recent',
        t.t('recent'),
        () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const _RecentTravelScreen()),
        ),
      ),
    ]);
  }
}

class TravelSearchScreen extends StatefulWidget {
  const TravelSearchScreen({super.key, this.initial, this.serviceFactory});
  final TravelQuery? initial;
  final TravelService Function()? serviceFactory;
  @override
  State<TravelSearchScreen> createState() => _TravelSearchScreenState();
}

class _TravelSearchScreenState extends State<TravelSearchScreen> {
  TravelQuery? _query;
  TravelService? _service;
  bool _busy = false;
  bool _restored = false;
  String? _message;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_query == null) {
      _query =
          widget.initial?.copy() ??
          TravelQuery(country: _strings(context).defaultCountry);
      if (widget.initial != null) {
        _restored = true;
      } else {
        _restore();
      }
    }
  }

  Future<void> _restore() async {
    try {
      final saved = await RecentTravelService().loadLast();
      if (!mounted) return;
      if (saved != null) {
        final today = DateUtilsTravel.today();
        if (saved.departure.isBefore(today)) saved.departure = today;
        if (saved.returnDate?.isBefore(saved.departure) == true) {
          saved.returnDate = saved.departure;
        }
        _query = saved;
      }
    } catch (_) {
      unawaited(AppLogger.log('[Travel] last_form_read_failed'));
    } finally {
      if (mounted) setState(() => _restored = true);
    }
  }

  Future<void> _remember(TravelCity city, bool from) async {
    if (!mounted) return;
    setState(() {
      if (from) {
        _query!.from = city.name;
        _query!.departureCity = city;
      } else {
        _query!.to = city.name;
        _query!.arrivalCity = city;
      }
    });
    try {
      await RecentTravelService().saveLast(_query!);
    } catch (_) {
      unawaited(AppLogger.log('[Travel] last_form_write_failed'));
    }
  }

  @override
  void dispose() {
    unawaited(_service?.close() ?? Future<void>.value());
    super.dispose();
  }

  AccessibleListRow _picker(
    String id,
    String title,
    String value,
    List<AccessibleOption> options,
    void Function(String) change,
  ) {
    final index = options
        .indexWhere((o) => o.value == value)
        .clamp(0, options.length - 1);
    return AccessibleListRow(
      id: id,
      title: title,
      kind: 'slider',
      value: value,
      valueLabel: options.where((o) => o.value == value).firstOrNull?.label,
      options: options,
      sliderValue: index.toDouble(),
      sliderMin: 0,
      sliderMax: (options.length - 1).toDouble(),
      sliderStep: 1,
      sliderIncreasedValueLabel:
          options[(index + 1).clamp(0, options.length - 1)].label,
      sliderDecreasedValueLabel:
          options[(index - 1).clamp(0, options.length - 1)].label,
      enabled: !_busy,
      onValueChanged: (v) {
        final position = v is num
            ? v.toDouble()
            : double.tryParse(v.toString());
        if (!_busy && position != null && position.isFinite) {
          final next = position.round().clamp(0, options.length - 1);
          setState(() => change(options[next].value.toString()));
        }
      },
    );
  }

  List<AccessibleOption> _numbers(int first, int last) => [
    for (var n = first; n <= last; n++)
      AccessibleOption(value: n.toString(), label: n.toString()),
  ];
  List<AccessibleListRow> _dateRows(
    String prefix,
    DateTime date,
    void Function(DateTime) setDate,
    TravelStrings t,
  ) => [
    _picker(
      '$prefix-day',
      '${t.t(prefix)}: ${t.t('day')}',
      '${date.day}',
      _numbers(1, DateTime(date.year, date.month + 1, 0).day),
      (v) =>
          setDate(DateUtilsTravel.clamp(date.year, date.month, int.parse(v))),
    ),
    _picker(
      '$prefix-month',
      t.t('month'),
      '${date.month}',
      [
        for (var m = 1; m <= 12; m++)
          AccessibleOption(
            value: '$m',
            label: DateFormat.MMMM(t.locale).format(DateTime(2026, m)),
          ),
      ],
      (v) => setDate(DateUtilsTravel.clamp(date.year, int.parse(v), date.day)),
    ),
    _picker(
      '$prefix-year',
      t.t('year'),
      '${date.year}',
      _numbers(
        date.year < DateTime.now().year ? date.year : DateTime.now().year,
        DateTime.now().year + 2,
      ),
      (v) => setDate(DateUtilsTravel.clamp(int.parse(v), date.month, date.day)),
    ),
  ];

  Future<TravelCity?> _resolve(String query, bool from, TravelStrings t) async {
    final cities = await _service!.cities(query, _query!.country);
    if (!mounted) return null;
    if (cities.isEmpty) {
      setState(() => _message = t.t('noCity'));
      return null;
    }
    final remembered = from ? _query!.departureCity : _query!.arrivalCity;
    if (remembered != null && query == remembered.name) {
      final match = cities
          .where((city) => city.id == remembered.id)
          .firstOrNull;
      if (match != null) return match;
    }
    if (cities.length == 1) return cities.first;
    return Navigator.of(context).push<TravelCity>(
      MaterialPageRoute(
        builder: (context) => _page(t.t(from ? 'chooseFrom' : 'chooseTo'), [
          for (final city in cities)
            _action(
              'city-${city.id}',
              city.name,
              () => Navigator.pop(context, city),
              subtitle: [
                localizedCountryDisplayName(city.country, localeName: t.locale),
                city.region,
              ].where((s) => s.isNotEmpty).join(' — '),
            ),
        ]),
      ),
    );
  }

  Future<void> _search() async {
    if (_busy) return;
    final q = _query!, t = _strings(context);
    if (q.from.trim().length < 2 ||
        q.to.trim().length < 2 ||
        q.departure.isBefore(DateUtilsTravel.today()) ||
        (q.returnDate != null && q.returnDate!.isBefore(q.departure))) {
      setState(() => _message = t.t('invalid'));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _service?.close();
      if (!mounted) return;
      _service = widget.serviceFactory?.call() ?? TravelService();
      await _service!.start(t.locale, q.currency);
      if (!mounted) return;
      final from = await _resolve(q.from.trim(), true, t);
      if (from == null || !mounted) return;
      await _remember(from, true);
      if (!mounted) return;
      final to = await _resolve(q.to.trim(), false, t);
      if (to == null || !mounted) return;
      await _remember(to, false);
      if (!mounted) return;
      if (from.id == to.id) {
        setState(() => _message = t.t('sameCity'));
        return;
      }
      await _service!.search(q, from, to);
      if (!mounted) return;
      final saved = q.copy()
        ..from = from.name
        ..to = to.name;
      try {
        await RecentTravelService().add(saved);
      } catch (_) {
        unawaited(AppLogger.log('[Travel] history_write_failed'));
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TravelResultsScreen(service: _service!, query: saved),
        ),
      );
    } catch (e) {
      unawaited(
        AppLogger.log('[Travel] search_flow_failed type=${e.runtimeType}'),
      );
      if (mounted) setState(() => _message = _error(t, e));
    } finally {
      await _service?.close();
      _service = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query!, t = _strings(context);
    if (!_restored) {
      return _page(t.t('new'), [_info('loading', t.t('working'))]);
    }
    final countries = [
      'IT',
      'FR',
      'DE',
      'ES',
      'PT',
      'BR',
      'GB',
      'US',
      'CA',
      'AU',
      'NZ',
      'CH',
      'AT',
      'BE',
      'NL',
      'PL',
      'CZ',
      'UA',
      'RO',
      'TR',
      'CN',
      'SE',
      'NO',
      'DK',
      'GR',
    ];
    return _page(t.t('new'), [
      _picker('currency', t.t('currency'), q.currency, [
        for (final c in [
          'EUR',
          'USD',
          'GBP',
          'CHF',
          'CAD',
          'AUD',
          'NZD',
          'SEK',
          'NOK',
          'DKK',
          'PLN',
          'CZK',
          'HUF',
          'RON',
          'BGN',
          'BRL',
          'MXN',
        ])
          AccessibleOption(value: c, label: c == 'EUR' ? 'Euro (EUR)' : c),
      ], (v) => q.currency = v),
      _picker('country', t.t('country'), q.country, [
        for (final c in countries)
          AccessibleOption(
            value: c,
            label: localizedCountryDisplayName(c, localeName: t.locale),
          ),
      ], (v) => q.country = v),
      AccessibleListRow(
        id: 'from',
        title: t.t('from'),
        kind: 'textField',
        value: q.from,
        enabled: !_busy,
        onValueChanged: (v) {
          q.from = v?.toString() ?? '';
          if (q.from.trim() != q.departureCity?.name) q.departureCity = null;
        },
      ),
      AccessibleListRow(
        id: 'to',
        title: t.t('to'),
        kind: 'textField',
        value: q.to,
        enabled: !_busy,
        onValueChanged: (v) {
          q.to = v?.toString() ?? '';
          if (q.to.trim() != q.arrivalCity?.name) q.arrivalCity = null;
        },
      ),
      _picker('mode', t.t('mode'), q.mode, [
        for (final m in ['train', 'flight', 'bus'])
          AccessibleOption(value: m, label: t.t(m)),
      ], (v) => q.mode = v),
      ..._dateRows('outbound', q.departure, (v) => q.departure = v, t),
      AccessibleListRow(
        id: 'roundtrip',
        title: t.t('roundtrip'),
        kind: 'toggle',
        toggleValue: q.returnDate != null,
        enabled: !_busy,
        onValueChanged: (v) {
          if (!_busy) {
            setState(() => q.returnDate = v == true ? q.departure : null);
          }
        },
      ),
      if (q.returnDate != null)
        ..._dateRows('return', q.returnDate!, (v) => q.returnDate = v, t),
      _picker(
        'passengers',
        t.t('passengers'),
        '${q.ages.length}',
        _numbers(1, 9),
        (v) {
          final count = int.parse(v);
          q.ages = List.generate(
            count,
            (i) => i < q.ages.length ? q.ages[i] : 40,
          );
        },
      ),
      for (var i = 0; i < q.ages.length; i++)
        _picker(
          'age-$i',
          '${t.t('age')} ${i + 1}',
          '${q.ages[i]}',
          _numbers(0, 110),
          (v) => q.ages[i] = int.parse(v),
        ),
      if (_message != null) _info('error', _message!),
      _action(
        'search',
        t.t(_busy ? 'working' : 'search'),
        _search,
        enabled: !_busy,
      ),
    ]);
  }
}

class TravelResultsScreen extends StatefulWidget {
  const TravelResultsScreen({
    super.key,
    required this.service,
    required this.query,
    this.outbound,
  });
  final TravelService service;
  final TravelQuery query;
  final Map<String, dynamic>? outbound;
  @override
  State<TravelResultsScreen> createState() => _TravelResultsScreenState();
}

class _TravelResultsScreenState extends State<TravelResultsScreen> {
  Map<String, dynamic>? _data;
  String? _errorText;
  bool _busy = false;
  int _pageNumber = 1;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(1, poll: true);
    });
  }

  Future<void> _load(int page, {bool poll = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorText = null;
    });
    final t = _strings(context);
    try {
      for (var i = 0; i < (poll ? 20 : 1); i++) {
        final data = await widget.service.results(
          page: page,
          outbound: widget.outbound?['choice_id'] as String?,
        );
        if (!mounted) return;
        setState(() {
          _data = data;
          _pageNumber = page;
        });
        if ((data['items'] as List).isNotEmpty ||
            data['status'] == 'complete') {
          break;
        }
        if (poll && i < 19) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
        if (!mounted) return;
      }
    } catch (e) {
      if (mounted) setState(() => _errorText = _error(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(Map<String, dynamic> item) async {
    if (_busy) return;
    if (widget.query.returnDate != null && widget.outbound == null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TravelResultsScreen(
            service: widget.service,
            query: widget.query,
            outbound: item,
          ),
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    final t = _strings(context);
    try {
      final selection = await widget.service.request(
        '/v1/search/selection',
        body: {
          'outbound_choice': widget.outbound?['choice_id'] ?? item['choice_id'],
          if (widget.outbound != null) 'inbound_choice': item['choice_id'],
        },
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _TravelFaresScreen(
            service: widget.service,
            query: widget.query,
            groups: (selection['groups'] as List).cast<Map<String, dynamic>>(),
            journeys: [if (widget.outbound != null) widget.outbound!, item],
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _errorText = _error(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _strings(context), data = _data;
    final items = (data?['items'] as List? ?? []).cast<Map<String, dynamic>>();
    return _page(
      '${t.t('results')} — ${t.t(widget.outbound == null ? 'outbound' : 'return')}',
      [
        if (_busy) _info('working', t.t('working')),
        if (_errorText != null) _info('error', _errorText!),
        if (data != null && data['status'] != 'complete')
          _info('partial', t.t(items.isEmpty ? 'waiting' : 'partial')),
        if (data?['status'] == 'complete' && items.isEmpty)
          _info('empty', t.t('empty')),
        if (items.isNotEmpty)
          _info(
            'page',
            '${t.t('page')} $_pageNumber — ${data!['count']} ${t.t('results').toLowerCase()}',
          ),
        for (final item in items)
          _action(
            'journey-${item['choice_id']}',
            _journey(item, widget.query.currency, t),
            () => _select(item),
            enabled: !_busy,
          ),
        if (_pageNumber > 1)
          _action(
            'previous',
            t.t('previous'),
            () => _load(_pageNumber - 1),
            enabled: !_busy,
          ),
        if (data?['has_next'] == true)
          _action(
            'next',
            t.t('next'),
            () => _load(_pageNumber + 1),
            enabled: !_busy,
          ),
        _action(
          'refresh',
          t.t('refresh'),
          () => _load(1, poll: true),
          enabled: !_busy,
        ),
      ],
    );
  }
}

class _TravelFaresScreen extends StatefulWidget {
  const _TravelFaresScreen({
    required this.service,
    required this.query,
    required this.groups,
    required this.journeys,
  });
  final TravelService service;
  final TravelQuery query;
  final List<Map<String, dynamic>> groups, journeys;
  @override
  State<_TravelFaresScreen> createState() => _TravelFaresScreenState();
}

class _TravelFaresScreenState extends State<_TravelFaresScreen> {
  final List<Map<String, dynamic>> _selected = [];
  String? _url, _message;
  bool _onsite = false;
  final _passengerDraft = TravelPassengerDraft();
  bool _busy = false, _attempted = false;
  final String _idempotencyKey = const Uuid().v4();
  Future<void> _enterPassengers() async {
    final screen = TravelPassengersScreen(
      service: widget.service,
      query: widget.query,
      fallbackUrl: _url!,
      draft: _passengerDraft,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(maintainState: true, builder: (_) => screen),
    );
  }

  Future<void> _open() async {
    if (_url == null) return;
    try {
      final uri = Uri.parse(_url!);
      if (uri.scheme != 'https' ||
          !['www.omio.com', 'omio.com'].contains(uri.host) ||
          uri.userInfo.isNotEmpty) {
        throw const TravelException('link');
      }
      await openTravelBrowser(context, uri.toString());
      unawaited(AppLogger.log('[Travel] checkout_open_requested'));
    } catch (_) {
      unawaited(AppLogger.log('[Travel] checkout_open_failed'));
      if (mounted) setState(() => _message = _strings(context).t('linkError'));
    }
  }

  Future<void> _continue() async {
    if (_busy || _attempted) return;
    final t = _strings(context);
    setState(() {
      _busy = true;
      _attempted = true;
      _message = null;
    });
    try {
      final booking = await widget.service.request(
        '/v1/bookings',
        body: {
          'offers': _selected.map((o) => o['offer_choice']).toList(),
          'confirm': true,
        },
        idempotencyKey: _idempotencyKey,
      );
      final urls = booking['urls'] as List?;
      final url =
          booking['passenger_url'] ?? (urls?.length == 1 ? urls!.first : null);
      if (url is! String) throw const TravelException('link');
      if (!mounted) return;
      setState(() {
        _url = url;
        _onsite = booking['status'] != 'external_provider';
      });
      if (_onsite) {
        await _enterPassengers();
      } else {
        await _open();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = '${t.t('bookingError')} ${_error(t, e)}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _strings(context);
    if (_selected.length < widget.groups.length) {
      final group = widget.groups[_selected.length];
      final offers = (group['offers'] as List).cast<Map<String, dynamic>>();
      return _page('${t.t('fares')} — ${t.t('group')} ${_selected.length + 1}', [
        for (final offer in offers)
          _action(
            'offer-${offer['offer_choice']}',
            '${(offer['fare'] as List? ?? []).map((f) => _plain(f['title'] ?? '')).join(', ')}. ${_money(offer['price'], widget.query.currency, t)}',
            () => setState(() => _selected.add(offer)),
            subtitle: _fareDetails(offer),
          ),
        if (_selected.isNotEmpty)
          _action(
            'previous',
            t.t('previous'),
            () => setState(() => _selected.removeLast()),
          ),
      ]);
    }
    return _page(t.t('handoff'), [
      for (var i = 0; i < widget.journeys.length; i++)
        _info(
          'summary-$i',
          _journey(widget.journeys[i], widget.query.currency, t),
        ),
      for (var i = 0; i < _selected.length; i++)
        _info(
          'fare-$i',
          '${t.t('fare')} ${i + 1}: ${_money(_selected[i]['price'], widget.query.currency, t)}\n${_fareDetails(_selected[i])}'
              .trim(),
        ),
      _info('notice', t.t('handoffInfo')),
      if (_message != null) _info('error', _message!),
      if (_url != null)
        _action(
          'open',
          t.t(_onsite ? 'continue' : 'open'),
          _onsite ? _enterPassengers : _open,
        )
      else
        _action(
          'continue',
          t.t(_busy ? 'working' : 'continue'),
          _continue,
          enabled: !_busy && !_attempted && _selected.isNotEmpty,
        ),
    ]);
  }
}

class _RecentTravelScreen extends StatefulWidget {
  const _RecentTravelScreen();
  @override
  State<_RecentTravelScreen> createState() => _RecentTravelScreenState();
}

class _RecentTravelScreenState extends State<_RecentTravelScreen> {
  List<TravelQuery>? _items;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await RecentTravelService().load();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _message = _strings(context).t('error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _strings(context);
    return _page(t.t('recent'), [
      if (_message != null) _info('error', _message!),
      if (_items == null && _message == null) _info('working', t.t('working')),
      if (_items?.isEmpty == true) _info('empty', t.t('noRecent')),
      if (_items?.isNotEmpty == true) _info('notice', t.t('recentInfo')),
      for (var i = 0; i < (_items?.length ?? 0); i++)
        _action(
          'recent-$i',
          '${_items![i].from} — ${_items![i].to}. ${t.t(_items![i].mode)}. ${DateFormat.yMd(t.locale).format(_items![i].departure)}',
          () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TravelSearchScreen(initial: _items![i]),
              ),
            );
            if (mounted) await _load();
          },
        ),
      if (_items?.isNotEmpty == true)
        _action('clear', t.t('clear'), () async {
          try {
            await RecentTravelService().clear();
            if (mounted) setState(() => _items = []);
          } catch (_) {
            if (context.mounted) showStatusMessage(context, t.t('error'));
          }
        }),
    ]);
  }
}
