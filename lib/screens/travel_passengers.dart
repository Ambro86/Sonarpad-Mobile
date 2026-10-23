part of 'travel_screen.dart';

/// Kept by the fare screen so returning to the form cannot repeat a submission.
class TravelPassengerDraft {
  final Map<String, dynamic> values = {};
  List<Map<String, dynamic>>? fields;
  int position = 0;
  bool attempted = false, submitted = false;
  String? paymentUrl;
  final String submissionKey = const Uuid().v4();
}

class TravelPassengersScreen extends StatefulWidget {
  const TravelPassengersScreen({
    super.key,
    required this.service,
    required this.query,
    required this.fallbackUrl,
    required this.draft,
  });
  final TravelService service;
  final TravelQuery query;
  final String fallbackUrl;
  final TravelPassengerDraft draft;
  @override
  State<TravelPassengersScreen> createState() => _TravelPassengersScreenState();
}

class _TravelPassengersScreenState extends State<TravelPassengersScreen> {
  TravelPassengerDraft get d => widget.draft;
  final _memory = TravelPassengerMemory();
  bool _busy = true;
  String? _message;
  final Map<String, List<AccessibleOption>> _stateOptions = {};
  List<AccessibleOption>? _countries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Iterable<Map<String, dynamic>> _flatten(List nodes) sync* {
    for (final node in nodes.whereType<Map>()) {
      if (node['name'] is String) yield Map<String, dynamic>.from(node);
      yield* _flatten(node['components'] as List? ?? []);
    }
  }

