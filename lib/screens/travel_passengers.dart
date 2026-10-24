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
  final _fieldsController = AccessibleListController();
  String? _invalidFieldId;
  bool _busy = true;
  String? _message;
  final Map<String, List<AccessibleOption>> _stateOptions = {};
  List<AccessibleOption>? _countries;
  bool _started = false;
  final Map<String, String> _choiceFilters = {};
  Timer? _filterAnnouncement;

  @override
  void dispose() {
    _filterAnnouncement?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
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
      if (!mounted) return;
      final country = _strings(context).defaultCountry;
      for (final f in d.fields!) {
        final name = f['name'] as String;
        if (['Country', 'CountryOfResidence'].contains(_component(f))) {
          final options = _options(f['options']);
          if (options.isEmpty || options.any((o) => o.value == country)) {
            d.values.putIfAbsent(name, () => country);
          }
        } else if (_component(f) == 'PhoneNumber') {
          d.values.putIfAbsent(
            name,
            () => <String, dynamic>{
              'countryDiallingCode': country == 'IT' ? '+39' : '+',
              'nationalNumber': '',
              'countryIsoCode': country,
            },
          );
        } else if (_component(f) == 'Date' &&
            name.endsWith('.dateOfBirth-0') &&
            !d.values.containsKey(name)) {
          d.values.putIfAbsent(
            '$name:parts',
            () => <String, int>{'year': 1960},
          );
        }
      }
      setState(() {});
      await _prepare();
    } catch (e) {
      if (mounted) {
        _message = e is TravelException && e.code != 'form'
            ? _error(_strings(context), e)
            : _strings(context).t('unsupportedForm');
      }
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
  List<int> get _passengerIndices =>
      (d.fields ?? [])
          .map((f) => int.parse((f['name'] as String).split('.').first))
          .toSet()
          .toList()
        ..sort();
  List<Map<String, dynamic>> get _currentFields {
    final indices = _passengerIndices;
    if (d.position >= indices.length) return [];
    return _visibleFields
        .where(
          (f) => (f['name'] as String).startsWith('${indices[d.position]}.'),
        )
        .toList();
  }

  bool _required(Map f) => (f['validation'] as List? ?? []).any(
    (r) => r is Map && r['type'] == 'required',
  );
  String _label(Map f, TravelStrings t) =>
      _plain(f['title'] ?? (f['name'] as String).split('.').last);
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
    for (final f in _currentFields) {
      if (_component(f) == 'CountryState') {
        final index = (f['name'] as String).split('.').first;
        final country = d.values['$index.addressCountry-0'];
        if (country is! String || country.isEmpty) {
          f['options'] = <dynamic>[];
          continue;
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
        if ((f['options'] as List).isEmpty) {
          unawaited(AppLogger.log('[Travel] passenger_state_options_empty'));
          throw const TravelException('form');
        }
      }
    }
  }

  void _changed(Map f, String value) {
    final name = f['name'] as String;
    d.values[name] = value;
    if (!name.endsWith('.addressCountry-0')) return;
    final prefix = '${name.split('.').first}.';
    for (final dependent in d.fields!.where(
      (f) =>
          (f['name'] as String).startsWith(prefix) &&
          _component(f) == 'CountryState',
    )) {
      dependent['options'] = <dynamic>[];
      d.values.remove(dependent['name']);
    }
    unawaited(_refreshStates());
  }

  Future<void> _refreshStates() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _prepare();
    } catch (e) {
      if (mounted) _message = _error(_strings(context), e);
    } finally {
      if (mounted) setState(() => _busy = false);
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
    void Function(String) update, {
    String? keyboardType,
  }) => AccessibleListRow(
    id: id,
    title: title,
    kind: 'textField',
    keyboardType: keyboardType,
    value: value,
    enabled: !_busy && !d.attempted,
    onValueChanged: (v) {
      if (!_busy && !d.attempted) update(v?.toString() ?? '');
    },
  );

  List<AccessibleListRow> _filteredChoice(
    String id,
    String title,
    String value,
    List<AccessibleOption> choices,
    void Function(String) update,
  ) {
    final t = _strings(context);
    final filter = _choiceFilters[id] ?? '';
    if (choices.length < 10 && filter.isEmpty) {
      return [_choice(id, title, value, choices, update)];
    }
    List<AccessibleOption> matching(String query) {
      final prefix = query.trim().toLowerCase();
      return choices
          .where((o) => o.label.trim().toLowerCase().startsWith(prefix))
          .toList();
    }

    String countLabel(int count) => count == 0
        ? t.t('filterNoResults')
        : t.t('filterResults').replaceAll('{count}', '$count');
    final filtered = matching(filter);
    final previous = choices.where((o) => o.value == value);
    return [
      _text('$id:filter', '${t.t('filterList')}: $title', filter, (query) {
        setState(() => _choiceFilters[id] = query);
        _filterAnnouncement?.cancel();
        _filterAnnouncement = Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            announceStatusMessage(context, countLabel(matching(query).length));
          }
        });
      }),
      if (filter.trim().isNotEmpty) ...[
        _info('$id:filter-count', countLabel(filtered.length)),
        if (previous.isNotEmpty && !filtered.any((o) => o.value == value))
          _info(
            '$id:retained-choice',
            '${t.t('filterRetained')}: ${previous.first.label}',
          ),
      ],
      if (filtered.isNotEmpty) _choice(id, title, value, filtered, update),
    ];
  }

  List<AccessibleListRow> _inputs(Map<String, dynamic> f, TravelStrings t) {
    final name = f['name'] as String,
        component = _component(f),
        label =
            '${_label(f, t)}. ${t.t(_required(f) ? 'required' : 'optional')}';
    final value = d.values[name];
    final options = _options(f['options']);
    if (options.isNotEmpty) {
      return _filteredChoice(
        name,
        label,
        value?.toString() ?? '',
        options,
        (v) => _changed(f, v),
      );
    }
    if (component == 'Country' || component == 'CountryOfResidence') {
      return _filteredChoice(
        name,
        label,
        value?.toString() ?? '',
        _countryOptions(t),
        (v) => _changed(f, v),
      );
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
    if (component == 'CountryState') {
      return [
        _info(
          '$name:state-status',
          t.t(_busy ? 'working' : 'stateChooseCountry'),
        ),
      ];
    }
    if (component == 'PhoneNumber') {
      final phone = Map<String, dynamic>.from(value is Map ? value : {});
      void change(String key, String v) {
        if (key == 'countryDiallingCode') {
          v = '+${v.replaceAll(RegExp(r'[^0-9]'), '')}';
        }
        if (key == 'nationalNumber') v = v.replaceAll(RegExp(r'[\s()-]'), '');
        phone[key] = v;
        d.values[name] = phone;
      }

      return [
        _text(
          '$name:prefix',
          t.t('phonePrefix'),
          phone['countryDiallingCode'] ?? '+',
          (v) => change('countryDiallingCode', v),
          keyboardType: 'phone',
        ),
        _text(
          '$name:number',
          t.t('phoneNumber'),
          phone['nationalNumber'] ?? '',
          (v) => change('nationalNumber', v),
          keyboardType: 'number',
        ),
        ..._filteredChoice(
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
        _text(
          name,
          label,
          value?.toString() ?? '',
          (v) => d.values[name] = v,
          keyboardType: component == 'Email'
              ? 'email'
              : (RegExp(
                      r'postal|postcode|zipcode|zip-\d|\.cap-\d',
                      caseSensitive: false,
                    ).hasMatch(name)
                    ? 'number'
                    : null),
        ),
      ];
    }
    if (_busy) return [];
    return [_info('unsupported-$name', t.t('unsupportedForm'))];
  }

  String? _validate(Map<String, dynamic> f) {
    final t = _strings(context), name = f['name'] as String;
    if (!_supported(f)) return t.t('unsupportedForm');
    final value = _answer(f);
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

  dynamic _answer(Map f) {
    final value = d.values[f['name']];
    if (_component(f) == 'PhoneNumber' &&
        !_required(f) &&
        value is Map &&
        (value['nationalNumber']?.toString().trim().isEmpty ?? true)) {
      return '';
    }
    return value;
  }

  void _showFieldError(Map<String, dynamic> field, String error) {
    final name = field['name'] as String;
    final inputs = _inputs(field, _strings(context));
    final target = inputs.where((row) => row.kind != 'text' && !row.id.endsWith(':filter'));
    final id = target.isEmpty ? name : target.first.id;
    setState(() {
      _message = '${_label(field, _strings(context))}: $error';
      _invalidFieldId = id;
      d.position = _passengerIndices.indexOf(int.parse(name.split('.').first));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _invalidFieldId != id) return;
      unawaited(_fieldsController.focusAccessibleRow(id));
    });
  }

  Future<void> _next() async {
    if (_busy || d.attempted) return;
    final fields = _currentFields;
    for (final f in fields) {
      final error = _validate(f);
      if (error != null) {
        _showFieldError(f, error);
        return;
      }
    }
    setState(() {
      _busy = true;
      _message = null;
      _invalidFieldId = null;
    });
    try {
      for (final f in fields) {
        final name = f['name'] as String;
        if (d.values[name] == null ||
            d.values[name] is String ||
            d.values[name] is Map) {
          await _memory.save(
            name.split('.')[1].replaceFirst(RegExp(r'-\d+$'), ''),
            d.values[name] ?? '',
            passenger: int.parse(name.split('.').first),
          );
        }
      }
      d.position++;
      await _prepare();
    } catch (e) {
      if (mounted) _message = _error(_strings(context), e);
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
        _showFieldError(f, error);
        return;
      }
      final value = _answer(f);
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
    if (_busy) {
      return Scaffold(
        appBar: SonarpadAppBar(title: Text(t.t('passengerData'))),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ExcludeSemantics(child: LinearProgressIndicator()),
                  const SizedBox(height: 24),
                  Semantics(
                    liveRegion: true,
                    child: Text(t.t('passengerLoading')),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('cancel-passenger-loading'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(t.t('cancelLoading')),
                  ),
                  if (d.attempted) ...[
                    const SizedBox(height: 16),
                    Text(t.t('cancelLoadingHelp')),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    List<Map<String, dynamic>> fields;
    try {
      fields = _currentFields;
    } catch (_) {
      return _page(t.t('passengerData'), [
        _info('error', t.t('unsupportedForm')),
        _action('fallback', t.t('open'), () => _open(widget.fallbackUrl)),
      ]);
    }
    return _page(
      t.t('passengerData'),
      [
        if (_message != null) _info('error', _message!),
        if (d.attempted) ...[
          _info(
            'submitted',
            t.t(d.submitted ? 'submitted' : 'submitUncertain'),
          ),
          if (d.paymentUrl != null)
            _action(
              'checkout',
              t.t('openCheckout'),
              () => _open(d.paymentUrl!),
            ),
          if (d.submitted && d.paymentUrl == null)
            _action('status', t.t('statusRefresh'), _status, enabled: !_busy),
        ] else if (d.fields != null && fields.isEmpty) ...[
          for (final index in _passengerIndices) ...[
            _info(
              'review-passenger-$index',
              '${t.t('passenger')} ${index + 1}',
            ),
            for (final item in _visibleFields.where(
              (f) => (f['name'] as String).startsWith('$index.'),
            ))
              _info(
                'review-${item['name']}',
                '${_label(item, t)}: ${_display(item, t)}',
              ),
          ],
          _info('consent', t.t('checkData')),
          _action(
            'submit-passengers',
            t.t('sendData'),
            _submit,
            enabled: !_busy,
            finishEditingOnActivate: true,
          ),
          _action('edit', t.t('editData'), () async {
            setState(() {
              d.position = 0;
              _message = null;
            });
            await _prepare();
          }, enabled: !_busy),
        ] else if (fields.isNotEmpty) ...[
          _info(
            'passenger-heading',
            '${t.t('passenger')} ${_passengerIndices[d.position] + 1}',
          ),
          _info('optional-hint', t.t('optionalHint')),
          for (final field in fields) ..._inputs(field, t),
          if (fields.every(_supported))
            _action('next-field', t.t('nextField'), _next, enabled: !_busy,
                finishEditingOnActivate: true),
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
      ],
      listKey: !d.attempted && d.fields != null && fields.isEmpty
          ? const ValueKey('passenger-review')
          : null,
      controller: _fieldsController,
      initialFocusId: _invalidFieldId ?? (_message != null
          ? 'error'
          : d.attempted
          ? (d.paymentUrl != null ? 'checkout' : 'submitted')
          : fields.isEmpty
          ? 'review-passenger-${_passengerIndices.first}'
          : 'passenger-heading'),
    );
  }

  String _display(Map f, TravelStrings t) {
    final value = _answer(f);
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
