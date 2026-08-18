import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// Global renderer mode.
///
/// Values:
/// - native (default): shared Dart model; UIKit renderer on iOS, Flutter on
///   every other platform.
/// - flutter: shared Dart model rendered by Flutter on every platform.
/// - legacy: pre-refactor Flutter screen definitions, kept only as a rollback
///   and comparison safety net.
///
/// Examples:
///   --dart-define=SONARPAD_ACCESSIBLE_RENDERER=flutter
///   --dart-define=SONARPAD_ACCESSIBLE_RENDERER=legacy
const String accessibleRendererMode = String.fromEnvironment(
  'SONARPAD_ACCESSIBLE_RENDERER',
  defaultValue: 'native',
);

bool get isIosPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

bool get isAndroidPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool get useSharedAccessibleViewModel =>
    (accessibleRendererMode == 'native' ||
        accessibleRendererMode == 'flutter') &&
    (isIosPlatform || isAndroidPlatform);

bool get useNativeIosAccessibleViews =>
    isIosPlatform && accessibleRendererMode == 'native';

class AccessibleOption {
  const AccessibleOption({required this.value, required this.label});
  final Object? value;
  final String label;
  Map<String, Object?> toMap() => {'value': value, 'label': label};
}

class AccessibleCustomAction {
  const AccessibleCustomAction({required this.id, required this.label});
  final String id;
  final String label;
  Map<String, Object?> toMap() => {'id': id, 'label': label};
}

typedef AccessibleActivateCallback = FutureOr<void> Function();
typedef AccessibleValueChangedCallback = FutureOr<void> Function(Object? value);
typedef AccessibleCustomActionCallback = FutureOr<void> Function(String actionId);

/// Platform-neutral description of one accessible row.
///
/// UIKit and Flutter consume the same data and callbacks. [flutterChild] is an
/// escape hatch for screens whose existing Android presentation must remain
/// pixel/behavior compatible; it changes presentation only, not row identity
/// or native event wiring.
class AccessibleListRow {
  const AccessibleListRow({
    required this.id,
    required this.title,
    this.subtitle,
    this.value,
    this.valueLabel,
    this.accessibilityLabel,
    this.hint,
    this.kind = 'action',
    this.enabled = true,
    this.selected = false,
    this.toggleValue = false,
    this.sliderValue = 0,
    this.sliderMin = 0,
    this.sliderMax = 1,
    this.sliderStep = 0.1,
    this.secure = false,
    this.placeholder,
    this.options = const [],
    this.actions = const [],
    this.onActivate,
    this.onValueChanged,
    this.onCustomAction,
    this.flutterChild,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? value;
  final String? valueLabel;
  final String? accessibilityLabel;
  final String? hint;
  final String kind;
  final bool enabled;
  final bool selected;
  final bool toggleValue;
  final double sliderValue;
  final double sliderMin;
  final double sliderMax;
  final double sliderStep;
  final bool secure;
  final String? placeholder;
  final List<AccessibleOption> options;
  final List<AccessibleCustomAction> actions;

  final AccessibleActivateCallback? onActivate;
  final AccessibleValueChangedCallback? onValueChanged;
  final AccessibleCustomActionCallback? onCustomAction;

  /// Optional exact Flutter presentation used on Android and when the UIKit
  /// renderer is disabled on iOS.
  final Widget? flutterChild;

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (value != null) 'value': value,
        if (valueLabel != null) 'valueLabel': valueLabel,
        if (accessibilityLabel != null) 'accessibilityLabel': accessibilityLabel,
        if (hint != null) 'hint': hint,
        'kind': kind,
        'enabled': enabled,
        'selected': selected,
        'toggleValue': toggleValue,
        'sliderValue': sliderValue,
        'sliderMin': sliderMin,
        'sliderMax': sliderMax,
        'sliderStep': sliderStep,
        'secure': secure,
        if (placeholder != null) 'placeholder': placeholder,
        'options': options.map((e) => e.toMap()).toList(),
        'actions': actions.map((e) => e.toMap()).toList(),
      };
}

class AccessibleListSection {
  const AccessibleListSection({
    this.header,
    this.footer,
    required this.rows,
    this.flutterHeader,
    this.flutterFooter,
  });
  final String? header;
  final String? footer;
  final List<AccessibleListRow> rows;
  final Widget? flutterHeader;
  final Widget? flutterFooter;

