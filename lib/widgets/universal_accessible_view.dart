import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../utils/app_logger.dart';

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

// Developer-only runtime override. The compile-time value above remains the
// default used by production builds; this notifier only lets an explicitly
// unlocked developer session compare the shared Flutter renderer with UIKit
// without rebuilding the app.
final ValueNotifier<bool> _forceFlutterAccessibleRendererOnIos =
    ValueNotifier<bool>(false);

void configureAccessibleRendererRuntime({required bool useFlutterOnIos}) {
  if (_forceFlutterAccessibleRendererOnIos.value == useFlutterOnIos) return;
  _forceFlutterAccessibleRendererOnIos.value = useFlutterOnIos;
}

String get effectiveAccessibleRendererMode {
  if (accessibleRendererMode == 'legacy') return 'legacy';
  if (isIosPlatform && _forceFlutterAccessibleRendererOnIos.value) {
    return 'flutter';
  }
  if (accessibleRendererMode == 'flutter') return 'flutter';
  if (accessibleRendererMode == 'native') return 'native';
  return accessibleRendererMode;
}

bool get isIosPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

bool get isAndroidPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool get useSharedAccessibleViewModel =>
    (effectiveAccessibleRendererMode == 'native' ||
        effectiveAccessibleRendererMode == 'flutter') &&
    (isIosPlatform || isAndroidPlatform);

bool get useNativeIosAccessibleViews =>
    isIosPlatform && effectiveAccessibleRendererMode == 'native';

/// Platform-neutral capability for controls that must keep the currently
/// focused adjustable element alive while its value changes. Renderer
/// selection remains centralized in this adapter; screens only react to the
/// focus-preservation capability.
bool get preserveAccessibleSliderFocusDuringValueChange =>
    useNativeIosAccessibleViews;

/// Platform-neutral capability for the hidden developer setting. Screens do
/// not need to know which platform/renderer implements the capability.
bool get canChooseAccessibleRendererAtRuntime =>
    isIosPlatform && accessibleRendererMode != 'legacy';

bool get isUsingFlutterAccessibleRendererAtRuntime =>
    isIosPlatform && effectiveAccessibleRendererMode == 'flutter';

/// Platform-neutral capability used by shared screens during a route-return
/// focus handoff. Platform/renderer selection stays centralized here.
bool get suppressBackSemanticsDuringRouteReturn =>
    useNativeIosAccessibleViews;

/// Visual navigation control paired with [UniversalAccessibleList.persistentTopAction].
///
/// UIKit receives the persistent accessibility action from the native list, so
/// the Flutter chrome must stay visual-only there to avoid duplicate Back
/// announcements. Flutter/Android keep the normal button semantics.
class UniversalPersistentNavigationButton extends StatelessWidget {
  const UniversalPersistentNavigationButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      excluding: useNativeIosAccessibleViews,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: const BackButtonIcon(),
      ),
    );
  }
}

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

