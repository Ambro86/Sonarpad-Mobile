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

int _accessibilityFocusSequence = 0;
final Map<ScrollPosition, int> _latestFocusForPosition =
    <ScrollPosition, int>{};
final Map<ScrollPosition, double> _lastFocusedLeadingOffset =
    <ScrollPosition, double>{};

String _safeAccessibilityLabel(String? label) {
  if (label == null || label.trim().isEmpty) return 'unknown';
  final compact = label.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= 140) return compact;
  return '${compact.substring(0, 137)}...';
}

void _logAccessibilityList(String message) {
  AppLogger.log('A11Y_LIST $message').ignore();
}

/// Keeps the accessibility-focused row inside a safe area of its viewport.
///
/// iOS 27 beta can stop linear VoiceOver traversal at the last semantic node
/// that is currently on screen. Waiting until the *next* off-screen node gains
/// accessibility focus is therefore too late: that focus callback may never
/// arrive. When a focused row reaches the lower part of the viewport this
/// helper proactively scrolls it upward, while keeping it visible, so that the
/// following rows enter the visible semantic window before the next VoiceOver
/// flick. The same logic is mirrored when traversing backwards.
///
/// The normal Sonarpad system log receives `A11Y_LIST` diagnostics for every
/// focus and every proactive/reveal scroll.
void keepAccessibilityFocusVisible(
  BuildContext context, {
  String? debugLabel,
}) {
  final sequence = ++_accessibilityFocusSequence;
  final label = _safeAccessibilityLabel(debugLabel);
  _logAccessibilityList('#$sequence focus label="$label"');

  // addPostFrameCallback alone does not request a new frame. On iOS 27 this
  // meant several fast VoiceOver flicks could queue before the callback ran.
  // Requesting a frame makes the accessibility reaction happen before the
  // following flick in normal use.
  final initialScrollable = Scrollable.maybeOf(context);
  if (initialScrollable != null) {
    _latestFocusForPosition[initialScrollable.position] = sequence;
  }

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

    final position = scrollable.position;
    final latest = _latestFocusForPosition[position];
    if (latest != null && latest != sequence) {
      _logAccessibilityList(
        '#$sequence skip=stale_focus latest=$latest label="$label"',
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
    final viewportExtent = position.viewportDimension;

    // Approximate the focused child's current location inside the viewport.
    // For a normal vertical list, leading-before is the child's top. The
    // trailing reveal offset lets us reconstruct the child's bottom.
    final relativeTop = leading - before;
    final relativeBottom = viewportExtent + trailing - before;

    final previousLeading = _lastFocusedLeadingOffset[position];
    final movingForward = previousLeading == null || leading >= previousLeading;
    final movingBackward = previousLeading != null && leading < previousLeading;
    _lastFocusedLeadingOffset[position] = leading;

    String action = 'none';
    double? target;

    // Main iOS 27 workaround. Do not merely reveal a row by a few pixels.
    // Move it into a safe zone while it is *still focused*, which materializes
    // and exposes several following semantic nodes before the next flick.
    final useIos27TraversalWorkaround =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    if (max > min && viewportExtent > 0) {
      final forwardTrigger = viewportExtent * 0.72;
      final backwardTrigger = viewportExtent * 0.18;

      if (useIos27TraversalWorkaround &&
          movingForward &&
          relativeBottom >= forwardTrigger) {
        // Keep the row a little below centre. This leaves enough room below for
        // the next rows without making the current VoiceOver item disappear.
        target = leading - (viewportExtent * 0.52);
        action = 'proactive_forward';
      } else if (useIos27TraversalWorkaround &&
          movingBackward &&
          relativeTop <= backwardTrigger) {
        // Symmetric protection for flicking backwards through a long list.
        target = leading - (viewportExtent * 0.30);
        action = 'proactive_backward';
      } else if (leading < before) {
        target = leading;
        action = 'reveal_start';
      } else if (trailing > before) {
        // Fallback: if geometry is unusual, at least fully reveal the row.
        target = trailing;
        action = 'reveal_end';
      }
    }

    if (target != null) {
      target = target.clamp(min, max).toDouble();
      if ((target - before).abs() < 1.0) {
        target = null;
        action = 'none';
      }
    }

    _logAccessibilityList(
      '#$sequence metrics label="$label" '
      'pixels=${before.toStringAsFixed(1)} '
      'min=${min.toStringAsFixed(1)} max=${max.toStringAsFixed(1)} '
      'viewport=${viewportExtent.toStringAsFixed(1)} '
      'leading=${leading.toStringAsFixed(1)} '
      'trailing=${trailing.toStringAsFixed(1)} '
      'top=${relativeTop.toStringAsFixed(1)} '
      'bottom=${relativeBottom.toStringAsFixed(1)} '
      'direction=${movingBackward ? 'backward' : 'forward'} '
      'action=$action'
      '${target == null ? '' : ' target=${target.toStringAsFixed(1)}'}',
    );

    if (target == null) return;

    try {
      // jumpTo is deliberate: an animation can leave the semantic tree in an
      // intermediate state while the user performs the next VoiceOver flick.
      // A zero-duration reposition is also what the native accessibility
      // scroll effectively needs here.
      position.jumpTo(target);
      final after = position.pixels;
      _logAccessibilityList(
        '#$sequence result=$action label="$label" '
        'before=${before.toStringAsFixed(1)} '
        'after=${after.toStringAsFixed(1)} '
        'moved=${(after - before).toStringAsFixed(1)}',
      );
    } catch (error) {
      _logAccessibilityList(
        '#$sequence error=$action label="$label" error="$error"',
      );
    }
  });

  WidgetsBinding.instance.scheduleFrame();
}