  Map<String, Object?> toMap() => {
        if (header != null) 'header': header,
        if (footer != null) 'footer': footer,
        'rows': rows.map((e) => e.toMap()).toList(),
      };
}

class AccessibleListEvent {
  const AccessibleListEvent({
    required this.type,
    this.id,
    this.value,
    this.action,
  });
  final String type;
  final String? id;
  final Object? value;
  final String? action;
}

typedef AccessibleListEventCallback = FutureOr<void> Function(
  AccessibleListEvent event,
);

class AccessibleListController {
  MethodChannel? _channel;
  Object? _flutterOwner;

  bool get hasAttachedRenderer =>
      _channel != null || _flutterScrollTo != null || _flutterFocusTo != null;
  Future<void> Function(String id, bool animated)? _flutterScrollTo;
  Future<void> Function(String id, bool animated)? _flutterFocusTo;

  Future<void> scrollTo(String id, {bool animated = true}) async {
    final channel = _channel;
    if (channel != null) {
      await channel.invokeMethod<void>('scrollTo', {
        'id': id,
        'animated': animated,
      });
      return;
    }
    await _flutterScrollTo?.call(id, animated);
  }

  Future<void> focusTo(String id, {bool animated = false}) async {
    final channel = _channel;
    if (channel != null) {
      await channel.invokeMethod<void>('focusTo', {
        'id': id,
        'animated': animated,
      });
      return;
    }
    await _flutterFocusTo?.call(id, animated);
  }

  void _attach(MethodChannel channel) => _channel = channel;
  void _detach(MethodChannel channel) {
    if (identical(_channel, channel)) _channel = null;
  }

  void _attachFlutter(
    Object owner,
    Future<void> Function(String id, bool animated) scrollTo,
    Future<void> Function(String id, bool animated) focusTo,
  ) {
    _flutterOwner = owner;
    _flutterScrollTo = scrollTo;
    _flutterFocusTo = focusTo;
  }

  void _detachFlutter(Object owner) {
    if (!identical(_flutterOwner, owner)) return;
    _flutterOwner = null;
    _flutterScrollTo = null;
    _flutterFocusTo = null;
  }
}

/// One list definition, two renderers.
///
/// The screen owns [sections] and callbacks once. On iOS this widget serializes
/// the model to UIKit; on Android (or with the global iOS switch disabled) it
/// renders the same model with Flutter.
class UniversalAccessibleList extends StatefulWidget {
  const UniversalAccessibleList({
    super.key,
    required this.sections,
    this.onEvent,
    this.onRefresh,
    this.refreshEnabled = false,
    this.controller,
    this.initialFocusId,
    this.padding = EdgeInsets.zero,
  });

  final List<AccessibleListSection> sections;
  final AccessibleListEventCallback? onEvent;
  final FutureOr<void> Function()? onRefresh;
  final bool refreshEnabled;
  final AccessibleListController? controller;
  final String? initialFocusId;
  final EdgeInsetsGeometry padding;

  @override
  State<UniversalAccessibleList> createState() =>
      _UniversalAccessibleListState();
}

class _UniversalAccessibleListState extends State<UniversalAccessibleList> {
  MethodChannel? _channel;
  final ScrollController _flutterScrollController = ScrollController();
  final Map<String, TextEditingController> _flutterTextControllers =
      <String, TextEditingController>{};
  final GlobalKey _flutterTargetKey = GlobalKey(debugLabel: 'accessible_target_row');
  String? _flutterTargetId;
  bool _initialFocusScheduled = false;

  Map<String, Object?> get _data => {
        'sections': widget.sections.map((e) => e.toMap()).toList(),
        'refreshEnabled': widget.refreshEnabled,
        if (widget.initialFocusId != null) 'initialFocusId': widget.initialFocusId,
      };

  AccessibleListRow? _rowForId(String? id) {
    if (id == null) return null;
    for (final section in widget.sections) {
      for (final row in section.rows) {
        if (row.id == id) return row;
      }
    }
    return null;
  }

