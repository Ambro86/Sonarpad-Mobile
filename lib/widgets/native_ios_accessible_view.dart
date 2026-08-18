import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool get useNativeIosAccessibleViews =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

class NativeIosOption {
  const NativeIosOption({required this.value, required this.label});
  final Object? value;
  final String label;
  Map<String, Object?> toMap() => {'value': value, 'label': label};
}

class NativeIosCustomAction {
  const NativeIosCustomAction({required this.id, required this.label});
  final String id;
  final String label;
  Map<String, Object?> toMap() => {'id': id, 'label': label};
}

class NativeIosListRow {
  const NativeIosListRow({
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
  final List<NativeIosOption> options;
  final List<NativeIosCustomAction> actions;

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

class NativeIosListSection {
  const NativeIosListSection({this.header, this.footer, required this.rows});
  final String? header;
  final String? footer;
  final List<NativeIosListRow> rows;
  Map<String, Object?> toMap() => {
        if (header != null) 'header': header,
        if (footer != null) 'footer': footer,
        'rows': rows.map((e) => e.toMap()).toList(),
      };
}

class NativeIosListEvent {
  const NativeIosListEvent({
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

typedef NativeIosListEventCallback = FutureOr<void> Function(
  NativeIosListEvent event,
);

class NativeIosListController {
  MethodChannel? _channel;

  Future<void> scrollTo(String id, {bool animated = true}) async {
    await _channel?.invokeMethod<void>('scrollTo', {
      'id': id,
      'animated': animated,
    });
  }

  void _attach(MethodChannel channel) => _channel = channel;
  void _detach(MethodChannel channel) {
    if (identical(_channel, channel)) _channel = null;
  }
}

class NativeIosAccessibleList extends StatefulWidget {
  const NativeIosAccessibleList({
    super.key,
    required this.sections,
    required this.onEvent,
    this.refreshEnabled = false,
    this.controller,
    this.fallback,
  });

  final List<NativeIosListSection> sections;
  final NativeIosListEventCallback onEvent;
  final bool refreshEnabled;
  final NativeIosListController? controller;
  final Widget? fallback;

  @override
  State<NativeIosAccessibleList> createState() =>
      _NativeIosAccessibleListState();
}

class _NativeIosAccessibleListState extends State<NativeIosAccessibleList> {
  MethodChannel? _channel;

  Map<String, Object?> get _data => {
        'sections': widget.sections.map((e) => e.toMap()).toList(),
        'refreshEnabled': widget.refreshEnabled,
      };

  @override
  void didUpdateWidget(covariant NativeIosAccessibleList oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    await widget.onEvent(
      NativeIosListEvent(
        type: raw['type']?.toString() ?? '',
        id: raw['id']?.toString(),
        value: raw['value'],
        action: raw['action']?.toString(),
      ),
    );
    if (raw['type'] == 'refresh') {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!useNativeIosAccessibleViews) {
      return widget.fallback ?? const SizedBox.shrink();
    }
    return UiKitView(
      viewType: 'sonarpad/native_accessible_list',
      creationParams: _data,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _created,
    );
  }
}

class NativeIosGridItem {
  const NativeIosGridItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.accessibilityLabel,
    this.hint,
    this.enabled = true,
  });
  final String id;
  final String title;
  final String? subtitle;
  final String? accessibilityLabel;
  final String? hint;
  final bool enabled;
  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (accessibilityLabel != null) 'accessibilityLabel': accessibilityLabel,
        if (hint != null) 'hint': hint,
        'enabled': enabled,
      };
}

class NativeIosAccessibleGrid extends StatefulWidget {
  const NativeIosAccessibleGrid({
    super.key,
    required this.items,
    required this.onActivate,
    this.columns = 2,
    this.fallback,
  });
  final List<NativeIosGridItem> items;
  final ValueChanged<String> onActivate;
  final int columns;
  final Widget? fallback;

  @override
  State<NativeIosAccessibleGrid> createState() =>
      _NativeIosAccessibleGridState();
}

class _NativeIosAccessibleGridState extends State<NativeIosAccessibleGrid> {
  MethodChannel? _channel;
  Map<String, Object?> get _data => {
        'items': widget.items.map((e) => e.toMap()).toList(),
        'columns': widget.columns,
      };

  @override
  void didUpdateWidget(covariant NativeIosAccessibleGrid oldWidget) {
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
        widget.onActivate(raw['id'].toString());
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!useNativeIosAccessibleViews) {
      return widget.fallback ?? const SizedBox.shrink();
    }
    return UiKitView(
      viewType: 'sonarpad/native_accessible_grid',
      creationParams: _data,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _created,
    );
  }
}
