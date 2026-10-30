import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/parser.dart' as html;
import '../l10n/app_localizations.dart';
import '../l10n/ticketone_strings.dart';
import '../services/concert_search_service.dart';
import '../utils/country_name_helper.dart';
import '../widgets/universal_accessible_view.dart';
import 'ticketone_browser_screen.dart';

DateTime concertDateOneMonthLater(DateTime date) {
  final next = DateTime(date.year, date.month + 1);
  return DateTime(
    next.year,
    next.month,
    date.day.clamp(1, DateUtils.getDaysInMonth(next.year, next.month)),
  );
}

AccessibleListRow _text(String id, String text) => AccessibleListRow(
  id: id,
  title: text,
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
  finishEditingOnActivate: true,
);
Widget _page(
  String title,
  List<AccessibleListRow> rows, {
  String? focus,
  Key? key,
}) => Scaffold(
  appBar: SonarpadAppBar(title: Text(title)),
  body: SafeArea(
    child: UniversalAccessibleList(
      key: key,
      initialFocusId: focus,
      sections: [AccessibleListSection(rows: rows)],
      padding: const EdgeInsets.all(16),
    ),
  ),
);
AccessibleListRow _slider(
  String id,
  String title,
  List<String> labels,
  int selected,
  void Function(int) change,
) => AccessibleListRow(
  id: id,
  title: title,
  kind: 'slider',
  value: '$selected',
  valueLabel: labels[selected],
  options: [
    for (var i = 0; i < labels.length; i++)
      AccessibleOption(value: '$i', label: labels[i]),
  ],
  sliderValue: selected.toDouble(),
  sliderMin: 0,
  sliderMax: (labels.length - 1).toDouble(),
  sliderStep: 1,
  sliderIncreasedValueLabel: labels[(selected + 1).clamp(0, labels.length - 1)],
  sliderDecreasedValueLabel: labels[(selected - 1).clamp(0, labels.length - 1)],
  onValueChanged: (value) {
    final n = double.tryParse('$value');
    if (n != null && n.isFinite) change(n.round().clamp(0, labels.length - 1));
  },
);

class ConcertSearchScreen extends StatefulWidget {
  const ConcertSearchScreen({super.key, this.service});
  final ConcertSearchService? service;
  @override
  State<ConcertSearchScreen> createState() => _ConcertSearchScreenState();
}