  Future<void> _dispatch(AccessibleListEvent event) async {
    final row = _rowForId(event.id);
    var handledByRow = false;
    if (row != null) {
      switch (event.type) {
        case 'activate':
          if (row.onActivate != null) {
            handledByRow = true;
            await row.onActivate!.call();
          }
          break;
        case 'toggle':
        case 'slider':
        case 'picker':
        case 'textChanged':
          if (row.onValueChanged != null) {
            handledByRow = true;
            await row.onValueChanged!.call(event.value);
          }
          break;
        case 'customAction':
          if (row.onCustomAction != null && event.action != null) {
            handledByRow = true;
            await row.onCustomAction!.call(event.action!);
          }
          break;
      }
    }
    if (!handledByRow) {
      final callback = widget.onEvent;
      if (callback != null) await callback(event);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._attachFlutter(this, _flutterScrollTo, _flutterFocusTo);
  }

  List<AccessibleListRow> get _flatRows => [
        for (final section in widget.sections) ...section.rows,
      ];

  Future<void> _flutterScrollTo(String id, bool animated) async {
    if (!mounted) return;
    if (_flutterTargetId != id) {
      setState(() => _flutterTargetId = id);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    var context = _flutterTargetKey.currentContext;
    if (context == null && _flutterScrollController.hasClients) {
      final rows = _flatRows;
      final index = rows.indexWhere((row) => row.id == id);
      if (index >= 0 && rows.length > 1) {
        final ratio = index / (rows.length - 1);
        for (var attempt = 0; attempt < 4 && context == null; attempt++) {
          final position = _flutterScrollController.position;
          final target = (position.maxScrollExtent * ratio)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble();
          if (animated && attempt == 0) {
            await _flutterScrollController.animateTo(
              target,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
            );
          } else {
            _flutterScrollController.jumpTo(target);
          }
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return;
          context = _flutterTargetKey.currentContext;
        }
      }
    }
    final targetContext = context;
    if (targetContext != null && targetContext.mounted) {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.35,
        duration: animated ? const Duration(milliseconds: 180) : Duration.zero,
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _flutterFocusTo(String id, bool animated) async {
    await _flutterScrollTo(id, animated);
    if (!mounted) return;

    // FocusNode.requestFocus() moves input/keyboard focus, not the
    // accessibility focus used by VoiceOver and TalkBack. After the target
    // row is rendered and visible, ask the platform accessibility bridge to
    // move its accessibility focus to that semantics node.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _flutterTargetKey.currentContext
        ?.findRenderObject()
        ?.sendSemanticsEvent(const FocusSemanticEvent());
  }

  void _scheduleInitialFocus() {
    final id = widget.initialFocusId;
    if (_initialFocusScheduled || id == null || id.isEmpty) return;
    _initialFocusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || useNativeIosAccessibleViews) return;
      unawaited(_flutterFocusTo(id, false));
    });
  }

  @override
  void didUpdateWidget(covariant UniversalAccessibleList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detachFlutter(this);
      widget.controller?._attachFlutter(this, _flutterScrollTo, _flutterFocusTo);
    }
    if (oldWidget.initialFocusId != widget.initialFocusId) {
      _initialFocusScheduled = false;
    }
    final channel = _channel;
    if (channel != null) {
      if (!identical(oldWidget.controller, widget.controller)) {
        oldWidget.controller?._detach(channel);
        widget.controller?._attach(channel);
      }
      unawaited(channel.invokeMethod<void>('setData', _data));
    }
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    if (call.method != 'event') return null;
    final raw = Map<Object?, Object?>.from(call.arguments as Map);
    final event = AccessibleListEvent(
      type: raw['type']?.toString() ?? '',
      id: raw['id']?.toString(),
      value: raw['value'],
      action: raw['action']?.toString(),
    );
    if (event.type == 'refresh') {
      final refresh = widget.onRefresh;
      if (refresh != null) await refresh();
    }
    await _dispatch(event);
    if (event.type == 'refresh') {
      await _channel?.invokeMethod<void>('endRefresh');
    }
    return null;
  }

