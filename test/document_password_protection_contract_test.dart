import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/models/document_item.dart';
import 'package:sonarpad_mobile_starter/services/document_library_service.dart';

void main() {
  test('document password metadata survives JSON round trip', () {
    final doc = DocumentItem(
      id: 'doc-1',
      name: 'prova.txt',
      path: 'Documenti/prova.txt',
      extension: 'txt',
      addedAt: DateTime.utc(2026, 9, 20),
      passwordSalt: 'salt',
      passwordHash: 'hash',
    );

    final restored = DocumentItem.fromJson(doc.toJson());
    expect(restored.isPasswordProtected, isTrue);
    expect(restored.passwordSalt, 'salt');
    expect(restored.passwordHash, 'hash');
    expect(
      restored.copyWith(clearPasswordProtection: true).isPasswordProtected,
      isFalse,
    );
  });

  test('document password verification accepts only the correct password', () {
    const salt = 'test-salt';
    const password = 'Segreta 123';
    final hash = sha256.convert(utf8.encode('$salt:$password')).toString();
    final doc = DocumentItem(
      id: 'doc-2',
      name: 'prova.pdf',
      path: 'Documenti/prova.pdf',
      extension: 'pdf',
      addedAt: DateTime.utc(2026, 9, 20),
      passwordSalt: salt,
      passwordHash: hash,
    );
    final service = DocumentLibraryService();

    expect(service.verifyDocumentPassword(doc, password), isTrue);
    expect(service.verifyDocumentPassword(doc, 'sbagliata'), isFalse);
  });

  test('documents expose password protection as secondary and visual-only action', () {
    final source = File('lib/screens/documents_screen.dart').readAsStringSync();
    final shared = File('lib/widgets/universal_accessible_view.dart').readAsStringSync();
    final native = File('ios/Runner/SonarpadNativeAccessibleView.swift').readAsStringSync();

    expect(source, contains("id: 'password_protection'"));
    expect(source, contains("case 'password_protection': await _toggleDocumentPasswordProtection(doc); break;"));
    expect(source, contains("icon: doc.isPasswordProtected ? 'lock_open' : 'lock'"));
    expect(source, contains("ValueKey('document_password_\${doc.id}')"));
    expect(source, contains('CustomSemanticsAction('));
    expect(shared, contains("'lock' => Icons.lock_outline"));
    expect(shared, contains("'lock_open' => Icons.lock_open_outlined"));
    expect(native, contains('case "lock": return "lock"'));
    expect(native, contains('case "lock_open": return "lock.open"'));
    expect(native, contains('button.isAccessibilityElement = false'));
    expect(native, contains('button.accessibilityElementsHidden = true'));
  });

  test('protected documents are authorized before opening', () {
    final source = File('lib/screens/documents_screen.dart').readAsStringSync();

    expect(source, contains('Future<bool> _authorizeDocumentOpen(DocumentItem doc)'));
    expect(source, contains('prompt: l10n.enterDocumentPasswordToOpen'));
    expect(source, contains('if (!await _authorizeDocumentOpen(doc)) return;'));
    expect(source, contains('_service.verifyDocumentPassword(current, value)'));
  });

  test('protected documents are authorized before every document share path', () {
    final source = File('lib/screens/documents_screen.dart').readAsStringSync();

    expect(source, contains('Future<bool> _authorizeDocumentShare(DocumentItem doc)'));
    expect(source, contains('if (!await _authorizeDocumentShare(doc)) return;'));
    expect(source, contains('DocumentItem sourceDocument'));
    expect(source, contains('if (!await _authorizeDocumentShare(sourceDocument))'));
    expect(source, contains('SharePlus.instance.share('));
  });

  test('bookmark and edit metadata updates preserve password protection', () {
    final service = File('lib/services/document_library_service.dart').readAsStringSync();
    expect(service, contains('passwordSalt: current.passwordSalt'));
    expect(service, contains('passwordHash: current.passwordHash'));
    expect(service, contains('clearPasswordProtection: !current.isPasswordProtected'));
  });

  test('every locale contains document password protection labels', () {
    const keys = [
      'protectDocumentWithPassword',
      'removeDocumentPasswordProtection',
      'documentPassword',
      'confirmDocumentPassword',
      'chooseDocumentPassword',
      'enterCurrentDocumentPassword',
      'documentPasswordRequired',
      'documentPasswordsDoNotMatch',
      'incorrectDocumentPassword',
      'documentPasswordProtectionEnabled',
      'documentPasswordProtectionRemoved',
      'documentPasswordRequiredTitle',
      'enterDocumentPasswordToShare',
      'enterDocumentPasswordToOpen',
      'documentPasswordProtectedStatus',
    ];
    for (final entity in Directory('lib/l10n').listSync()) {
      if (entity is! File || !entity.path.endsWith('.arb')) continue;
      final data = jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
      for (final key in keys) {
        expect(data.containsKey(key), isTrue, reason: '${entity.path} missing $key');
      }
    }
  });

  test('current changelog mentions password-protected document opening and sharing in every language', () {
    final changelog = jsonDecode(File('assets/changelog.json').readAsStringSync()) as List<dynamic>;
    final current = changelog.first as Map<String, dynamic>;
    for (final entry in current.entries) {
      if (entry.key == 'version' || entry.key == 'date') continue;
      final lines = (entry.value as List).cast<String>();
      expect(
        lines.any((line) =>
            line.toLowerCase().contains('password') ||
            line.contains('mot de passe') ||
            line.contains('contraseña') ||
            line.contains('palavra-passe') ||
            line.contains('senha') ||
            line.contains('hasł') ||
            line.contains('hesl') ||
            line.toLowerCase().contains('passwort') ||
            line.contains('парол') ||
            line.contains('密码')),
        isTrue,
        reason: 'Missing password protection changelog entry for ${entry.key}',
      );
    }
  });
}