  Future<void> _load() async {
    try {
      if (d.fields == null) {
        final form = await widget.service.request('/v1/booking/form');
        final fields = _flatten(form['components'] as List? ?? []).where((f) {
          final name = f['name'] as String;
          return !name.split('.').last.startsWith('saveToProfile') &&
              !name.split('.').last.startsWith('promotional');
        }).toList();
        if (fields.isEmpty ||
            fields.any((f) => !RegExp(r'^\d+\..+$').hasMatch(f['name']))) {
          throw const TravelException('form');
        }
        final indices =
            fields
                .map((f) => int.parse((f['name'] as String).split('.').first))
                .toSet()
                .toList()
              ..sort();
        if (indices.any((i) => i < 0 || i >= widget.query.ages.length)) {
          throw const TravelException('form');
        }
        // Group travellers numerically, preserving the provider's field order within each.
        d.fields = [
          for (final index in indices)
            ...fields.where((f) => (f['name'] as String).startsWith('$index.')),
        ];
        for (final index in indices) {
          final saved = await _memory.load(passenger: index);
          for (final f in d.fields!.where(
            (f) => (f['name'] as String).startsWith('$index.'),
          )) {
            final name = f['name'] as String;
            final key = name.split('.')[1].replaceFirst(RegExp(r'-\d+$'), '');
            if (saved[key] != null) {
              d.values.putIfAbsent(name, () => saved[key]!);
            }
          }
        }
      }
      await _prepare();
    } catch (_) {
      if (mounted) _message = _strings(context).t('unsupportedForm');
      unawaited(AppLogger.log('[Travel] passenger_form_load_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _visible(Map<String, dynamic> f) {
    final visible = (f['renderingOptions'] as Map?)?['visible'];
    if (visible == false) return false;
    if (visible is! Map) return true;
    final matches = (visible['condition'] as Map?)?['valueMatches'];
    final dependency = visible['fieldNameToCondition'];
    if (matches is! List || dependency is! String) {
      throw const TravelException('form');
    }
    final index = (f['name'] as String).split('.').first;
    return matches.contains(d.values['$index.$dependency-0']);
  }

  List<Map<String, dynamic>> get _visibleFields =>
      (d.fields ?? []).where(_visible).toList();
  Map<String, dynamic>? get _field {
    final fields = _visibleFields;
    return d.position < fields.length ? fields[d.position] : null;
  }

  bool _required(Map f) => (f['validation'] as List? ?? []).any(
    (r) => r is Map && r['type'] == 'required',
  );
  String _label(Map f, TravelStrings t) =>
      '${t.t('passenger')} ${int.parse((f['name'] as String).split('.').first) + 1}: ${_plain(f['title'] ?? (f['name'] as String).split('.').last)}';
  String _component(Map f) => f['component']?.toString() ?? 'Text';
  bool _supported(Map f) =>
      _options(f['options']).isNotEmpty ||
      const [
        'Text',
        'TextInput',
        'Input',
        'Email',
        'DiscountCard',
        'Country',
        'CountryOfResidence',
        'Date',
        'PhoneNumber',
      ].contains(_component(f));

  List<AccessibleOption> _options(dynamic nodes) {
    if (nodes is List) {
      return nodes
          .whereType<Map>()
          .where((o) => o['value'] != null && o['label'] != null)
          .map(
            (o) => AccessibleOption(
              value: o['value'].toString(),
              label: _plain(o['label']),
            ),
          )
          .toList();
    }
    if (nodes is Map) {
      for (final child in nodes.values) {
        final found = _options(child);
        if (found.isNotEmpty) return found;
      }
    }
    return [];
  }

  Future<void> _prepare() async {
    final f = _field;
    if (f == null) return;
    if (_component(f) == 'CountryState') {
      final index = (f['name'] as String).split('.').first;
      final country = d.values['$index.addressCountry-0'];
      if (country is! String || country.isEmpty) {
        throw const TravelException('form');
      }
      if (!_stateOptions.containsKey(country)) {
        _stateOptions[country] = _options(
          await widget.service.request(
            '/v1/country-states',
            query: {'country': country},
          ),
        );
      }
      f['options'] = _stateOptions[country]!
          .map((o) => {'value': o.value, 'label': o.label})
          .toList();
      if ((f['options'] as List).isEmpty) throw const TravelException('form');
    }
  }

  List<AccessibleOption> _countryOptions(TravelStrings t) => _countries ??=
      (WorldCountry.list
          .map(
            (c) => AccessibleOption(
              value: c.codeShort,
              label: localizedCountryDisplayName(
                c.codeShort,
                localeName: t.locale,
              ),
            ),
          )
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label)));

  AccessibleListRow _choice(
    String id,
    String title,
    String value,
    List<AccessibleOption> choices,
    void Function(String) update,
  ) {
    final options = [
      AccessibleOption(value: '', label: _strings(context).t('chooseValue')),
      ...choices,
    ];
    final index = options
        .indexWhere((o) => o.value == value)
        .clamp(0, options.length - 1);
    return AccessibleListRow(
      id: id,
      title: title,
      kind: 'slider',
      value: value,
      valueLabel: options[index].label,
      enabled: !_busy && !d.attempted,
      sliderValue: index.toDouble(),
      sliderMin: 0,
      sliderMax: (options.length - 1).toDouble(),
      sliderStep: 1,
      sliderIncreasedValueLabel:
          options[(index + 1).clamp(0, options.length - 1)].label,
      sliderDecreasedValueLabel:
          options[(index - 1).clamp(0, options.length - 1)].label,
      onValueChanged: (v) {
        final n = v is num ? v.toDouble() : double.tryParse(v.toString());
        if (_busy || d.attempted || n == null || !n.isFinite) return;
        setState(
          () => update(
            options[n.round().clamp(0, options.length - 1)].value.toString(),
          ),
        );
      },
    );
  }

  AccessibleListRow _text(
    String id,
    String title,
    String value,
    void Function(String) update,
  ) => AccessibleListRow(
    id: id,
    title: title,
    kind: 'textField',
    value: value,
    enabled: !_busy && !d.attempted,
    onValueChanged: (v) {
      if (!_busy && !d.attempted) update(v?.toString() ?? '');
    },
  );

  List<AccessibleListRow> _inputs(Map<String, dynamic> f, TravelStrings t) {
    final name = f['name'] as String,
        component = _component(f),
        label = _label(f, t);
    final value = d.values[name];
    final options = _options(f['options']);
    if (options.isNotEmpty) {
      return [
        _choice(
          name,
          label,
          value?.toString() ?? '',
          options,
          (v) => d.values[name] = v,
        ),
      ];
    }
    if (component == 'Country' || component == 'CountryOfResidence') {
      return [
        _choice(
          name,
          label,
          value?.toString() ?? '',
          _countryOptions(t),
          (v) => d.values[name] = v,
        ),
      ];
    }
    if (component == 'Date') {
      // A blank date stays blank until the user actually changes a slider.
      final parsed = value is String ? DateTime.tryParse(value) : null;
      final parts =
          (d.values['$name:parts'] as Map<String, int>?) ??
          {
            if (parsed != null) 'day': parsed.day,
            if (parsed != null) 'month': parsed.month,
            if (parsed != null) 'year': parsed.year,
          };
      return [
        for (final part in ['day', 'month', 'year'])
          _choice(
            '$name:$part',
            part == 'day' ? '$label: ${t.t(part)}' : t.t(part),
            parts[part]?.toString() ?? '',
            [
              for (
                var n = part == 'year' ? DateTime.now().year - 120 : 1;
                n <=
                    (part == 'day'
                        ? DateTime(
                            parts['year'] ?? 2000,
                            (parts['month'] ?? 1) + 1,
                            0,
                          ).day
                        : part == 'month'
                        ? 12
                        : DateTime.now().year + 20);
                n++
              )
                AccessibleOption(
                  value: n.toString(),
                  label: part == 'month'
                      ? DateFormat.MMMM(t.locale).format(DateTime(2000, n))
                      : n.toString(),
                ),
            ],
            (v) {
              if (v.isEmpty) {
                parts.remove(part);
              } else {
                parts[part] = int.parse(v);
              }
              d.values['$name:parts'] = parts;
              if (parts.length == 3) {
                final date = DateUtilsTravel.clamp(
                  parts['year']!,
                  parts['month']!,
                  parts['day']!,
                );
                parts['day'] = date.day;
                d.values[name] = DateUtilsTravel.iso(date);
              } else {
                d.values.remove(name);
              }
            },
          ),
      ];
    }
    if (component == 'PhoneNumber') {
      final phone = Map<String, dynamic>.from(value is Map ? value : {});
      void change(String key, String v) {
        phone[key] = v;
        d.values[name] = phone;
      }

      return [
        _text(
          '$name:prefix',
          t.t('phonePrefix'),
          phone['countryDiallingCode'] ?? '',
          (v) => change('countryDiallingCode', v),
        ),
        _text(
          '$name:number',
          t.t('phoneNumber'),
          phone['nationalNumber'] ?? '',
          (v) => change('nationalNumber', v),
        ),
        _choice(
          '$name:country',
          t.t('phoneCountry'),
          phone['countryIsoCode'] ?? '',
          _countryOptions(t),
          (v) => change('countryIsoCode', v),
        ),
      ];
    }
    if ([
      'Text',
      'TextInput',
      'Input',
      'Email',
      'DiscountCard',
    ].contains(component)) {
      return [
        _text(name, label, value?.toString() ?? '', (v) => d.values[name] = v),
      ];
    }
    return [_info('unsupported', t.t('unsupportedForm'))];
  }

  String? _validate(Map<String, dynamic> f) {
    final t = _strings(context), name = f['name'] as String;
    if (!_supported(f)) return t.t('unsupportedForm');
    final value = d.values[name];
    if (value == null || value == '') {
      return _required(f) ? t.t('invalidField') : null;
    }
    if (_component(f) == 'PhoneNumber') {
      if (value is! Map ||
          !RegExp(
            r'^\+\d{1,4}$',
          ).hasMatch(value['countryDiallingCode'] ?? '') ||
          !RegExp(r'^\d{1,16}$').hasMatch(value['nationalNumber'] ?? '') ||
          !RegExp(r'^[A-Z]{2}$').hasMatch(value['countryIsoCode'] ?? '')) {
        return t.t('invalidField');
      }
      return null;
    }
    if (value is! String || value.length > 500) return t.t('invalidField');
    if (_component(f) == 'Email' &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      return t.t('invalidField');
    }
    final options = _options(f['options']);
    if (options.isNotEmpty && !options.any((o) => o.value == value)) {
      return t.t('invalidField');
    }
    final rules = (f['validation'] as List? ?? []).whereType<Map>();
    for (final rule in rules) {
      try {
        if (rule['type'] == 'regex' && !RegExp(rule['regex']).hasMatch(value)) {
          return t.t('invalidField');
        }
        if (rule['type'] == 'email' &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
          return t.t('invalidField');
        }
      } catch (_) {
        return t.t('unsupportedForm');
      }
    }
    if (_component(f) == 'Date') {
      final date = DateTime.tryParse(value);
      if (date == null || DateUtilsTravel.iso(date) != value) {
        return t.t('invalidField');
      }
      if (rules.any((r) => r['type'] == 'pastDate') &&
          !date.isBefore(DateUtilsTravel.today())) {
        return t.t('invalidField');
      }
      if (name.endsWith('.dateOfBirth-0')) {
        final when = widget.query.departure;
        final age =
            when.year -
            date.year -
            (when.month < date.month ||
                    (when.month == date.month && when.day < date.day)
                ? 1
                : 0);
        final index = int.parse(name.split('.').first);
        if (index >= widget.query.ages.length ||
            age != widget.query.ages[index]) {
          return t.t('ageMismatch');
        }
      }
    }
    return null;
  }

  Future<void> _next({bool skip = false}) async {
    if (_busy || d.attempted) return;
    final f = _field!;
    if (skip) d.values.remove(f['name']);
    final error = _validate(f);
    if (error != null) {
      setState(() => _message = error);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final name = f['name'] as String;
      if (d.values[name] is String) {
        await _memory.save(
          name.split('.')[1].replaceFirst(RegExp(r'-\d+$'), ''),
          d.values[name],
          passenger: int.parse(name.split('.').first),
        );
      }
      d.position++;
      await _prepare();
    } catch (_) {
      if (mounted) _message = _strings(context).t('unsupportedForm');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String url) async {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'https' ||
          !['omio.com', 'www.omio.com'].contains(uri.host) ||
          uri.userInfo.isNotEmpty) {
        throw const TravelException('link');
      }
      await openTravelBrowser(context, uri.toString());
    } catch (_) {
      if (mounted) setState(() => _message = _strings(context).t('linkError'));
    }
  }

