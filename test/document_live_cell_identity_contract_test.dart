import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('document native rows resolve their live index path before focus and activation', () {
    final nativeSource =
        File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();

    expect(nativeSource, contains('private func liveIndexPath(for cell: SonarpadAccessibleTableCell)'));
    expect(nativeSource, contains('tableView.indexPath(for: cell)'));
    expect(nativeSource, contains('DOCUMENT_LIVE_CELL_IDENTITY_CORRECTION'));

    expect(
      nativeSource,
      contains('let live = self.reconcileLiveCellIdentity(cell, reason: "focus")'),
      reason: 'VoiceOver focus must report the row currently occupied by a retained UITableViewCell.',
    );
    expect(
      nativeSource,
      contains('self.handleAccessibilityFocus(live.rowId)'),
    );

    expect(
      nativeSource,
      contains('let live = self.reconcileLiveCellIdentity(cell, reason: "activate")'),
      reason: 'A double tap after an in-place insert/delete must not use an IndexPath captured before the mutation.',
    );
    expect(nativeSource, contains('self.sendActivation(at: live.indexPath)'));
    expect(
      nativeSource,
      isNot(contains('cell.activationHandler = { [weak self] in self?.sendActivation(at: indexPath) }')),
      reason: 'Capturing the configure-time IndexPath caused the next paragraph to edit the previous one after a split.',
    );
  });

  test('document VoiceOver custom actions follow the live focused cell identity', () {
    final nativeSource =
        File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();

    expect(nativeSource, contains('var resolvedRowId = associatedRowId'));
    expect(
      nativeSource,
      contains('let live = reconcileLiveCellIdentity(focusedCell, reason: "customAction")'),
    );
    expect(
      nativeSource,
      contains('arguments: ["type": "customAction", "id": resolvedRowId, "action": actionId]'),
      reason: 'Bookmark and other rotor actions must target the paragraph VoiceOver is actually on.',
    );
  });
}