  void _created(int id) {
    final channel = MethodChannel('sonarpad/native_accessible_list/$id');
    _channel = channel;
    widget.controller?._attach(channel);
    channel.setMethodCallHandler(_handleMethod);
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      widget.controller?._detach(channel);
      channel.setMethodCallHandler(null);
    }
    widget.controller?._detachFlutter(this);
    _flutterScrollController.dispose();
    for (final controller in _flutterTextControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _activate(AccessibleListRow row) {
    unawaited(_dispatch(AccessibleListEvent(type: 'activate', id: row.id)));
  }

  void _change(AccessibleListRow row, String type, Object? value) {
    unawaited(_dispatch(AccessibleListEvent(type: type, id: row.id, value: value)));
  }

  Widget _withCustomActions(AccessibleListRow row, Widget child) {
    if (row.actions.isEmpty) return child;
    return Semantics(
      customSemanticsActions: {
        for (final action in row.actions)
          CustomSemanticsAction(label: action.label): () {
            unawaited(_dispatch(AccessibleListEvent(
              type: 'customAction',
              id: row.id,
              action: action.id,
            )));
          },
      },
      child: child,
    );
  }

  TextEditingController _textControllerFor(AccessibleListRow row) {
    final desired = row.value ?? '';
    final controller = _flutterTextControllers.putIfAbsent(
      row.id,
      () => TextEditingController(text: desired),
    );
    if (controller.text != desired) {
      controller.value = TextEditingValue(
        text: desired,
        selection: TextSelection.collapsed(offset: desired.length),
      );
    }
    return controller;
  }

  Widget _defaultFlutterRow(BuildContext context, AccessibleListRow row) {
    final label = row.accessibilityLabel ?? row.title;
    if (row.flutterChild != null) {
      final child = Semantics(
        label: label == row.title ? null : label,
        hint: row.hint,
        selected: row.selected,
        child: row.flutterChild!,
      );
      return _withCustomActions(row, child);
    }

    final subtitle = row.subtitle == null ? null : Text(row.subtitle!);
    final displayValue = row.valueLabel ?? row.value;
    final enabled = row.enabled;

    Widget result;
    switch (row.kind) {
      case 'header':
        result = Semantics(
          header: true,
          child: ListTile(
            title: Text(
              row.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
        break;
      case 'text':
        result = ListTile(
          title: Text(row.title),
          subtitle: subtitle,
          trailing: displayValue == null ? null : Text(displayValue),
          enabled: enabled,
        );
        break;
      case 'toggle':
        result = SwitchListTile(
          title: Text(row.title),
          subtitle: subtitle,
          value: row.toggleValue,
          onChanged: enabled
              ? (value) => _change(row, 'toggle', value)
              : null,
        );
        break;
      case 'slider':
        final span = row.sliderMax - row.sliderMin;
        final divisions = row.sliderStep > 0 && span > 0
            ? (span / row.sliderStep).round()
            : null;
        result = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(row.title),
              subtitle: subtitle,
              trailing: displayValue == null ? null : Text(displayValue),
            ),
            Slider(
              value: row.sliderValue.clamp(row.sliderMin, row.sliderMax).toDouble(),
              min: row.sliderMin,
              max: row.sliderMax,
              divisions: divisions != null && divisions > 0 ? divisions : null,
              label: displayValue,
              onChanged: enabled
                  ? (value) => _change(row, 'slider', value)
                  : null,
            ),
          ],
        );
        break;
      case 'picker':
        if (row.options.isEmpty) {
          result = ListTile(
            title: Text(row.title),
            subtitle: subtitle,
            trailing: displayValue == null ? null : Text(displayValue),
            enabled: enabled,
            onTap: enabled ? () => _activate(row) : null,
          );
          break;
        }
        Object? selectedValue;
        for (final option in row.options) {
          if (option.value.toString() == row.value) {
            selectedValue = option.value;
            break;
          }
        }
        result = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: DropdownButtonFormField<Object?>(
            initialValue: selectedValue,
            isExpanded: true,
            decoration: InputDecoration(labelText: row.title),
            items: row.options
                .map(
                  (option) => DropdownMenuItem<Object?>(
                    value: option.value,
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: enabled
                ? (value) => _change(row, 'picker', value)
                : null,
          ),
        );
        break;
      case 'textField':
        result = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: TextFormField(
            controller: _textControllerFor(row),
            obscureText: row.secure,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: row.title,
              hintText: row.placeholder,
              helperText: row.subtitle,
            ),
            onChanged: enabled
                ? (value) => _change(row, 'textChanged', value)
                : null,
          ),
        );
        break;
      case 'button':
        result = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: FilledButton(
            onPressed: enabled ? () => _activate(row) : null,
            child: Text(row.title),
          ),
        );
        break;
      case 'action':
      default:
        result = ListTile(
          title: Text(row.title),
          subtitle: subtitle,
          enabled: enabled,
          selected: row.selected,
          trailing: displayValue == null ? null : Text(displayValue),
          onTap: enabled ? () => _activate(row) : null,
        );
        break;
    }

    result = Semantics(
      label: label == row.title ? null : label,
      hint: row.hint,
      selected: row.selected,
      child: result,
    );
    return _withCustomActions(row, result);
  }

