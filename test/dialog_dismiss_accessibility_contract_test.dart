import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

const _barrierOptions = {
  'showDialog': 'barrierDismissible',
  'showAdaptiveDialog': 'barrierDismissible',
  'showGeneralDialog': 'barrierDismissible',
  'showCupertinoDialog': 'barrierDismissible',
  'showDatePicker': 'barrierDismissible',
  'showDateRangePicker': 'barrierDismissible',
  'showTimePicker': 'barrierDismissible',
  'showModalBottomSheet': 'isDismissible',
  'showCupertinoModalPopup': 'semanticsDismissible',
  'DialogRoute': 'barrierDismissible',
  'RawDialogRoute': 'barrierDismissible',
  'CupertinoDialogRoute': 'barrierDismissible',
  'ModalBottomSheetRoute': 'isDismissible',
  'CupertinoModalPopupRoute': 'semanticsDismissible',
};

class _DialogVisitor extends RecursiveAstVisitor<void> {
  final failures = <String>[];
  int checked = 0;

  void check(String name, ArgumentList arguments, int offset) {
    final option = _barrierOptions[name];
    if (option == null) return;
    checked++;
    final values = arguments.arguments.whereType<NamedArgument>().where(
      (arg) => arg.name.lexeme == option,
    );
    if (values.length != 1 ||
        values.single.argumentExpression is! BooleanLiteral ||
        (values.single.argumentExpression as BooleanLiteral).value) {
      failures.add(
        '$name at offset $offset must explicitly set $option: false',
      );
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    check(node.methodName.name, node.argumentList, node.offset);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName.type
        .toSource()
        .split('<')
        .first
        .split('.')
        .last;
    check(name, node.argumentList, node.offset);
    super.visitInstanceCreationExpression(node);
  }
}

void main() {
  test(
    'every app dialog disables the redundant dismiss accessibility barrier',
    () {
      final failures = <String>[];
      var checked = 0;
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final parsed = parseString(
          content: file.readAsStringSync(),
          path: file.path,
        );
        final visitor = _DialogVisitor();
        parsed.unit.accept(visitor);
        checked += visitor.checked;
        failures.addAll(
          visitor.failures.map((failure) => '${file.path}: $failure'),
        );
      }
      expect(
        checked,
        greaterThan(100),
        reason: 'The audit must cover the entire app.',
      );
      expect(failures, isEmpty, reason: failures.join('\n'));
    },
  );

  test('audit detects defaults, true, nested dialogs and prefixed calls', () {
    final visitor = _DialogVisitor();
    parseString(
      content: '''
void example() {
  material.showDialog(context: context, builder: (_) {
    showDialog(barrierDismissible: true, builder: (_) => null);
    return null;
  });
  showDialog(barrierDismissible: false, builder: (_) => null);
  DialogRoute(barrierDismissible: false, context: context, builder: (_) => null);
  showModalBottomSheet(builder: (_) => null);
  showCupertinoModalPopup(semanticsDismissible: true, builder: (_) => null);
}
''',
    ).unit.accept(visitor);
    expect(visitor.checked, 6);
    expect(visitor.failures, hasLength(4));
  });
}
