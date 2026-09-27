import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import '../services/home_customization_service.dart';
import '../services/raiplay_service.dart';
import '../services/raiplay_sound_service.dart';
import '../services/tv_service.dart';
import '../utils/home_item_catalog.dart';
import '../widgets/universal_accessible_view.dart';

class HomeCustomizationScreen extends StatefulWidget {
  const HomeCustomizationScreen({super.key});

  @override
  State<HomeCustomizationScreen> createState() => _HomeCustomizationScreenState();
}

class _HomeCustomizationScreenState extends State<HomeCustomizationScreen> {
  final _settings = AppSettingsService();
  final _customization = HomeCustomizationService();
  bool _loading = true;
  bool _groupingEnabled = true;
  Set<String> _hiddenIds = <String>{};
  List<String> _order = List<String>.from(HomeItemIds.defaultFlatOrder);
  bool _isSecretCodeValid = false;
  bool _isTvCodeValid = false;
  bool _isRaiPlayValid = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final code = await _settings.getTvSecretCode();
    final grouping = await _settings.isHomeGroupingEnabled();
    final hidden = await _customization.loadHiddenItemIds();
    final order = await _customization.loadItemOrder();
    if (!mounted) return;
    setState(() {
      _isTvCodeValid = TvService().isSecretCodeValid(code);
      _isSecretCodeValid = RaiPlaySoundService().isSecretCodeValid(code);
      _isRaiPlayValid = RaiPlayService().isSecretCodeValid(code);
      _groupingEnabled = grouping;
      _hiddenIds = hidden;
      _order = order;
      _loading = false;
    });
  }

  Set<String> _availableIds(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return availableHomeItemIds(
      isItalian: l10n.localeName == 'it',
      isTvCodeValid: _isTvCodeValid,
      isRaiPlayValid: _isRaiPlayValid,
      isRaiPlaySoundCodeValid: _isSecretCodeValid,
    );
  }

  Future<void> _setGrouping(bool value) async {
    await _settings.setHomeGroupingEnabled(value);
    if (!mounted) return;
    setState(() => _groupingEnabled = value);
  }

  Future<void> _setVisible(String id, bool visible) async {
    await _customization.setItemVisible(id, visible);
    if (!mounted) return;
    setState(() {
      if (visible) {
        _hiddenIds.remove(id);
      } else {
        _hiddenIds.add(id);
      }
    });
  }

  Future<void> _openReorder() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HomeReorderScreen(
          availableIds: _availableIds(context),
          groupingEnabled: _groupingEnabled,
        ),
      ),
    );
    if (!mounted) return;
    _order = await _customization.loadItemOrder();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.settingsHomeCustomization)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final available = _availableIds(context);
    final customizable = HomeItemIds.defaultFlatOrder
        .where((id) =>
            available.contains(id) && !HomeItemIds.alwaysVisible.contains(id))
        .toList(growable: false);

    final modeRows = <AccessibleListRow>[
      AccessibleListRow(
        id: 'categories',
        title: l10n.homeCategories,
        subtitle: l10n.homeCategoriesHint,
        kind: 'toggle',
        toggleValue: _groupingEnabled,
        valueLabel: _groupingEnabled
            ? l10n.settingsToggleOn
            : l10n.settingsToggleOff,
      ),
      AccessibleListRow(
        id: 'reorder',
        title: l10n.homeReorderItems,
        kind: 'button',
      ),
    ];
    final visibleRows = <AccessibleListRow>[
      for (final id in customizable)
        AccessibleListRow(
          id: 'visible_$id',
          title: homeItemLabel(l10n, id),
          kind: 'toggle',
          toggleValue: !_hiddenIds.contains(id),
          valueLabel: !_hiddenIds.contains(id)
              ? l10n.settingsToggleOn
              : l10n.settingsToggleOff,
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsHomeCustomization)),
      body: UniversalAccessibleList(
        key: ValueKey(
          'home-customization-${_groupingEnabled ? 'categories' : 'flat'}-${_hiddenIds.length}-${_order.join(',')}',
        ),
        debugTag: 'home-customization',
        sections: [
          AccessibleListSection(rows: modeRows),
          AccessibleListSection(
            header: l10n.homeVisibleItems,
            rows: visibleRows,
          ),
        ],
        onEvent: (event) async {
          final id = event.id;
          if (id == 'categories' && event.type == 'toggle') {
            await _setGrouping(event.value == true);
            return;
          }
          if (id == 'reorder' && event.type == 'activate') {
            await _openReorder();
            return;
          }
          if (id != null && id.startsWith('visible_') && event.type == 'toggle') {
            await _setVisible(id.substring('visible_'.length), event.value == true);
          }
        },
      ),
    );
  }
}