  Widget _buildFlutterModel(BuildContext context) {
    final children = <Widget>[];
    for (final section in widget.sections) {
      if (section.flutterHeader != null) {
        children.add(section.flutterHeader!);
      } else if (section.header != null && section.header!.isNotEmpty) {
        children.add(
          Semantics(
            header: true,
            child: ListTile(
              title: Text(
                section.header!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        );
      }
      for (final row in section.rows) {
        final rowChild = _defaultFlutterRow(context, row);
        if (row.id == _flutterTargetId) {
          children.add(
            KeyedSubtree(
              key: _flutterTargetKey,
              child: rowChild,
            ),
          );
        } else {
          children.add(
            KeyedSubtree(
              key: ValueKey<String>('accessible_row_${row.id}'),
              child: rowChild,
            ),
          );
        }
      }
      if (section.flutterFooter != null) {
        children.add(section.flutterFooter!);
      } else if (section.footer != null && section.footer!.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(section.footer!),
          ),
        );
      }
    }
    final listView = ListView(
      controller: _flutterScrollController,
      padding: widget.padding,
      physics: widget.refreshEnabled
          ? const AlwaysScrollableScrollPhysics()
          : null,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: children,
    );
    if (!widget.refreshEnabled) return listView;
    return RefreshIndicator(
      onRefresh: () async {
        final refresh = widget.onRefresh;
        if (refresh != null) await refresh();
        await _dispatch(const AccessibleListEvent(type: 'refresh'));
      },
      child: listView,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!useNativeIosAccessibleViews) {
      _scheduleInitialFocus();
      return _buildFlutterModel(context);
    }
    return UiKitView(
      viewType: 'sonarpad/native_accessible_list',
      creationParams: _data,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _created,
    );
  }
}

class AccessibleGridItem {
  const AccessibleGridItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.accessibilityLabel,
    this.hint,
    this.enabled = true,
    this.onActivate,
    this.flutterChild,
  });
  final String id;
  final String title;
  final String? subtitle;
  final String? accessibilityLabel;
  final String? hint;
  final bool enabled;
  final AccessibleActivateCallback? onActivate;
  final Widget? flutterChild;

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (accessibilityLabel != null) 'accessibilityLabel': accessibilityLabel,
        if (hint != null) 'hint': hint,
        'enabled': enabled,
      };
}

class UniversalAccessibleGrid extends StatefulWidget {
  const UniversalAccessibleGrid({
    super.key,
    required this.items,
    this.onActivate,
    this.columns = 2,
    this.padding = const EdgeInsets.all(16),
  });
  final List<AccessibleGridItem> items;
  final ValueChanged<String>? onActivate;
  final int columns;
  final EdgeInsetsGeometry padding;

  @override
  State<UniversalAccessibleGrid> createState() =>
      _UniversalAccessibleGridState();
}

class _UniversalAccessibleGridState extends State<UniversalAccessibleGrid> {
  MethodChannel? _channel;
  Map<String, Object?> get _data => {
        'items': widget.items.map((e) => e.toMap()).toList(),
        'columns': widget.columns,
      };

  AccessibleGridItem? _itemForId(String id) {
    for (final item in widget.items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant UniversalAccessibleGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_channel != null) {
      unawaited(_channel!.invokeMethod<void>('setData', _data));
    }
  }

  void _created(int id) {
    final channel = MethodChannel('sonarpad/native_accessible_grid/$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method != 'event') return null;
      final raw = Map<Object?, Object?>.from(call.arguments as Map);
      if (raw['type'] == 'activate' && raw['id'] != null) {
        final id = raw['id'].toString();
        final item = _itemForId(id);
        if (item?.onActivate != null) {
          await item!.onActivate!.call();
        } else {
          widget.onActivate?.call(id);
        }
      }
      return null;
    });
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  Widget _buildFlutterModel() {
    return GridView.count(
      padding: widget.padding,
      crossAxisCount: widget.columns,
      children: widget.items
          .map(
            (item) => item.flutterChild ??
                Semantics(
                  label: item.accessibilityLabel,
                  hint: item.hint,
                  button: true,
                  child: InkWell(
                    onTap: item.enabled
                        ? () {
                            if (item.onActivate != null) {
                              unawaited(Future<void>.sync(item.onActivate!));
                            } else {
                              widget.onActivate?.call(item.id);
                            }
                          }
                        : null,
                    child: Center(child: Text(item.title)),
                  ),
                ),
          )
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!useNativeIosAccessibleViews) {
      return _buildFlutterModel();
    }
    return UiKitView(
      viewType: 'sonarpad/native_accessible_grid',
      creationParams: _data,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _created,
    );
  }
}

// Compatibility aliases for code/plugins that may still refer to the old names.
typedef NativeIosOption = AccessibleOption;
typedef NativeIosCustomAction = AccessibleCustomAction;
typedef NativeIosListRow = AccessibleListRow;
typedef NativeIosListSection = AccessibleListSection;
typedef NativeIosListEvent = AccessibleListEvent;
typedef NativeIosListEventCallback = AccessibleListEventCallback;
typedef NativeIosListController = AccessibleListController;
typedef NativeIosAccessibleList = UniversalAccessibleList;
typedef NativeIosGridItem = AccessibleGridItem;
typedef NativeIosAccessibleGrid = UniversalAccessibleGrid;