class _ConcertSearchScreenState extends State<ConcertSearchScreen> {
  late final ConcertSearchService _service =
      widget.service ?? ConcertSearchService();
  ConcertMarket _market = ConcertMarket.all.first;
  String _term = '', _city = '';
  String? _chosenCity, _error;
  bool _busy = true, _dates = false, _initialized = false;
  static const _welcomeKey = 'sonarpad_concert_welcome_accepted_v1';
  bool _welcomeAccepted = false, _welcomeFailed = false;
  int _generation = 0;
  late DateTime _from = DateUtils.dateOnly(DateTime.now());
  late DateTime _to = concertDateOneMonthLater(_from);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      unawaited(_restore());
    }
  }

  Future<void> _restore() async {
    final locale = AppLocalizations.of(context).localeName;
    final generation = _generation;
    _market = ConcertMarket.all.firstWhere(
      (m) => m.language == locale.split('_').first,
      orElse: () => ConcertMarket.all.first,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || generation != _generation) return;
      final saved = prefs.getString('concert_country');
      _welcomeAccepted = prefs.getBool(_welcomeKey) ?? false;
      _market = ConcertMarket.all.firstWhere(
        (m) => m.country == saved,
        orElse: () => _market,
      );
      _term = prefs.getString('concert_term') ?? '';
      _city = prefs.getString('concert_city') ?? '';
      _chosenCity = prefs.getString('concert_chosen_city');
    } catch (_) {
      // Searching remains available if saved preferences cannot be restored.
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('concert_country', _market.country);
    await prefs.setString('concert_term', _term);
    await prefs.setString('concert_city', _city);
    if (_chosenCity != null) {
      await prefs.setString('concert_chosen_city', _chosenCity!);
    } else {
      await prefs.remove('concert_chosen_city');
    }
  }

  Future<void> _acceptWelcome() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _welcomeFailed = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(_welcomeKey, true)) {
        throw StateError('preference_save_failed');
      }
      if (mounted) setState(() => _welcomeAccepted = true);
    } catch (_) {
      if (mounted) setState(() => _welcomeFailed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    if (widget.service == null) _service.close();
    super.dispose();
  }

  Future<void> _search() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    if (_dates && _to.isBefore(_from)) {
      setState(
        () => _error = MaterialLocalizations.of(context).invalidDateRangeLabel,
      );
      return;
    }
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_city.trim().isNotEmpty && _chosenCity != _city.trim()) {
        final city = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (_) => _ConcertResults(
              title: l.radioCity,
              cities: true,
              market: _market,
              load: (page) => _service.cities(_market, _city, page: page),
            ),
          ),
        );
        if (!mounted || generation != _generation) return;
        if (city == null) return;
        _chosenCity = _city = city['name'] as String;
      }
      await _save();
      if (!mounted || generation != _generation) return;
      final market = _market, term = _term, city = _chosenCity ?? '';
      final from = _dates ? _from : null, to = _dates ? _to : null;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ConcertResults(
            title: l.concertsTitle,
            market: market,
            load: (page) => _service.search(
              market,
              term: term,
              city: city,
              from: from,
              to: to,
              page: page,
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted && generation == _generation) {
        _error = l.technicalErrorGeneric;
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  List<AccessibleListRow> _dateRows(bool end, AppLocalizations l) {
    final date = end ? _to : _from, id = end ? 'to' : 'from';
    void update({int? day, int? month, int? year}) {
      final y = year ?? date.year, m = month ?? date.month;
      final d = (day ?? date.day).clamp(1, DateUtils.getDaysInMonth(y, m));
      setState(() {
        if (end) {
          _to = DateTime(y, m, d);
        } else {
          _from = DateTime(y, m, d);
          _to = concertDateOneMonthLater(_from);
        }
      });
    }

    final years = List.generate(8, (i) => DateTime.now().year + i);
    return [
      _slider(
        '$id-day',
        end ? l.concertsTo : l.concertsFrom,
        List.generate(
          DateUtils.getDaysInMonth(date.year, date.month),
          (i) => DateFormat.MMMMEEEEd(l.localeName).format(
            DateTime(date.year, date.month, i + 1),
          ),
        ),
        date.day - 1,
        (n) => update(day: n + 1),
      ),
      _slider(
        '$id-month',
        l.concertsMonth,
        List.generate(
          12,
          (i) => DateFormat.MMMM(l.localeName).format(DateTime(2026, i + 1)),
        ),
        date.month - 1,
        (n) => update(month: n + 1),
      ),
      _slider(
        '$id-year',
        l.concertsYear,
        years.map((y) => '$y').toList(),
        years.indexOf(date.year).clamp(0, years.length - 1),
        (n) => update(year: years[n]),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_busy) {
      return _page(l.concertsTitle, [
        _text('loading', l.loading),
        _button('cancel', l.cancel, () {
          _generation++;
          setState(() => _busy = false);
        }),
      ], key: const ValueKey('concert-loading'));
    }
    if (!_welcomeAccepted) {
      final t = TicketOneStrings(l.localeName);
      return _page(
        t.t('concertWelcomeTitle'),
        [
          if (_welcomeFailed) _text('welcome-error', t.t('welcomeSaveError')),
          for (var i = 1; i <= 5; i++)
            _text('welcome-$i', t.t('concertWelcome$i')),
          _button('accept', t.t('accept'), _acceptWelcome),
          _button(
            'decline',
            t.t('decline'),
            () => Navigator.of(context).maybePop(),
          ),
        ],
        focus: 'welcome-1',
        key: const ValueKey('concert-welcome'),
      );
    }
    return _page(
      l.concertsTitle,
      [
        if (_error != null) _text('error', _error!),
        _slider(
          'country',
          l.radioCountry,
          ConcertMarket.all
              .map(
                (m) => localizedCountryDisplayName(
                  m.country,
                  localeName: l.localeName,
                ),
              )
              .toList(),
          ConcertMarket.all.indexOf(_market),
          (n) => setState(() {
            _market = ConcertMarket.all[n];
            _city = '';
            _chosenCity = null;
          }),
        ),
        AccessibleListRow(
          id: 'term',
          title: l.concertsArtist,
          kind: 'textField',
          value: _term,
          onValueChanged: (v) => _term = '$v',
        ),
        AccessibleListRow(
          id: 'city',
          title: l.radioCity,
          subtitle: l.concertsAllCities,
          kind: 'textField',
          value: _city,
          onValueChanged: (v) {
            _city = v?.toString() ?? '';
            if (_city.trim() != _chosenCity) _chosenCity = null;
          },
        ),
        AccessibleListRow(
          id: 'dates',
          title: l.concertsDates,
          kind: 'toggle',
          toggleValue: _dates,
          onValueChanged: (v) => setState(() => _dates = v == true),
        ),
        if (_dates) ...[..._dateRows(false, l), ..._dateRows(true, l)],
        _button('search', l.search, _search),
        _text('notice', l.concertsInitialText),
      ],
      key: const ValueKey('concert-form'),
      focus: _error != null ? 'error' : null,
    );
  }
}

class _ConcertResults extends StatefulWidget {
  const _ConcertResults({
    required this.title,
    required this.market,
    required this.load,
    this.cities = false,
    this.page = 1,
  });
  final String title;
  final ConcertMarket market;
  final Future<ConcertPage> Function(int) load;
  final bool cities;
  final int page;
  @override
  State<_ConcertResults> createState() => _ConcertResultsState();
}

class _ConcertResultsState extends State<_ConcertResults> {
  ConcertPage? _result;
  bool _busy = true, _error = false;
  int _pageNumber = 1, _generation = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load(widget.page));
  }

  void _changePage(int page) {
    if (widget.cities) {
      unawaited(_load(page));
      return;
    }
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) => _ConcertResults(
          title: widget.title,
          market: widget.market,
          load: widget.load,
          cities: widget.cities,
          page: page,
        ),
      ),
    );
  }

  Future<void> _load(int page) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = false;
      _pageNumber = page;
    });
    try {
      final result = await widget.load(page);
      if (mounted && generation == _generation) {
        setState(() => _result = result);
      }
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _error = true);
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  String _label(Map<String, dynamic> event) {
    if (widget.cities) return event['name']?.toString() ?? '';
    final info =
        (event['typeAttributes'] as Map?)?['liveEntertainment'] as Map? ?? {};
    final place = info['location'] as Map? ?? {};
    // Preserve the event's local wall time, never convert it to the phone's zone.
    final raw = info['startDate']?.toString() ?? '';
    final date = raw.length >= 16
        ? DateTime.tryParse(raw.substring(0, 16))
        : null;
    final l = AppLocalizations.of(context);
    return [
      event['name'],
      if (date != null) DateFormat.yMMMMd(l.localeName).add_Hm().format(date),
      place['city'],
      place['name'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(' — ');
  }

  Future<void> _select(Map<String, dynamic> event) async {
    if (widget.cities) {
      Navigator.of(context).pop(event);
      return;
    }
    final l = AppLocalizations.of(context), market = widget.market;
    final label = _label(event);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ConcertDetails(
          event: event,
          market: market,
          label: label,
          title: l.concertsTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), result = _result;
    if (_busy) {
      return _page(widget.title, [
        _text('loading', l.loading),
        _button('cancel', l.cancel, () => Navigator.of(context).maybePop()),
      ], key: const ValueKey('concert-results-loading'));
    }
    if (_error) {
      return _page(widget.title, [
        _text('error', l.technicalErrorGeneric),
        _button('retry', l.retry, () => _load(_pageNumber)),
      ], focus: 'error');
    }
    return _page(
      '${widget.title} — $_pageNumber/${result?.pages ?? 0}',
      [
        if (result == null || result.items.isEmpty)
          _text(
            'empty',
            widget.cities ? l.weatherCityNotFound : l.concertsEmpty,
          ),
        if (result != null)
          for (var i = 0; i < result.items.length; i++)
            _button(
              'item-$i',
              _label(result.items[i]),
              () => _select(result.items[i]),
            ),
        if (_pageNumber > 1)
          _button(
            'previous',
            l.radioPreviousPage,
            () => _changePage(_pageNumber - 1),
          ),
        if (result != null && _pageNumber < result.pages)
          _button('next', l.radioNextPage, () => _changePage(_pageNumber + 1)),
      ],
      key: ValueKey('concert-results-$_pageNumber'),
      focus: result?.items.isNotEmpty == true ? 'item-0' : 'empty',
    );
  }
}

class _ConcertDetails extends StatelessWidget {
  const _ConcertDetails({
    required this.event,
    required this.market,
    required this.label,
    required this.title,
  });
  final Map<String, dynamic> event;
  final ConcertMarket market;
  final String label, title;
  Future<void> _open(BuildContext context, Uri url) async {
    final l = AppLocalizations.of(context);
    try {
      if (market.host == 'www.ticketone.it') {
        final eventUrl = ConcertSearchService.eventUrl(market, event['link']);
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TicketOneBrowserScreen(
              eventUrl: eventUrl,
              accountPath: url.path.startsWith('/dashboard/') ? url.path : null,
            ),
          ),
        );
        return;
      }
      if (!await launchUrl(url, mode: LaunchMode.inAppBrowserView)) {
        throw const ConcertSearchException('link');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.errorOpening)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _page(title, [
      _text('event', label),
      _text(
        'description',
        html.parseFragment(event['description']?.toString() ?? '').text ?? '',
      ),
      _text('notice', l.concertsInitialText),
      if (market.host == 'www.ticketone.it') ...[
        _button(
          'ticketone-login',
          l.concertsTicketOneLogin,
          () =>
              _open(context, Uri.https('www.ticketone.it', '/dashboard/login')),
        ),
        _button(
          'ticketone-register',
          l.concertsTicketOneRegister,
          () => _open(
            context,
            Uri.https('www.ticketone.it', '/dashboard/login/register'),
          ),
        ),
      ],
      _button('open', l.concertsBuyTickets, () async {
        try {
          final url = ConcertSearchService.eventUrl(market, event['link']);
          await _open(context, url);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l.errorOpening)));
          }
        }
      }),
    ]);
  }
}
