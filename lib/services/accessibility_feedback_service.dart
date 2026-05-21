import 'package:flutter/material.dart';

class AccessibilityFeedbackService {
  const AccessibilityFeedbackService._();

  static Future<T?> push<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    required String routeName,
  }) async {
    if (!context.mounted) return null;
    return Navigator.push<T>(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: routeName),
        builder: builder,
      ),
    );
  }
}
