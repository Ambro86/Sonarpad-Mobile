part of 'travel_screen.dart';

/// Each leg has its own availability and quote. A car is never copied silently
/// to another leg, and quantities represent passengers, not numbers of cabins.
class TravelFerryScreen extends StatefulWidget {
  const TravelFerryScreen({
    super.key,
    required this.service,
    required this.query,
    required this.offerChoice,
    required this.group,
  });
  final TravelService service;
  final TravelQuery query;
  final String offerChoice;
  final int group;
  @override
  State<TravelFerryScreen> createState() => _TravelFerryScreenState();
}

class _TravelFerryScreenState extends State<TravelFerryScreen> {
  Map<String, dynamic>? _config, _preview, _model;
  final _quantities = <String, int>{};
  bool _busy = true, _carAvailable = false, _car = false, _dimensions = false;
  String _plate = '';
  String? _errorText;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final config = await widget.service.request(
        '/v1/ferry/accommodations',
        query: {'offer_choice': widget.offerChoice},
      );
      if (!mounted) return;
      final vehicles = await widget.service.request(
        '/v1/ferry/vehicles',
        query: {'offer_choice': widget.offerChoice},
      );
      if (!mounted) return;
      _config = config;
      _carAvailable = ((vehicles['vehicles']?['vehicleClasses'] as List?) ?? [])
          .any((v) => v['type'] == 'CAR' && v['isSoldOut'] != true);
    } catch (e) {
      if (mounted) _errorText = _error(_strings(context), e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map get _seating => _config?['seatingOption'] as Map? ?? {};
  List<Map> get _options => [
    for (final category in _seating['seatingCategories'] as List? ?? [])
      for (final option in category['options'] as List? ?? [])
        if (option['key'] is String &&
            option['key'] != 'any' &&
            option['maxQuantity'] is int &&
            option['maxQuantity'] > 0 &&
            option['isSoldOut'] != true)
          {...option, 'category': category['name']},
  ];
  List<Map<String, dynamic>> get _items => [
    for (final e in _quantities.entries)
      if (e.value > 0) {'id': e.key, 'quantity': e.value},
  ];
  bool get _valid {
    final count = _quantities.values.fold(0, (a, b) => a + b);
    if (count == 0 && _seating['required'] != true && !_car) return true;
    return count == widget.query.ages.length &&
        (_seating['singleOptionSelection'] != true || _items.length == 1) &&
        (!_car ||
            (_model != null &&
                _dimensions &&
                RegExp(r'^[A-Za-z0-9 -]{2,20}$').hasMatch(_plate.trim())));
  }

  Future<void> _quote([String? category]) async {
    if (_busy || !_valid) return;
    if (_items.isEmpty && !_car) {
      Navigator.pop(context, <String, String>{});
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final result = await widget.service.request(
        '/v1/ferry/accommodations/preview',
        body: {
          'offer_choice': widget.offerChoice,
          'items': _items,
          if (_car)
            'vehicle': {
              'model_id': _model!['id'],
              'registration_plate': _plate.trim(),
              'confirm_dimensions': true,
              'category': ?category,
            },
        },
      );
      if (mounted) _preview = result;
    } catch (e) {
      if (mounted) _errorText = _error(_strings(context), e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseModel() async {
    final model = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _TravelVehicleModelsScreen(service: widget.service),
      ),
    );
    if (mounted && model != null) {
      setState(() {
        _model = model;
        _dimensions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _strings(context);
    final title =
        '${t.t('ferryAccommodation')} — ${t.t('group')} ${widget.group}';
    if (_busy) {
      return Scaffold(
        appBar: SonarpadAppBar(title: Text(title)),
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const ExcludeSemantics(child: LinearProgressIndicator()),
              Semantics(liveRegion: true, child: Text(t.t('passengerLoading'))),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t.t('ferryCancel')),
              ),
            ],
          ),
        ),
      );
    }
    final preview = _preview;
    if (preview != null) {
      final quote = preview['quote'] as Map? ?? {};
      final categories = preview['vehicle_options'] as List? ?? [];
      return _page(
        title,
        [
          _info('ferry-review-heading', t.t('ferryReview')),
          if (_errorText != null) _info('error', _errorText!),
          for (final item in quote['selected_items'] as List? ?? [])
            _info(
              'quote-${item['id']}',
              '${_options.where((o) => o['key'] == item['id']).map((o) => '${o['category']} — ${o['name']}').join(', ')}. ${t.t('passengers')}: ${item['quantity']}. ${_money(item['price'], widget.query.currency, t)}',
            ),
          if (quote['seating_price'] != null)
            _info(
              'aggregate',
              '${t.t('ferrySupplement')}: ${_money(quote['seating_price'], widget.query.currency, t)}',
            ),
          if (_car && _model != null) _info('model', _vehicleLabel(_model!, t)),
          if (quote['vehicle_price'] != null)
            _info(
              'vehicle-price',
              '${t.t('ferryCar')}: ${_money(quote['vehicle_price'], widget.query.currency, t)}',
            ),
          _info('price-notice', t.t('ferryPriceNotice')),
          if (preview['needs_vehicle_category'] == true)
            for (final category in categories)
              _action(
                'category-${category['externalCode']}',
                '${category['classLabel']} ${category['dimensionsLabel'] ?? ''}. ${_money(category['price'], widget.query.currency, t)}',
                () => _quote(category['externalCode'] as String),
              ),
          if (preview['selection_token'] is String)
            _action(
              'ferry-confirm',
              t.t('ferryConfirm'),
              () => Navigator.pop(context, {
                widget.offerChoice: preview['selection_token'] as String,
              }),
            ),
          _action(
            'ferry-edit',
            t.t('editData'),
            () => setState(() {
              _preview = null;
              _errorText = null;
            }),
          ),
        ],
        initialFocusId: 'ferry-review-heading',
        listKey: const ValueKey('ferry-review'),
      );
    }
    return _page(
      title,
      [
        _info('ferry-heading', title),
        if (_errorText != null) _info('error', _errorText!),
        if (_config == null)
          _action('retry', t.t('statusRefresh'), _load)
        else ...[
          _info('allocation-help', t.t('ferryAllocation')),
          for (final option in _options) _quantity(option, t),
          if (_config!['fareTerms'] != null)
            _info('terms', _plain(_config!['fareTerms'])),
          _info('car-help', t.t(_carAvailable ? 'ferryCarHelp' : 'ferryNoCar')),
          if (_carAvailable)
            AccessibleListRow(
              id: 'car-toggle',
              title: t.t('ferryCar'),
              kind: 'toggle',
              toggleValue: _car,
              onValueChanged: (v) => setState(() => _car = v == true),
            ),
          if (_car) ...[
            _action('model-search', t.t('ferryModels'), _chooseModel),
            if (_model != null) _info('car-model', _vehicleLabel(_model!, t)),
            AccessibleListRow(
              id: 'plate',
              title: t.t('ferryPlate'),
              kind: 'textField',
              value: _plate,
              onValueChanged: (v) =>
                  setState(() => _plate = v?.toString() ?? ''),
            ),
            AccessibleListRow(
              id: 'dimensions',
              title: t.t('ferryDimensions'),
              kind: 'toggle',
              toggleValue: _dimensions,
              onValueChanged: (v) => setState(() => _dimensions = v == true),
            ),
          ],
          if (!_valid) _info('selection-help', t.t('ferrySelectionHelp')),
          _action(
            'preview',
            t.t('ferryPreview'),
            _quote,
            enabled: _valid,
            finishEditingOnActivate: true,
          ),
        ],
      ],
      initialFocusId: 'ferry-heading',
      listKey: const ValueKey('ferry-options'),
    );
  }

  AccessibleListRow _quantity(Map option, TravelStrings t) {
    final id = option['key'] as String;
    final value = _quantities[id] ?? 0;
    final max = (option['maxQuantity'] as int).clamp(
      0,
      widget.query.ages.length,
    );
    return AccessibleListRow(
      id: 'quantity-$id',
      title:
          '${option['category']} — ${option['name']}. ${_money(option['price'], widget.query.currency, t)}',
      subtitle: _plain(option['description'] ?? ''),
      kind: 'slider',
      value: '$value',
      valueLabel: '$value',
      options: [
        for (var n = 0; n <= max; n++) AccessibleOption(value: n, label: '$n'),
      ],
      sliderValue: value.toDouble(),
      sliderMin: 0,
      sliderMax: max.toDouble(),
      sliderStep: 1,
      sliderIncreasedValueLabel: '${(value + 1).clamp(0, max)}',
      sliderDecreasedValueLabel: '${(value - 1).clamp(0, max)}',
      onValueChanged: (v) {
        if (v is! num || !v.isFinite) return;
        setState(() {
          if (_seating['singleOptionSelection'] == true) _quantities.clear();
          _quantities[id] = v.round().clamp(0, max);
        });
      },
    );
  }
}

