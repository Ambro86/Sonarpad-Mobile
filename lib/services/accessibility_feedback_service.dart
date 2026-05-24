import 'package:flutter/material.dart';

class AccessibilityFeedbackService {
  const AccessibilityFeedbackService._();

  static Future<T?> goNamed<T>(
    BuildContext context, {
    required String routeName,
  }) async {
    if (!context.mounted) return null;
    return Navigator.of(context).pushNamed<T>(routeName);
  }

  static Future<T?> pushRoute<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    required String routeName,
  }) async {
    if (!context.mounted) return null;
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        settings: RouteSettings(name: routeName),
        builder: builder,
      ),
    );
  }

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
