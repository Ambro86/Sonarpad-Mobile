import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Shows a short visual status message without adding a temporary element to
/// the accessibility focus tree, and announces the same message to VoiceOver.
///
/// This replaces ordinary SnackBars for transient success/info/error feedback.
/// Announcements are delayed slightly so VoiceOver can finish the action label
/// that triggered the status update before the new message is spoken.
/// SnackBars are visually useful, but on iOS/VoiceOver they can sometimes become
/// focusable temporary nodes and destabilize semantics after navigation or
/// language changes.
void showStatusMessage(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
  Duration announcementDelay = const Duration(milliseconds: 300),
}) {
  final trimmedMessage = message.trim();
  if (trimmedMessage.isEmpty) return;

  final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
  final view = View.maybeOf(context);

  void announce() {
    final capturedView = view;
    if (capturedView == null) return;
    try {
      SemanticsService.sendAnnouncement(
        capturedView,
        trimmedMessage,
        direction,
      );
    } catch (_) {
      // Accessibility announcements are best-effort. The visual toast below
      // still provides feedback when a view is not available anymore.
    }
  }

  if (announcementDelay == Duration.zero) {
    announce();
  } else {
    Timer(announcementDelay, announce);
  }

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _StatusMessageOverlay.show(
    overlay: overlay,
    message: trimmedMessage,
    duration: duration,
  );
}

class _StatusMessageOverlay {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show({
    required OverlayState overlay,
    required String message,
    required Duration duration,
  }) {
    _timer?.cancel();
    _entry?.remove();

    _entry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final textStyle = theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        );

        return Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: SafeArea(
                minimum: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Material(
                    color: Colors.transparent,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.inverseSurface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 10,
                            offset: Offset(0, 4),
                            color: Color(0x33000000),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: textStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_entry!);
    _timer = Timer(duration, () {
      _entry?.remove();
      _entry = null;
      _timer = null;
    });
  }
}