/// Sighted-only counterpart of an accessible custom action.
///
/// These controls are deliberately excluded from the semantics/accessibility
/// tree. Screen-reader users invoke the corresponding [AccessibleCustomAction]
/// on the row instead, so the action is exposed exactly once.
class AccessibleVisualAction {
  const AccessibleVisualAction({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final String icon;

  Map<String, Object?> toMap() => {
        'id': id,
        'label': label,
        'icon': icon,
      };
}

typedef AccessibleActivateCallback = FutureOr<void> Function();
typedef AccessibleValueChangedCallback = FutureOr<void> Function(Object? value);
typedef AccessibleCustomActionCallback = FutureOr<void> Function(String actionId);
typedef AccessibleFocusCallback = FutureOr<void> Function();
typedef AccessibleSubmittedCallback = FutureOr<void> Function(String value);

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
    this.accessibilityButtonTrait = true,
    this.toggleValue = false,
    this.sliderValue = 0,
    this.sliderMin = 0,
    this.sliderMax = 1,
    this.sliderStep = 0.1,
    this.sliderIncreasedValueLabel,
    this.sliderDecreasedValueLabel,
    this.nativeSliderAccessibilityElement = false,
    this.secure = false,
    this.placeholder,
    this.options = const [],
    this.actions = const [],
    this.mergeFlutterCustomActions = false,
    this.visualActions = const [],
    this.visualActionId,
    this.visualActionIcon,
    this.onActivate,
    this.onValueChanged,
    this.onCustomAction,
    this.onAccessibilityFocus,
    this.onSubmitted,
    this.textInputAction,
    this.stabilizeNativeTextFieldFocusOnBegin = false,
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
  /// Whether native accessibility should expose the row with the button trait.
  /// Keep this false for activatable text, such as document paragraphs, where
  /// double-tap/custom actions remain available without VoiceOver announcing
  /// every row as a button.
  final bool accessibilityButtonTrait;
  final bool toggleValue;
  final double sliderValue;
  final double sliderMin;
  final double sliderMax;
  final double sliderStep;
  final String? sliderIncreasedValueLabel;
  final String? sliderDecreasedValueLabel;

  /// iOS-only: expose the real native UISlider as the single VoiceOver
  /// element instead of the containing table cell. Use this for controls
  /// where native adjustable gestures must behave exactly like a standard
  /// iOS slider. Flutter/Android ignore this presentation flag.
  final bool nativeSliderAccessibilityElement;
  final bool secure;
  final String? placeholder;
  final List<AccessibleOption> options;
  final List<AccessibleCustomAction> actions;

  /// Flutter-only accessibility safeguard. When true, the row and its custom
  /// actions are merged into one semantics node so VoiceOver/TalkBack focus
  /// lands on the same node that exposes the actions. UIKit ignores this.
  final bool mergeFlutterCustomActions;

  /// Sighted-only counterparts of [actions]. They are rendered as visible
  /// controls but deliberately excluded from the accessibility tree.
  final List<AccessibleVisualAction> visualActions;

  /// Optional legacy sighted-only accessory action. It is rendered as a visible
  /// control but deliberately excluded from the accessibility tree. Screen
  /// reader users invoke the matching entry in [actions] instead.
  final String? visualActionId;
  final String? visualActionIcon;

  final AccessibleActivateCallback? onActivate;
  final AccessibleValueChangedCallback? onValueChanged;
  final AccessibleCustomActionCallback? onCustomAction;
  final AccessibleFocusCallback? onAccessibilityFocus;
  final AccessibleSubmittedCallback? onSubmitted;

  /// Optional native/Flutter keyboard return-key intent for text fields.
  /// Supported values are `search`, `done` and `next`. When [onSubmitted]
  /// is provided, UIKit sends the same logical submit event that Flutter does.
  final String? textInputAction;

  /// iOS-only VoiceOver safeguard for text fields that are activated inside a
  /// native UITableView. When true, UIKit restores accessibility focus to the
  /// same UITextField after the keyboard is actually shown, as long as that
  /// field is still first responder. Flutter/Android ignores this flag.
  final bool stabilizeNativeTextFieldFocusOnBegin;

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
        'accessibilityButtonTrait': accessibilityButtonTrait,
        'toggleValue': toggleValue,
        'sliderValue': sliderValue,
        'sliderMin': sliderMin,
        'sliderMax': sliderMax,
        'sliderStep': sliderStep,
        if (sliderIncreasedValueLabel != null)
          'sliderIncreasedValueLabel': sliderIncreasedValueLabel,
        if (sliderDecreasedValueLabel != null)
          'sliderDecreasedValueLabel': sliderDecreasedValueLabel,
        'nativeSliderAccessibilityElement': nativeSliderAccessibilityElement,
        'secure': secure,
        if (placeholder != null) 'placeholder': placeholder,
        'submitOnReturn': onSubmitted != null,
        if (textInputAction != null) 'textInputAction': textInputAction,
        'stabilizeNativeTextFieldFocusOnBegin':
            stabilizeNativeTextFieldFocusOnBegin,
        'options': options.map((e) => e.toMap()).toList(),
        'actions': actions.map((e) => e.toMap()).toList(),
        if (visualActions.isNotEmpty)
          'visualActions': visualActions.map((e) => e.toMap()).toList(),
        if (visualActionId != null) 'visualActionId': visualActionId,
        if (visualActionIcon != null) 'visualActionIcon': visualActionIcon,
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

enum AccessibleFocusMode {
  screenEntry,
  inPlaceJump,
  routeReturnJump,
  returnFocus,
}

class AccessibleListController {
  AccessibleListController({this.debugName});

  final String? debugName;
  MethodChannel? _channel;
  Object? _flutterOwner;
  ({String id, bool animated})? _pendingScroll;
  ({String id, bool animated, AccessibleFocusMode mode})? _pendingFocus;

  bool get hasAttachedRenderer =>
      _channel != null || _flutterScrollTo != null || _flutterFocusTo != null;
  bool get hasAttachedNativeRenderer => _channel != null;
  Future<void> Function(
    String id,
    bool animated,
    AccessibleFocusMode mode,
  )? _nativeFocusTo;
  Future<void> Function(String id, bool animated)? _flutterScrollTo;
  Future<void> Function(String id, bool animated)? _flutterFocusTo;

  void _debug(String message) {
    final name = debugName;
    if (name == null || name.isEmpty) return;
    unawaited(AppLogger.log('ACCESSIBLE[$name] $message'));
  }

  Future<void> scrollTo(
    String id, {
    bool animated = true,
  }) async {
    _debug('scrollTo requested id=$id animated=$animated native=${_channel != null} flutter=${_flutterScrollTo != null}');
    final channel = _channel;
    if (channel != null) {
      _debug('scrollTo dispatch native id=$id');
      await channel.invokeMethod<void>('scrollTo', {
        'id': id,
        'animated': animated,
      });
      return;
    }
    final flutterScrollTo = _flutterScrollTo;
    if (flutterScrollTo != null) {
      _debug('scrollTo dispatch flutter id=$id');
      await flutterScrollTo(id, animated);
      return;
    }
    _debug('scrollTo queued id=$id');
    _pendingScroll = (
      id: id,
      animated: animated,
    );
  }

  Future<void> focusAccessibleRow(
    String id, {
    AccessibleFocusMode mode = AccessibleFocusMode.inPlaceJump,
    bool animated = false,
  }) async {
    _debug(
      'focusAccessibleRow requested id=$id mode=${mode.name} '
      'animated=$animated native=${_channel != null} '
      'flutter=${_flutterFocusTo != null}',
    );
    final nativeFocusTo = _nativeFocusTo;
    if (_channel != null && nativeFocusTo != null) {
      _debug('focusAccessibleRow dispatch native id=$id mode=${mode.name}');
      await nativeFocusTo(id, animated, mode);
      return;
    }
    final flutterFocusTo = _flutterFocusTo;
    if (flutterFocusTo != null) {
      _debug('focusAccessibleRow dispatch flutter id=$id mode=${mode.name}');
      await flutterFocusTo(id, animated);
      return;
    }
    _debug('focusAccessibleRow queued id=$id mode=${mode.name}');
    _pendingFocus = (id: id, animated: animated, mode: mode);
  }

  Future<void> focusTo(String id, {bool animated = false}) =>
      focusAccessibleRow(
        id,
        mode: AccessibleFocusMode.inPlaceJump,
        animated: animated,
      );

  Future<void> focusToScreenEntry(String id, {bool animated = false}) =>
      focusAccessibleRow(
        id,
        mode: AccessibleFocusMode.screenEntry,
        animated: animated,
      );

  Future<void> focusToReturn(String id, {bool animated = false}) =>
      focusAccessibleRow(
        id,
        mode: AccessibleFocusMode.returnFocus,
        animated: animated,
      );

  /// Refreshes the accessibility metadata of one already-visible row without
  /// moving or recreating the list. Flutter semantics are rebuilt normally by
  /// the owning widget; UIKit uses this to invalidate VoiceOver's cached
  /// custom-action names for the currently focused cell.
  Future<void> refreshAccessibilityRow(String id) async {
    final channel = _channel;
    if (channel == null) {
      _debug('refreshAccessibilityRow flutter/no-op id=$id');
      return;
    }
    _debug('refreshAccessibilityRow native id=$id');
    await channel.invokeMethod<void>('refreshAccessibilityRow', {'id': id});
  }

  void _attach(
    MethodChannel channel,
    Future<void> Function(
      String id,
      bool animated,
      AccessibleFocusMode mode,
    ) nativeFocusTo,
  ) {
    _debug('native renderer attach pendingScroll=${_pendingScroll?.id} pendingFocus=${_pendingFocus?.id}');
    _channel = channel;
    _nativeFocusTo = nativeFocusTo;
    final pendingScroll = _pendingScroll;
    final pendingFocus = _pendingFocus;
    _pendingScroll = null;
    _pendingFocus = null;
    if (pendingScroll != null) {
      _debug('replay queued native scroll id=${pendingScroll.id}');
      unawaited(channel.invokeMethod<void>('scrollTo', {
        'id': pendingScroll.id,
        'animated': pendingScroll.animated,
      }));
    }
    if (pendingFocus != null) {
      _debug(
        'replay queued native focus id=${pendingFocus.id} '
        'mode=${pendingFocus.mode.name}',
      );
      unawaited(
        nativeFocusTo(
          pendingFocus.id,
          pendingFocus.animated,
          pendingFocus.mode,
        ),
      );
    }
  }

  void _detach(MethodChannel channel) {
    if (identical(_channel, channel)) {
      _debug('native renderer detach');
      _channel = null;
      _nativeFocusTo = null;
    }
  }

  void _attachFlutter(
    Object owner,
    Future<void> Function(String id, bool animated) scrollTo,
    Future<void> Function(String id, bool animated) focusTo,
  ) {
    _debug('flutter renderer attach');
    _flutterOwner = owner;
    _flutterScrollTo = scrollTo;
    _flutterFocusTo = focusTo;
  }

  void _detachFlutter(Object owner) {
    if (!identical(_flutterOwner, owner)) return;
    _debug('flutter renderer detach');
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
    this.showVerticalScrollIndicator = true,
    this.controller,
    this.persistentTopAction,
    this.initialFocusId,
    this.debugTag,
    this.routeReturnSemanticsSettleDelay = const Duration(milliseconds: 80),
    this.routeReturnUseFocusProxy = false,
    this.routeReturnWaitForForeignFocusClear = false,
    this.padding = EdgeInsets.zero,
  });

  final List<AccessibleListSection> sections;
  final AccessibleListEventCallback? onEvent;
  final FutureOr<void> Function()? onRefresh;
  final bool refreshEnabled;

  /// Whether the native scrolling surface should expose its vertical scroll
  /// indicator. Screens with a compact auxiliary list can hide the indicator
  /// without disabling scrolling or changing the accessibility rows.
  final bool showVerticalScrollIndicator;

  final AccessibleListController? controller;

  /// Optional route-level action that must remain reachable even while the
  /// native UIKit list is scrolled. The native renderer exposes it as a fixed
  /// accessibility element ahead of the table; Flutter keeps using the
  /// screen's normal persistent chrome (for example an AppBar back button).
  /// Keep the matching visual control outside the list when one already exists.
  final AccessibleListRow? persistentTopAction;

  final String? initialFocusId;
  final String? debugTag;
  final Duration routeReturnSemanticsSettleDelay;
  /// Use a one-shot native accessibility proxy during a fresh renderer return.
  /// The proxy is inserted before the UITableView only until VoiceOver enters
  /// it, then UIKit immediately hands focus to the real target row and restores
  /// the natural table traversal order.
  final bool routeReturnUseFocusProxy;
  /// For fresh renderer returns from another native PlatformView, wait until
  /// VoiceOver is no longer focused inside the dismissed native subtree.
  /// The target is then re-prepared before the one-shot accessibility post.
  final bool routeReturnWaitForForeignFocusClear;
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
  GlobalKey _nativeViewKey = GlobalKey(debugLabel: 'accessible_native_view');
  int _rendererGeneration = 0;
  int _focusRequestId = 0;
  int _nativeViewRecreationId = 0;
  String? _flutterTargetId;
  String? _runtimeInitialFocusId;
  String? _routeReturnFreshFocusId;
  bool _initialFocusScheduled = false;
  late bool _rendererUsesNative;

  String? get _effectiveInitialFocusId =>
      _runtimeInitialFocusId ?? widget.initialFocusId;

  Map<String, Object?> get _data => {
        'sections': widget.sections.map((e) => e.toMap()).toList(),
        'refreshEnabled': widget.refreshEnabled,
        'showVerticalScrollIndicator': widget.showVerticalScrollIndicator,
        if (widget.persistentTopAction != null)
          'persistentTopAction': widget.persistentTopAction!.toMap(),
        if (_effectiveInitialFocusId != null)
          'initialFocusId': _effectiveInitialFocusId,
        if (widget.debugTag != null) 'debugTag': widget.debugTag,
      };

  AccessibleListRow? _rowForId(String? id) {
    if (id == null) return null;
    final persistentTopAction = widget.persistentTopAction;
    if (persistentTopAction != null && persistentTopAction.id == id) {
      return persistentTopAction;
    }
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
        case 'textSubmitted':
          if (row.onSubmitted != null) {
            handledByRow = true;
            await row.onSubmitted!.call(event.value?.toString() ?? '');
          }
          break;
        case 'customAction':
          if (row.onCustomAction != null && event.action != null) {
            handledByRow = true;
            await row.onCustomAction!.call(event.action!);
          }
          break;
        case 'focus':
          // Native UIKit can report VoiceOver focus changes directly. Keep
          // these events local to the row so screens that do not care about
          // focus do not receive a new event type unexpectedly.
          handledByRow = true;
          if (row.onAccessibilityFocus != null) {
            await row.onAccessibilityFocus!.call();
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
    _rendererUsesNative = useNativeIosAccessibleViews;
    _forceFlutterAccessibleRendererOnIos.addListener(_rendererModeChanged);
    if (!_rendererUsesNative) {
      widget.controller?._attachFlutter(this, _flutterScrollTo, _flutterFocusTo);
    }
  }

  void _rendererModeChanged() {
    final nextUsesNative = useNativeIosAccessibleViews;
    if (nextUsesNative == _rendererUsesNative) return;

    _focusRequestId += 1;
    _rendererGeneration += 1;
    _initialFocusScheduled = false;

    if (_rendererUsesNative) {
      final channel = _channel;
      if (channel != null) {
        widget.controller?._detach(channel);
        channel.setMethodCallHandler(null);
      }
      _channel = null;
      widget.controller?._attachFlutter(this, _flutterScrollTo, _flutterFocusTo);
    } else {
      widget.controller?._detachFlutter(this);
      _nativeViewKey = GlobalKey(
        debugLabel: 'accessible_native_view_runtime_$_rendererGeneration',
      );
    }

    _rendererUsesNative = nextUsesNative;
    if (mounted) setState(() {});
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
      if (!_rendererUsesNative) {
        widget.controller?._attachFlutter(this, _flutterScrollTo, _flutterFocusTo);
      }
    }
    if (oldWidget.initialFocusId != widget.initialFocusId) {
      _runtimeInitialFocusId = null;
      _initialFocusScheduled = false;
      final currentChannel = _channel;
      if (currentChannel != null && useNativeIosAccessibleViews) {
        _scheduleNativeInitialFocus(currentChannel);
      }
    }
    final channel = _channel;
    if (channel != null) {
      final tag = widget.debugTag ?? widget.controller?.debugName;
      if (tag != null && tag.isNotEmpty) {
        final sliderSnapshot = <String>[
          for (final section in widget.sections)
            for (final row in section.rows)
              if (row.kind == 'slider') '${row.id}=${row.sliderValue}/${row.valueLabel ?? row.value ?? ''}',
        ].join(',');
        unawaited(AppLogger.log(
          'DOC_NATIVE[$tag] DART_WIDGET_UPDATE setDataPending=true '
          'generation=$_rendererGeneration sliders=$sliderSnapshot',
        ));
      }
      if (!identical(oldWidget.controller, widget.controller)) {
        oldWidget.controller?._detach(channel);
        widget.controller?._attach(
          channel,
          (targetId, animated, mode) => _focusAccessibleNative(
            channel,
            targetId,
            mode: mode,
            animated: animated,
          ),
        );
      }
      unawaited(channel.invokeMethod<void>('setData', _data));
    }
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    if (call.method != 'event') return null;
    final raw = Map<Object?, Object?>.from(call.arguments as Map);
    final eventType = raw['type']?.toString() ?? '';
    if (eventType == 'debug') {
      final tag = widget.debugTag ?? widget.controller?.debugName ?? 'list';
      final message = raw['message']?.toString() ?? raw.toString();
      await AppLogger.log('DOC_NATIVE[$tag] $message');
      return null;
    }
    if (eventType == 'focusDiagnostic') {
      final tag = widget.debugTag ?? widget.controller?.debugName ?? 'list';
      await AppLogger.log(
        'DOC_NATIVE[$tag] FOCUS_DIAGNOSTIC '
        'phase=${raw['phase']} id=${raw['id']} delayMs=${raw['delayMs']} '
        'requestId=${raw['requestId']} rendererGeneration=${raw['rendererGeneration']} '
        'tokensCurrent=${raw['tokensCurrent']} voiceOverRunning=${raw['voiceOverRunning']} '
        'offsetY=${raw['offsetY']} contentSizeHeight=${raw['contentSizeHeight']} '
        'boundsHeight=${raw['boundsHeight']} insetTop=${raw['adjustedInsetTop']} '
        'insetBottom=${raw['adjustedInsetBottom']} visibleCount=${raw['visibleCount']} '
        'visibleFirst=${raw['visibleFirst']} visibleLast=${raw['visibleLast']} '
        'visibleIds=${raw['visibleIds']} targetIndexPath=${raw['targetIndexPath']} '
        'targetVisible=${raw['targetVisible']} targetExists=${raw['targetExists']} '
        'targetWindow=${raw['targetWindow']} targetInRoot=${raw['targetInRoot']} '
        'targetFrameRoot=${raw['targetFrameRoot']} targetFrameWindow=${raw['targetFrameWindow']} '
        'focusedRow=${raw['focusedRow']} focusedType=${raw['focusedType']} '
        'focusedLabel=${raw['focusedLabel']} focusedEqualsTarget=${raw['focusedEqualsTarget']} '
        'rootWindow=${raw['rootWindow']} tableWindow=${raw['tableWindow']}',
      );
      return null;
    }
    final event = AccessibleListEvent(
      type: eventType,
      id: raw['id']?.toString(),
      value: raw['value'],
      action: raw['action']?.toString(),
    );
    if (event.type == 'slider') {
      final tag = widget.debugTag ?? widget.controller?.debugName ?? 'list';
      unawaited(AppLogger.log(
        'DOC_NATIVE[$tag] DART_SLIDER_EVENT_RECEIVED '
        'id=${event.id} value=${event.value} mounted=$mounted '
        'rendererNative=$_rendererUsesNative generation=$_rendererGeneration',
      ));
    }
    if (event.type == 'focus') {
      final tag = widget.debugTag ?? widget.controller?.debugName;
      if (tag != null && tag.isNotEmpty) {
        unawaited(AppLogger.log(
          'DOC_NATIVE[$tag] DART_FOCUS_EVENT id=${event.id} '
          'expected=${raw['expected']} matchesTarget=${raw['matchesTarget']} '
          'offsetY=${raw['offsetY']} visibleFirst=${raw['visibleFirst']} '
          'visibleLast=${raw['visibleLast']} visibleIds=${raw['visibleIds']} '
          'targetVisible=${raw['targetVisible']} targetExists=${raw['targetExists']} '
          'targetFrameRoot=${raw['targetFrameRoot']} rootWindow=${raw['rootWindow']} '
          'tableWindow=${raw['tableWindow']}',
        ));
      }
    }
    if (event.type == 'refresh') {
      final refresh = widget.onRefresh;
      if (refresh != null) await refresh();
    }
    await _dispatch(event);
    if (event.type == 'slider') {
      final tag = widget.debugTag ?? widget.controller?.debugName ?? 'list';
      unawaited(AppLogger.log(
        'DOC_NATIVE[$tag] DART_SLIDER_EVENT_DISPATCHED '
        'id=${event.id} value=${event.value} mounted=$mounted '
        'rendererNative=$_rendererUsesNative generation=$_rendererGeneration',
      ));
    }
    if (event.type == 'refresh') {
      await _channel?.invokeMethod<void>('endRefresh');
    }
    return null;
  }

  void _created(int id) {
    if (widget.debugTag != null || widget.controller?.debugName != null) {
      unawaited(AppLogger.log('DOC_NATIVE[${widget.debugTag ?? widget.controller?.debugName}] platform view created id=$id initialFocusId=$_effectiveInitialFocusId rows=${_flatRows.length}'));
    }
    final channel = MethodChannel('sonarpad/native_accessible_list/$id');
    _channel = channel;
    channel.setMethodCallHandler(_handleMethod);
    _rendererGeneration += 1;
    final rendererGeneration = _rendererGeneration;
    unawaited(_completeNativeAttach(channel, rendererGeneration));
  }

  Future<void> _completeNativeAttach(
    MethodChannel channel,
    int rendererGeneration,
  ) async {
    await channel.invokeMethod<void>('setRendererGeneration', {
      'rendererGeneration': rendererGeneration,
    });
    if (!mounted ||
        !identical(_channel, channel) ||
        rendererGeneration != _rendererGeneration) {
      return;
    }
    widget.controller?._attach(
      channel,
      (targetId, animated, mode) => _focusAccessibleNative(
        channel,
        targetId,
        mode: mode,
        animated: animated,
      ),
    );
    _scheduleNativeInitialFocus(channel);
  }

  Future<bool> _focusGuard(
    MethodChannel channel, {
    required int rendererGeneration,
    required int requestId,
    required String id,
    required String stage,
  }) async {
    final channelMatches = identical(_channel, channel);
    final generationMatches = rendererGeneration == _rendererGeneration;
    final requestMatches = requestId == _focusRequestId;
    final pass = mounted && channelMatches && generationMatches && requestMatches;
    final tag = widget.debugTag ?? widget.controller?.debugName;
    if (tag != null && tag.isNotEmpty) {
      unawaited(AppLogger.log(
        'DOC_NATIVE[$tag] GUARD_CHECK stage=$stage id=$id '
        'requestId=$requestId currentRequestId=$_focusRequestId '
        'rendererGeneration=$rendererGeneration '
        'currentRendererGeneration=$_rendererGeneration mounted=$mounted '
        'channelMatches=$channelMatches result=${pass ? 'pass' : 'fail'}',
      ));
    }
    return pass;
  }

  Future<void> _waitForRouteAndFrameToSettle(
    AccessibleFocusMode mode,
  ) async {
    if (mode == AccessibleFocusMode.routeReturnJump) {
      // Navigator.push() completes as soon as the child route pops, while its
      // reverse transition can still be running. On iOS 27 VoiceOver this is
      // enough to leave an already-existing UiKitView temporarily detached
      // from Flutter's active accessibility container chain. Wait for the
      // parent route's secondary animation to be fully dismissed rather than
      // guessing with a fixed 300 ms delay.
      final route = ModalRoute.of(context);
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (mounted && route != null && DateTime.now().isBefore(deadline)) {
        final primaryStable = route.animation == null ||
            route.animation!.status == AnimationStatus.completed;
        final secondaryStable = route.secondaryAnimation == null ||
            route.secondaryAnimation!.status == AnimationStatus.dismissed;
        if (route.isCurrent && primaryStable && secondaryStable) break;
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _recreateNativeRendererForRouteReturn(String id) async {
    await _waitForRouteAndFrameToSettle(AccessibleFocusMode.routeReturnJump);
    if (!mounted || !useNativeIosAccessibleViews) return;

    final tag = widget.debugTag ?? widget.controller?.debugName;
    final oldChannel = _channel;
    if (tag != null && tag.isNotEmpty) {
      final route = ModalRoute.of(context);
      unawaited(AppLogger.log(
        'DOC_NATIVE[$tag] ROUTE_RETURN_RECREATE_BEGIN id=$id '
        'routeCurrent=${route?.isCurrent} '
        'primary=${route?.animation?.status} '
        'secondary=${route?.secondaryAnimation?.status} '
        'oldRendererGeneration=$_rendererGeneration',
      ));
    }

    // A fresh UiKitView is intentional here. Initial focus on a newly-created
    // renderer is already device-validated by Document and Calendar, whereas
    // VoiceOver refuses programmatic entry into the old renderer immediately
    // after a picker route returns. Recreate only for this route-return mode;
    // normal in-place focus, state updates and Android are unchanged.
    _focusRequestId += 1;
    if (oldChannel != null) {
      widget.controller?._detach(oldChannel);
      oldChannel.setMethodCallHandler(null);
    }
    _channel = null;
    _initialFocusScheduled = false;

    _routeReturnFreshFocusId = id;
    setState(() {
      _runtimeInitialFocusId = id;
      _nativeViewRecreationId += 1;
      _nativeViewKey = GlobalKey(
        debugLabel: 'accessible_native_view_route_return_$_nativeViewRecreationId',
      );
    });

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (tag != null && tag.isNotEmpty) {
      unawaited(AppLogger.log(
        'DOC_NATIVE[$tag] ROUTE_RETURN_RECREATE_COMMITTED id=$id '
        'recreationId=$_nativeViewRecreationId',
      ));
    }
  }

  Future<void> _focusAccessibleNative(
    MethodChannel channel,
    String id, {
    required AccessibleFocusMode mode,
    required bool animated,
  }) async {
    if (!mounted || !identical(_channel, channel)) return;

    if (mode == AccessibleFocusMode.routeReturnJump) {
      await _recreateNativeRendererForRouteReturn(id);
      return;
    }

    final rendererGeneration = _rendererGeneration;
    final requestId = ++_focusRequestId;
    final tag = widget.debugTag ?? widget.controller?.debugName;
    if (tag != null && tag.isNotEmpty) {
      unawaited(AppLogger.log(
        'DOC_NATIVE[$tag] FOCUS_REQUEST id=$id mode=${mode.name} '
        'requestId=$requestId rendererGeneration=$rendererGeneration',
      ));
    }

    await _waitForRouteAndFrameToSettle(mode);
    if (!await _focusGuard(
      channel,
      rendererGeneration: rendererGeneration,
      requestId: requestId,
      id: id,
      stage: 'routeReady',
    )) {
      return;
    }
    if (tag != null && tag.isNotEmpty) {
      unawaited(AppLogger.log(
        'DOC_NATIVE[$tag] ROUTE_READY id=$id signal=endOfFrame '
        'requestId=$requestId rendererGeneration=$rendererGeneration',
      ));
    }

    // Runtime jumps never mutate initialFocusId. Ask UIKit to scroll and
    // materialize the row in the already-live renderer instance first.
    final prepared = await channel.invokeMethod<bool>(
          'prepareAccessibleFocus',
          {
            'id': id,
            'animated': animated,
            'requestId': requestId,
            'rendererGeneration': rendererGeneration,
          },
        ) ??
        false;
    if (!prepared ||
        !await _focusGuard(
          channel,
          rendererGeneration: rendererGeneration,
          requestId: requestId,
          id: id,
          stage: 'nativePrepared',
        )) {
      return;
    }

    final nativeRenderObject = _nativeViewKey.currentContext?.findRenderObject();
    final isFreshRouteReturnFocus =
        mode == AccessibleFocusMode.screenEntry &&
        _routeReturnFreshFocusId == id;
    final waitForForeignFocusClear = isFreshRouteReturnFocus &&
        widget.routeReturnWaitForForeignFocusClear;

    if (waitForForeignFocusClear) {
      if (tag != null && tag.isNotEmpty) {
        unawaited(AppLogger.log(
          'DOC_NATIVE[$tag] FOREIGN_FOCUS_GATE_BEGIN id=$id '
          'requestId=$requestId rendererGeneration=$rendererGeneration',
        ));
      }
      Map<Object?, Object?> gateOutcome;
      try {
        final rawGate = await channel.invokeMethod<dynamic>(
          'waitForForeignFocusClear',
          {
            'id': id,
            'requestId': requestId,
            'rendererGeneration': rendererGeneration,
            'timeoutMs': 2400,
          },
        ).timeout(const Duration(seconds: 3));
        gateOutcome = rawGate is Map
            ? Map<Object?, Object?>.from(rawGate)
            : <Object?, Object?>{'cleared': false, 'reason': 'unexpectedGateResult'};
      } on TimeoutException {
        gateOutcome = <Object?, Object?>{
          'cleared': false,
          'reason': 'foreignFocusGateTimeout',
        };
      }
      if (tag != null && tag.isNotEmpty) {
        unawaited(AppLogger.log(
          'DOC_NATIVE[$tag] FOREIGN_FOCUS_GATE_END id=$id '
          'requestId=$requestId outcome=$gateOutcome',
        ));
      }
      if (!await _focusGuard(
        channel,
        rendererGeneration: rendererGeneration,
        requestId: requestId,
        id: id,
        stage: 'afterForeignFocusGate',
      )) {
        return;
      }

      // The dismissed native letter picker may have caused UIKit to adjust the
      // table while its stale VoiceOver focus was being torn down. Re-center
      // and materialize the real target only after that old focus is gone.
      final reprepared = await channel.invokeMethod<bool>(
            'prepareAccessibleFocus',
            {
              'id': id,
              'animated': false,
              'requestId': requestId,
              'rendererGeneration': rendererGeneration,
            },
          ) ??
          false;
      if (!reprepared ||
          !await _focusGuard(
            channel,
            rendererGeneration: rendererGeneration,
            requestId: requestId,
            id: id,
            stage: 'afterForeignFocusReprepare',
          )) {
        return;
      }
      if (tag != null && tag.isNotEmpty) {
        unawaited(AppLogger.log(
          'DOC_NATIVE[$tag] FOREIGN_FOCUS_REPREPARED id=$id '
          'requestId=$requestId',
        ));
      }
    }

    if (tag != null && tag.isNotEmpty) {
      unawaited(AppLogger.log(
        'DOC_NATIVE[$tag] SEMANTICS_FOCUS_SENT id=$id '
        'requestId=$requestId render=${nativeRenderObject?.runtimeType}',
      ));
    }
    nativeRenderObject?.sendSemanticsEvent(const FocusSemanticEvent());

    // Some picker-return flows benefit from a short semantics settling
    // window after recreating the UiKitView, while others (notably alphabetic
    // jumps) work better when the native target is posted immediately. Keep
    // the policy configurable per list and leave ordinary focus paths alone.
    await WidgetsBinding.instance.endOfFrame;
    final routeReturnSettleDelay = widget.routeReturnSemanticsSettleDelay;
    if (isFreshRouteReturnFocus && routeReturnSettleDelay > Duration.zero) {
      if (tag != null && tag.isNotEmpty) {
        unawaited(AppLogger.log(
          'DOC_NATIVE[$tag] ROUTE_RETURN_SEMANTICS_SETTLE_BEGIN id=$id '
          'requestId=$requestId delayMs=${routeReturnSettleDelay.inMilliseconds}',
        ));
      }
      await Future<void>.delayed(routeReturnSettleDelay);
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (tag != null && tag.isNotEmpty) {
        unawaited(AppLogger.log(
          'DOC_NATIVE[$tag] ROUTE_RETURN_SEMANTICS_SETTLE_END id=$id '
          'requestId=$requestId',
        ));
      }
    }
    if (!await _focusGuard(
      channel,
      rendererGeneration: rendererGeneration,
      requestId: requestId,
      id: id,
      stage: 'afterSemantics',
    )) {
      return;
    }

    // Reuse the native method names that are already proven on this exact
    // per-PlatformView MethodChannel. The payload still carries the unified
    // focus mode and request/renderer tokens; Swift routes both names through
    // the same generic one-shot focus implementation.
    final nativeMethod = mode == AccessibleFocusMode.screenEntry
        ? 'focusInitial'
        : 'focusTo';
    final useFocusProxy =
        isFreshRouteReturnFocus && widget.routeReturnUseFocusProxy;
    final postFocusDiagnostics = waitForForeignFocusClear || useFocusProxy;
    if (tag != null && tag.isNotEmpty) {
      unawaited(AppLogger.log(
        'DOC_NATIVE[$tag] NATIVE_DISPATCH id=$id method=$nativeMethod '
        'mode=${mode.name} useFocusProxy=$useFocusProxy '
        'waitForForeignFocusClear=$waitForForeignFocusClear requestId=$requestId '
        'rendererGeneration=$rendererGeneration channelIdentity=${identityHashCode(channel)}',
      ));
    }
    Map<Object?, Object?> outcome;
    try {
      final rawOutcome = await channel.invokeMethod<dynamic>(
        nativeMethod,
        {
          'id': id,
          'mode': mode.name,
          'animated': animated,
          'requestId': requestId,
          'rendererGeneration': rendererGeneration,
          'useFocusProxy': useFocusProxy,
          'postFocusDiagnostics': postFocusDiagnostics,
        },
      ).timeout(const Duration(seconds: 2));
      if (rawOutcome is Map) {
        outcome = Map<Object?, Object?>.from(rawOutcome);
      } else if (rawOutcome is bool) {
        // Compatibility with an older native build.
        outcome = <Object?, Object?>{
          'posted': rawOutcome,
          'reason': rawOutcome ? 'legacyAccepted' : 'legacyRejected',
        };
      } else {
        outcome = <Object?, Object?>{
          'posted': false,
          'reason': 'unexpectedNativeResult:${rawOutcome.runtimeType}',
        };
      }
    } on TimeoutException {
      outcome = <Object?, Object?>{
        'posted': false,
        'reason': 'nativeResultTimeout',
      };
    }
    if (tag != null && tag.isNotEmpty) {
      final posted = outcome['posted'] == true;
      final reason = outcome['reason']?.toString() ?? 'unknown';
      final notification = outcome['notification']?.toString() ?? 'unknown';
      unawaited(AppLogger.log(
        'DOC_NATIVE[$tag] NATIVE_RESULT id=$id method=$nativeMethod '
        'mode=${mode.name} requestId=$requestId posted=$posted '
        'reason=$reason notification=$notification outcome=$outcome',
      ));
    }
    if (isFreshRouteReturnFocus && _routeReturnFreshFocusId == id) {
      _routeReturnFreshFocusId = null;
    }
  }

  void _scheduleNativeInitialFocus(MethodChannel channel) {
    final id = _effectiveInitialFocusId;
    if (_initialFocusScheduled ||
        id == null ||
        id.isEmpty ||
        !useNativeIosAccessibleViews) {
      return;
    }
    _initialFocusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _focusAccessibleNative(
          channel,
          id,
          mode: AccessibleFocusMode.screenEntry,
          animated: false,
        ),
      );
    });
  }

  @override
  void dispose() {
    _forceFlutterAccessibleRendererOnIos.removeListener(_rendererModeChanged);
    _focusRequestId += 1;
    _rendererGeneration += 1;
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

  Future<void> _showAndroidSecondaryActions(AccessibleListRow row) async {
    if (!isAndroidPlatform || row.actions.isEmpty || !mounted) return;

    final actionId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(MaterialLocalizations.of(dialogContext).moreButtonTooltip),
        children: [
          for (final action in row.actions)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(action.id),
              child: Text(action.label),
            ),
        ],
      ),
    );
    if (actionId == null || !mounted) return;

