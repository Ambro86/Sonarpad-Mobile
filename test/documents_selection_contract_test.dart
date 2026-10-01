import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('documents mirrors recordings multi-selection without duplicating VoiceOver actions', () {
    final documents = File('lib/screens/documents_screen.dart').readAsStringSync();
    final dialog = File('lib/widgets/document_selection_dialog.dart').readAsStringSync();
    final shared = File('lib/widgets/universal_accessible_view.dart').readAsStringSync();
    final native = File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();

    expect(documents, contains("tooltip: l10n.selectDocuments"));
    expect(documents, contains("key: const ValueKey('documents_select_action')"));
    expect(documents, contains("id: 'select'"));
    expect(documents, contains("icon: 'select'"));
    expect(documents, contains("ValueKey('document_select_\${doc.id}')"));
    expect(documents, contains('ExcludeSemantics('));
    expect(documents, contains('showDocumentSelectionDialog('));
    expect(documents, contains('DocumentSelectionAction.share'));
    expect(documents, contains('DocumentSelectionAction.delete'));
    expect(documents, contains('SharePlus.instance.share('));
    expect(documents, contains('_removeDocuments('));

    expect(dialog, contains("kind: 'toggle'"));
    expect(dialog, contains("'document_selection_select_all'"));
    expect(dialog, contains('l10n.deleteSelectedDocumentsConfirmation'));
    expect(dialog, contains('l10n.selectionActionCount('));

    expect(shared, contains("'select' => Icons.check_box_outlined"));
    expect(native, contains('case "select": return "checkmark.square"'));
    expect(native, contains('button.isAccessibilityElement = false'));
    expect(native, contains('stack.accessibilityElementsHidden = true'));
  });
}