class HomeReorderScreen extends StatefulWidget {
  const HomeReorderScreen({
    super.key,
    required this.availableIds,
    required this.groupingEnabled,
  });

  final Set<String> availableIds;
  final bool groupingEnabled;

  @override
  State<HomeReorderScreen> createState() => _HomeReorderScreenState();
}

class _HomeReorderScreenState extends State<HomeReorderScreen> {
  static const _readingCategoryId = 'reading';
  static const _mediaCategoryId = 'media';
  static const _utilitiesCategoryId = 'utilities';

  final _customization = HomeCustomizationService();
  bool _loading = true;
  Set<String> _hiddenIds = <String>{};
  List<String> _fullOrder = <String>[];
  final Map<String, List<String>> _categoryOrders = <String, List<String>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hidden = await _customization.loadHiddenItemIds();
    final order = await _customization.loadItemOrder();
    final readingOrder = await _customization.loadCategoryOrder(
      categoryId: _readingCategoryId,
      defaultOrder: HomeItemIds.readingOrder,
    );
    final mediaOrder = await _customization.loadCategoryOrder(
      categoryId: _mediaCategoryId,
      defaultOrder: HomeItemIds.mediaOrder,
    );
    final utilitiesOrder = await _customization.loadCategoryOrder(
      categoryId: _utilitiesCategoryId,
      defaultOrder: HomeItemIds.utilityOrder,
    );
    if (!mounted) return;
    setState(() {
      _hiddenIds = hidden;
      _fullOrder = order;
      _categoryOrders[_readingCategoryId] = readingOrder;
      _categoryOrders[_mediaCategoryId] = mediaOrder;
      _categoryOrders[_utilitiesCategoryId] = utilitiesOrder;
      _loading = false;
    });
  }

  List<String> get _visibleFlatOrder => _customization.visibleOrderedIds(
        fullOrder: _fullOrder,
        availableIds: widget.availableIds,
        hiddenIds: _hiddenIds,
      );

  List<String> _defaultOrderForCategory(String categoryId) {
    switch (categoryId) {
      case _readingCategoryId:
        return HomeItemIds.readingOrder;
      case _mediaCategoryId:
        return HomeItemIds.mediaOrder;
      case _utilitiesCategoryId:
        return HomeItemIds.utilityOrder;
      default:
        return const <String>[];
    }
  }

  String? _categoryIdForItem(String id) {
    if (HomeItemIds.readingOrder.contains(id)) return _readingCategoryId;
    if (HomeItemIds.mediaOrder.contains(id)) return _mediaCategoryId;
    if (HomeItemIds.utilityOrder.contains(id)) return _utilitiesCategoryId;
    return null;
  }

  List<String> _visibleCategoryOrder(String categoryId) {
    final defaultOrder = _defaultOrderForCategory(categoryId);
    final categoryOrder = _categoryOrders[categoryId] ?? defaultOrder;
    return _customization.visibleCategoryIds(
      categoryOrder: categoryOrder,
      availableIds: widget.availableIds,
      hiddenIds: _hiddenIds,
    );
  }

  Future<void> _moveFlat(String id, int newIndex) async {
    _fullOrder = await _customization.moveVisibleItem(
      itemId: id,
      newVisibleIndex: newIndex,
      availableIds: widget.availableIds,
      hiddenIds: _hiddenIds,
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _moveCategory(
    String categoryId,
    String id,
    int newIndex,
  ) async {
    final updated = await _customization.moveVisibleCategoryItem(
      categoryId: categoryId,
      defaultOrder: _defaultOrderForCategory(categoryId),
      itemId: id,
      newVisibleIndex: newIndex,
      availableIds: widget.availableIds,
      hiddenIds: _hiddenIds,
    );
    if (!mounted) return;
    setState(() => _categoryOrders[categoryId] = updated);
  }

  Future<void> _moveToPosition(String id) async {
    final categoryId = widget.groupingEnabled ? _categoryIdForItem(id) : null;
    if (widget.groupingEnabled && categoryId == null) return;
    final visible = categoryId == null
        ? _visibleFlatOrder
        : _visibleCategoryOrder(categoryId);
    final currentIndex = visible.indexOf(id);
    if (currentIndex < 0) return;
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _HomePositionDialog(
        currentIndex: currentIndex,
        itemIds: visible,
      ),
    );
    if (result == null || result == currentIndex) return;
    if (categoryId == null) {
      await _moveFlat(id, result);
    } else {
      await _moveCategory(categoryId, id, result);
    }
  }

  List<AccessibleListRow> _rowsFor(List<String> visible) {
    final l10n = AppLocalizations.of(context);
    return <AccessibleListRow>[
      for (var index = 0; index < visible.length; index++)
        AccessibleListRow(
          id: visible[index],
          title: homeItemLabel(l10n, visible[index]),
          kind: 'action',
          actions: [
            if (index > 0)
              AccessibleCustomAction(id: 'move_up', label: l10n.moveUp),
            if (index < visible.length - 1)
              AccessibleCustomAction(id: 'move_down', label: l10n.moveDown),
            AccessibleCustomAction(
              id: 'move_position',
              label: l10n.moveToPosition,
            ),
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.homeReorderTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final readingVisible = _visibleCategoryOrder(_readingCategoryId);
    final mediaVisible = _visibleCategoryOrder(_mediaCategoryId);
    final utilitiesVisible = _visibleCategoryOrder(_utilitiesCategoryId);
    final flatVisible = _visibleFlatOrder;

    final sections = widget.groupingEnabled
        ? <AccessibleListSection>[
            if (readingVisible.isNotEmpty)
              AccessibleListSection(
                header: l10n.categoryReading,
                rows: _rowsFor(readingVisible),
              ),
            if (mediaVisible.isNotEmpty)
              AccessibleListSection(
                header: l10n.categoryMedia,
                rows: _rowsFor(mediaVisible),
              ),
            if (utilitiesVisible.isNotEmpty)
              AccessibleListSection(
                header: l10n.categoryUtilities,
                rows: _rowsFor(utilitiesVisible),
              ),
          ]
        : <AccessibleListSection>[
            AccessibleListSection(rows: _rowsFor(flatVisible)),
          ];

    final keyOrder = widget.groupingEnabled
        ? <String>[
            ...readingVisible,
            '|',
            ...mediaVisible,
            '|',
            ...utilitiesVisible,
          ]
        : flatVisible;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeReorderTitle)),
      body: UniversalAccessibleList(
        key: ValueKey(
          'home-reorder-${widget.groupingEnabled ? 'categories' : 'flat'}-${keyOrder.join(',')}',
        ),
        debugTag: 'home-reorder',
        sections: sections,
        onEvent: (event) async {
          final id = event.id;
          if (id == null || event.type != 'customAction') return;
          final categoryId = widget.groupingEnabled ? _categoryIdForItem(id) : null;
          if (widget.groupingEnabled && categoryId == null) return;
          final visibleNow = categoryId == null
              ? _visibleFlatOrder
              : _visibleCategoryOrder(categoryId);
          final index = visibleNow.indexOf(id);
          if (index < 0) return;
          switch (event.action) {
            case 'move_up':
              if (index > 0) {
                if (categoryId == null) {
                  await _moveFlat(id, index - 1);
                } else {
                  await _moveCategory(categoryId, id, index - 1);
                }
              }
              break;
            case 'move_down':
              if (index < visibleNow.length - 1) {
                if (categoryId == null) {
                  await _moveFlat(id, index + 1);
                } else {
                  await _moveCategory(categoryId, id, index + 1);
                }
              }
              break;
            case 'move_position':
              await _moveToPosition(id);
              break;
          }
        },
      ),
    );
  }
}