String _vehicleLabel(Map model, TravelStrings t) =>
    '${model['brand']} ${model['model']} ${model['year'] ?? ''}. ${t.t('ferrySize')}: ${model['dimensions']?['length']} × ${model['dimensions']?['height']} cm';

class _TravelVehicleModelsScreen extends StatefulWidget {
  const _TravelVehicleModelsScreen({required this.service});
  final TravelService service;
  @override
  State<_TravelVehicleModelsScreen> createState() =>
      _TravelVehicleModelsScreenState();
}

class _TravelVehicleModelsScreenState
    extends State<_TravelVehicleModelsScreen> {
  String _query = '';
  Map<String, dynamic>? _results;
  String? _message;
  bool _busy = false;
  Future<void> _search([int page = 1]) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await widget.service.request(
        '/v1/ferry/vehicle-models',
        query: {'q': _query.trim(), 'page': '$page'},
      );
      if (mounted) _results = result;
    } catch (e) {
      if (mounted) _message = _error(_strings(context), e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _strings(context);
    if (_busy) {
      return _page(t.t('ferryModels'), [
        _info('loading', t.t('passengerLoading')),
        _action('cancel', t.t('ferryCancel'), () => Navigator.pop(context)),
      ], initialFocusId: 'loading');
    }
    final data = _results;
    final page = data?['pagination']?['currentPage'] as int? ?? 1;
    final pages = data?['pagination']?['totalPages'] as int? ?? 1;
    return _page(
      t.t('ferryModels'),
      [
        _info(
          'models-heading',
          t.t(data == null ? 'ferryModelHelp' : 'results'),
        ),
        if (_message != null) _info('error', _message!),
        if (data == null) ...[
          AccessibleListRow(
            id: 'model-query',
            title: t.t('ferryModels'),
            kind: 'textField',
            value: _query,
            onValueChanged: (v) => _query = v?.toString() ?? '',
          ),
          _action(
            'search',
            t.t('search'),
            _search,
            finishEditingOnActivate: true,
          ),
        ] else ...[
          for (final model in data['items'] as List? ?? [])
            _action(
              'model-${model['id']}',
              _vehicleLabel(model, t),
              () => Navigator.pop(context, Map<String, dynamic>.from(model)),
            ),
          if ((data['items'] as List? ?? []).isEmpty)
            _info('empty', t.t('empty')),
          if (page < pages)
            _action('next', t.t('next'), () => _search(page + 1)),
          if (page > 1)
            _action('previous', t.t('previous'), () => _search(page - 1)),
          _action(
            'new-search',
            t.t('search'),
            () => setState(() => _results = null),
          ),
        ],
      ],
      initialFocusId: 'models-heading',
      listKey: ValueKey('models-${data == null ? 0 : page}'),
    );
  }
}