  Future<void> _status() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      for (var n = 0; n < 20; n++) {
        final result = await widget.service.request('/v1/booking/status');
        if (!mounted) return;
        if (result['payment_url'] is String) {
          d.paymentUrl = result['payment_url'];
          break;
        }
        if ([
          'TIMEOUT',
          'FAILED',
          'CANCELLED',
          'EXPIRED',
        ].contains(result['status'])) {
          _message = _strings(context).t('bookingUnavailable');
          break;
        }
        if (n < 19) await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
      }
    } catch (e) {
      if (mounted) _message = _error(_strings(context), e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || d.attempted) return;
    final answers = <String, Map<String, dynamic>>{};
    for (final f in d.fields!) {
      final parts = (f['name'] as String).split('.');
      answers.putIfAbsent(parts[0], () => {});
      if (!_visible(f)) continue;
      final error = _validate(f);
      if (error != null) {
        setState(() {
          _message = error;
          d.position = _visibleFields.indexOf(f);
        });
        return;
      }
      final value = d.values[f['name']];
      if (value != null && value != '') {
        answers[parts[0]]![parts.sublist(1).join('.')] = value;
      }
    }
    setState(() {
      _busy = true;
      d.attempted = true;
      _message = null;
    });
    try {
      await widget.service.request(
        '/v1/booking/passengers',
        body: {'confirm': true, 'answers': answers},
        idempotencyKey: d.submissionKey,
      );
      d.submitted = true;
    } catch (e) {
      if (e is TravelException && e.status == 422) {
        d.attempted = false;
        if (mounted) _message = _strings(context).t('invalidField');
      } else if (mounted) {
        _message = _strings(context).t('submitUncertain');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && d.submitted) await _status();
  }

  @override
  Widget build(BuildContext context) {
    final t = _strings(context);
    Map<String, dynamic>? f;
    try {
      f = _field;
    } catch (_) {
      return _page(t.t('passengerData'), [
        _info('error', t.t('unsupportedForm')),
        _action('fallback', t.t('open'), () => _open(widget.fallbackUrl)),
      ]);
    }
    final field = f;
    return _page(t.t('passengerData'), [
      if (_busy) _info('working', t.t('working')),
      if (_message != null) _info('error', _message!),
      if (d.attempted) ...[
        _info('submitted', t.t(d.submitted ? 'submitted' : 'submitUncertain')),
        if (d.paymentUrl != null)
          _action('checkout', t.t('openCheckout'), () => _open(d.paymentUrl!)),
        if (d.submitted && d.paymentUrl == null)
          _action('status', t.t('statusRefresh'), _status, enabled: !_busy),
      ] else if (d.fields != null && field == null) ...[
        for (final item in _visibleFields)
          _info(
            'review-${item['name']}',
            '${_label(item, t)}: ${_display(item, t)}',
          ),
        _info('consent', t.t('checkData')),
        _action('submit-passengers', t.t('sendData'), _submit, enabled: !_busy),
        _action('edit', t.t('editData'), () async {
          setState(() {
            d.position = 0;
            _message = null;
          });
          await _prepare();
        }, enabled: !_busy),
      ] else if (field != null) ...[
        _info(
          'field-title',
          '${_label(field, t)}. ${t.t(_required(field) ? 'required' : 'optional')}',
        ),
        ..._inputs(field, t),
        if (_supported(field))
          _action(
            'next-field',
            t.t('nextField'),
            () => _next(),
            enabled: !_busy,
          ),
        if (!_required(field))
          _action(
            'skip-field',
            t.t('skip'),
            () => _next(skip: true),
            enabled: !_busy,
          ),
        if (d.position > 0)
          _action('previous-field', t.t('previous'), () async {
            setState(() {
              d.position--;
              _message = null;
              _busy = true;
            });
            try {
              await _prepare();
            } catch (_) {
              if (mounted) _message = t.t('unsupportedForm');
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          }, enabled: !_busy),
      ],
      _action(
        'fallback',
        t.t('open'),
        () => _open(widget.fallbackUrl),
        enabled: !_busy,
      ),
      _action('forget', t.t('forgetPassenger'), () async {
        await _memory.clear();
        if (context.mounted) {
          showStatusMessage(context, t.t('passengerForgotten'));
        }
      }, enabled: !_busy),
    ]);
  }

  String _display(Map f, TravelStrings t) {
    final value = d.values[f['name']];
    if (value == null || value == '') return t.t('notProvided');
    if (value is Map) return value.values.join(' ');
    if (_component(f) == 'Date') {
      final date = DateTime.tryParse(value.toString());
      if (date != null) return DateFormat.yMd(t.locale).format(date);
    }
    for (final option in _options(f['options'])) {
      if (option.value == value) return option.label;
    }
    if (['Country', 'CountryOfResidence'].contains(_component(f))) {
      return localizedCountryDisplayName(
        value.toString(),
        localeName: t.locale,
      );
    }
    return value.toString();
  }
}