class _HomePositionDialog extends StatefulWidget {
  const _HomePositionDialog({
    required this.currentIndex,
    required this.itemIds,
  });

  final int currentIndex;
  final List<String> itemIds;

  @override
  State<_HomePositionDialog> createState() => _HomePositionDialogState();
}

class _HomePositionDialogState extends State<_HomePositionDialog> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.currentIndex.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentId = widget.itemIds[widget.currentIndex];
    final targets = widget.itemIds.where((id) => id != currentId).toList();
    final maxPosition = targets.length;
    final pos = _value.round().clamp(0, maxPosition).toInt();

    String positionLabel(int position) {
      if (position >= targets.length) return l10n.positionLabelLast;
      return l10n.positionLabel(
        position + 1,
        homeItemLabel(l10n, targets[position]),
      );
    }

    final label = positionLabel(pos);
    final increasedPosition = pos < maxPosition ? pos + 1 : maxPosition;
    final decreasedPosition = pos > 0 ? pos - 1 : 0;

    return AlertDialog(
      title: Text(l10n.homeMoveItem),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Semantics(
            slider: true,
            label: l10n.homeMoveItem,
            value: label,
            increasedValue: positionLabel(increasedPosition),
            decreasedValue: positionLabel(decreasedPosition),
            onIncrease: pos < maxPosition
                ? () => setState(() => _value = (pos + 1).toDouble())
                : null,
            onDecrease: pos > 0
                ? () => setState(() => _value = (pos - 1).toDouble())
                : null,
            child: ExcludeSemantics(
              child: Slider(
                value: _value.clamp(0, maxPosition.toDouble()).toDouble(),
                min: 0,
                max: maxPosition.toDouble(),
                divisions: maxPosition > 0 ? maxPosition : null,
                onChanged: (value) => setState(() => _value = value),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(pos),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
