import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart'
    show RenderAbstractViewport, ScrollCacheExtent;
import 'package:flutter/widgets.dart';

import 'app_logger.dart';

/// Keeps additional list items ready for accessibility traversal.
///
/// On iOS we keep this enabled even when [MediaQuery.accessibleNavigation]
/// is not reported. This is intentional: VoiceOver relies on the viewport
/// cache to move accessibility focus to an off-screen child and trigger the
/// implicit scroll. iOS 27 beta can otherwise leave only the currently laid
/// out rows reachable by swipe navigation.
ScrollCacheExtent? accessibilityListCacheExtent(BuildContext context) {
  final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  if (isIos || MediaQuery.of(context).accessibleNavigation) {
    return const ScrollCacheExtent.pixels(4000);
  }
  return null;
}

/// Same policy as [accessibilityListCacheExtent], usable by scroll views that
/// do not need a [BuildContext] just to decide their cache size.
ScrollCacheExtent? accessibilityListCacheExtentForPlatform() {
  final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  final accessibleNavigation = WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .accessibleNavigation;
  if (isIos || accessibleNavigation) {
    return const ScrollCacheExtent.pixels(4000);
  }
  return null;
}

/// Makes the row that has just received screen-reader focus visible.
///
/// This is a second line of defence for iOS accessibility traversal. The
/// cache should normally let Flutter perform the implicit scroll itself, but
/// explicitly revealing the focused row avoids getting stuck on the last
/// semantic node in the current viewport if the platform misses that scroll.
int _accessibilityFocusSequence = 0;

String _safeAccessibilityLabel(String? label) {
  if (label == null || label.trim().isEmpty) return 'unknown';
  final compact = label.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= 140) return compact;
  return '${compact.substring(0, 137)}...';
}

void _logAccessibilityList(String message) {
  AppLogger.log('A11Y_LIST $message').ignore();
}

/// Keeps the accessibility-focused row visible and records enough diagnostics
/// in Sonarpad's normal system log to understand a stalled VoiceOver traversal.
///
/// [debugLabel] should identify the list/row (for example "TV guide: 18:30 -
/// News"). It is intentionally optional so generic callers can still use this
/// helper without knowing anything about the row contents.
void keepAccessibilityFocusVisible(
  BuildContext context, {
  String? debugLabel,
}) {
  final sequence = ++_accessibilityFocusSequence;
  final label = _safeAccessibilityLabel(debugLabel);
  _logAccessibilityList('#$sequence focus label="$label"');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) {
      _logAccessibilityList(
        '#$sequence abort=context_unmounted label="$label"',
      );
      return;
    }

    final object = context.findRenderObject();
    if (object == null) {
      _logAccessibilityList(
        '#$sequence abort=no_render_object label="$label"',
      );
      return;
    }
    if (!object.attached) {
      _logAccessibilityList(
        '#$sequence abort=render_object_detached label="$label"',
      );
      return;
    }

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) {
      _logAccessibilityList(
        '#$sequence abort=no_scrollable label="$label"',
      );
      return;
    }

    final viewport = RenderAbstractViewport.maybeOf(object);
    if (viewport == null) {
      _logAccessibilityList(
        '#$sequence abort=no_viewport label="$label"',
      );
      return;
    }

    final position = scrollable.position;
    if (!position.hasPixels || !position.hasContentDimensions) {
      _logAccessibilityList(
        '#$sequence abort=scroll_metrics_not_ready '
        'hasPixels=${position.hasPixels} '
        'hasContentDimensions=${position.hasContentDimensions} '
        'label="$label"',
      );
      return;
    }

    final before = position.pixels;
    final leading = viewport.getOffsetToReveal(object, 0.0).offset;
    final trailing = viewport.getOffsetToReveal(object, 1.0).offset;
    final min = position.minScrollExtent;
    final max = position.maxScrollExtent;

    ScrollPositionAlignmentPolicy? policy;
    String action = 'none';
    if (leading < before) {
      policy = ScrollPositionAlignmentPolicy.keepVisibleAtStart;
      action = 'ensure_start';
    } else if (trailing > before) {
      policy = ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
      action = 'ensure_end';
    }

    _logAccessibilityList(
      '#$sequence metrics label="$label" '
      'pixels=${before.toStringAsFixed(1)} '
      'min=${min.toStringAsFixed(1)} max=${max.toStringAsFixed(1)} '
      'leading=${leading.toStringAsFixed(1)} '
      'trailing=${trailing.toStringAsFixed(1)} action=$action',
    );

    if (policy == null) return;

    Scrollable.ensureVisible(
      context,
      duration: Duration.zero,
      alignmentPolicy: policy,
    ).then((_) {
      if (!context.mounted) {
        _logAccessibilityList(
          '#$sequence result=$action context_unmounted label="$label"',
        );
        return;
      }
      final currentScrollable = Scrollable.maybeOf(context);
      if (currentScrollable == null || !currentScrollable.position.hasPixels) {
        _logAccessibilityList(
          '#$sequence result=$action no_scroll_metrics label="$label"',
        );
        return;
      }
      final after = currentScrollable.position.pixels;
      _logAccessibilityList(
        '#$sequence result=$action label="$label" '
        'before=${before.toStringAsFixed(1)} '
        'after=${after.toStringAsFixed(1)} '
        'moved=${(after - before).toStringAsFixed(1)}',
      );
    }).catchError((Object error, StackTrace stackTrace) {
      _logAccessibilityList(
        '#$sequence error=$action label="$label" error="$error"',
      );
    }).ignore();
  });
}
