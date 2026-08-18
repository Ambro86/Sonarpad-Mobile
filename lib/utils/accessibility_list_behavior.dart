import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';

/// Keeps additional list items ready while a screen reader is active.
///
/// VoiceOver and TalkBack can move accessibility focus beyond the currently
/// painted viewport. Prebuilding a larger area prevents the focused semantic
/// node from being created only after a rapid accessibility swipe.
ScrollCacheExtent? accessibilityListCacheExtent(BuildContext context) {
  return MediaQuery.of(context).accessibleNavigation
      ? const ScrollCacheExtent.pixels(4000)
      : null;
}