    unawaited(_dispatch(AccessibleListEvent(
      type: 'customAction',
      id: row.id,
      action: actionId,
    )));
  }

  Widget _withCustomActions(AccessibleListRow row, Widget child) {
    if (row.actions.isEmpty && row.onAccessibilityFocus == null) return child;
    final semantics = Semantics(
      onDidGainAccessibilityFocus: row.onAccessibilityFocus == null
          ? null
          : () => unawaited(
              Future<void>.sync(row.onAccessibilityFocus!),
            ),
      // Android/TalkBack: double tap and hold invokes the semantic long-press
      // action. Expose the same existing secondary actions in a standard
      // accessible dialog instead of duplicating their callbacks. iOS keeps
      // using UIAccessibilityCustomAction/VoiceOver rotor unchanged.
      onLongPress: isAndroidPlatform && row.actions.isNotEmpty
          ? () => unawaited(_showAndroidSecondaryActions(row))
          : null,
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
    if (row.mergeFlutterCustomActions && row.actions.isNotEmpty) {
      return MergeSemantics(child: semantics);
    }
    return semantics;
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

  IconData _visualActionIcon(String? name) => switch (name) {
        'download' => Icons.download,
        'save' => Icons.save_alt,
        'favorite' => Icons.favorite_border,
        'favorite_filled' => Icons.favorite,
        'share' => Icons.share,
        'channel' => Icons.account_circle_outlined,
        'comments' => Icons.comment_outlined,
        'transcript' => Icons.subject,
        'podcast_add' => Icons.podcasts,
        'remove' => Icons.delete_outline,
        'edit' => Icons.edit_outlined,
        'play' => Icons.play_arrow,
        'record' => Icons.fiber_manual_record,
        _ => Icons.more_horiz,
      };

  Widget _visualActionControl(
    AccessibleListRow row, {
    required String actionId,
    required String label,
    required String? icon,
  }) {
    return IconButton(
      tooltip: label.isEmpty ? null : label,
      icon: Icon(_visualActionIcon(icon)),
      onPressed: row.enabled
          ? () => unawaited(_dispatch(AccessibleListEvent(
                type: 'customAction',
                id: row.id,
                action: actionId,
              )))
          : null,
    );
  }

  Widget? _visualActionButtons(AccessibleListRow row) {
    final actions = row.visualActions;
    if (actions.isNotEmpty) {
      return ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: actions
              .map(
                (action) => _visualActionControl(
                  row,
                  actionId: action.id,
                  label: action.label,
                  icon: action.icon,
                ),
              )
              .toList(growable: false),
        ),
      );
    }

    final actionId = row.visualActionId;
    if (actionId == null || actionId.isEmpty) return null;
    return ExcludeSemantics(
      child: _visualActionControl(
        row,
        actionId: actionId,
        label: '',
        icon: row.visualActionIcon,
      ),
    );
  }

  Widget? _rowTrailing(AccessibleListRow row, String? displayValue) {
    final visualActions = _visualActionButtons(row);
    if (visualActions == null) {
      return displayValue == null ? null : Text(displayValue);
    }
    if (displayValue == null) return visualActions;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Text(displayValue), visualActions],
    );
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
        final currentValue =
            row.sliderValue.clamp(row.sliderMin, row.sliderMax).toDouble();
        final increasedRaw =
            (currentValue + row.sliderStep).clamp(row.sliderMin, row.sliderMax);
        final decreasedRaw =
            (currentValue - row.sliderStep).clamp(row.sliderMin, row.sliderMax);
        result = Semantics(
          slider: true,
          label: row.accessibilityLabel ?? row.title,
          value: displayValue,
          increasedValue: row.sliderIncreasedValueLabel,
          decreasedValue: row.sliderDecreasedValueLabel,
          hint: row.hint,
          enabled: enabled,
          onIncrease: enabled
              ? () => _change(row, 'slider', increasedRaw.toDouble())
              : null,
          onDecrease: enabled
              ? () => _change(row, 'slider', decreasedRaw.toDouble())
              : null,
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  title: Text(row.title),
                  subtitle: subtitle,
                  trailing:
                      displayValue == null ? null : Text(displayValue),
                ),
                Slider(
                  value: currentValue,
                  min: row.sliderMin,
                  max: row.sliderMax,
                  divisions:
                      divisions != null && divisions > 0 ? divisions : null,
                  label: displayValue,
                  onChanged: enabled
                      ? (value) => _change(row, 'slider', value)
                      : null,
                ),
              ],
            ),
          ),
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
            textInputAction: switch (row.textInputAction) {
              'search' => TextInputAction.search,
              'next' => TextInputAction.next,
              'done' => TextInputAction.done,
              _ => null,
            },
            onChanged: enabled
                ? (value) => _change(row, 'textChanged', value)
                : null,
            onFieldSubmitted: enabled && row.onSubmitted != null
                ? (value) => _change(row, 'textSubmitted', value)
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
          trailing: _rowTrailing(row, displayValue),
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
    if (!_rendererUsesNative) {
      _scheduleInitialFocus();
      return _buildFlutterModel(context);
    }
    return UiKitView(
      key: _nativeViewKey,
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
  late bool _rendererUsesNative;
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
  void initState() {
    super.initState();
    _rendererUsesNative = useNativeIosAccessibleViews;
    _forceFlutterAccessibleRendererOnIos.addListener(_rendererModeChanged);
  }

  void _rendererModeChanged() {
    final nextUsesNative = useNativeIosAccessibleViews;
    if (nextUsesNative == _rendererUsesNative) return;
    if (_rendererUsesNative) {
      _channel?.setMethodCallHandler(null);
      _channel = null;
    }
    _rendererUsesNative = nextUsesNative;
    if (mounted) setState(() {});
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
    _forceFlutterAccessibleRendererOnIos.removeListener(_rendererModeChanged);
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
    if (!_rendererUsesNative) {
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
