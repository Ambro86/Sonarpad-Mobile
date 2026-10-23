import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/universal_accessible_view.dart';

/// Await the route opened by a channel action before returning accessibility
/// focus to its originating row. A hidden/disposed list must never steal focus.
Future<void> restoreTvRowAfterAction(BuildContext context,
    AccessibleListController controller, String rowId,
    FutureOr<void> Function() action) async {
  try {
    await action();
  } finally {
    if (context.mounted) {
      await WidgetsBinding.instance.endOfFrame;
      if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
        await controller.focusAccessibleRow(rowId,
          mode: AccessibleFocusMode.routeReturnJump, animated: false);
      }
    }
  }
}
