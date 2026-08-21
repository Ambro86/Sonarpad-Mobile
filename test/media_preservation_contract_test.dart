import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('playable Audiodescriptions and RaiPlay Sound expose preserve media', () {
    const screens = [
      'lib/screens/audiodescription_recent_screen.dart',
      'lib/screens/audiodescription_film_screen.dart',
      'lib/screens/audiodescription_series_screen.dart',
      'lib/screens/raiplaysound_screen.dart',
    ];
    for (final path in screens) {
      final source = File(path).readAsStringSync();
      expect(source, contains("id: 'preserve_media'"), reason: path);
      expect(source, contains('l10n.preserveMedia'), reason: path);
      expect(source, contains('preserveMediaWithProgress'), reason: path);
    }
  });

  test('media preservation streams to temp, saves in Documents and shares on save failure', () {
    final source = File('lib/services/media_preservation_service.dart')
        .readAsStringSync();
    expect(source, contains("http.Request('GET'"));
    expect(source, contains('await for (final chunk in response.stream)'));
    expect(source, contains('MediaPreservationProgress'));
    expect(source, contains('MediaPreservationCancellationToken'));
    expect(source, contains('cancellationToken?.throwIfCancelled()'));
    expect(source, isNot(contains('readAsBytes')));
    expect(source, contains('DocumentLibraryService'));
    expect(source, contains('importFile('));
    expect(source, contains('SharePlus.instance.share'));
    expect(source, contains('MediaPreservationResult.sharedFallback'));
  });


  test('preserve media download uses a cancellable Material progress dialog', () {
    final source = File('lib/widgets/media_preservation_progress_dialog.dart')
        .readAsStringSync();
    expect(source, contains('AlertDialog('));
    expect(source, contains('barrierDismissible: false'));
    expect(source, contains('PopScope('));
    expect(source, contains('LinearProgressIndicator(value: fraction)'));
    expect(source, contains("'\$percent%'"));
    expect(source, contains('l10n.download'));
    expect(source, contains('l10n.preserveMediaSaving'));
    expect(source, contains('l10n.cancel'));
    expect(source, contains('token.cancel()'));
    expect(source, contains('WidgetsBinding.instance.endOfFrame'));
  });

  test('preserve media strings are localized in every ARB locale', () {
    const files = [
      'app_it.arb',
      'app_en.arb',
      'app_es.arb',
      'app_fr.arb',
      'app_de.arb',
      'app_pl.arb',
      'app_cs.arb',
      'app_pt.arb',
      'app_pt_BR.arb',
      'app_zh.arb',
      'app_zh_CN.arb',
    ];
    const keys = [
      'preserveMedia',
      'preserveMediaSaving',
      'preserveMediaSaved',
      'preserveMediaError',
      'download',
      'cancel',
    ];
    for (final file in files) {
      final data = _arb(file);
      for (final key in keys) {
        expect(data[key], isA<String>(), reason: '$file $key');
        expect((data[key] as String).trim(), isNotEmpty, reason: '$file $key');
      }
    }
  });

  test('preserve media visual controls stay out of VoiceOver and TalkBack semantics', () {
    const screens = [
      'lib/screens/audiodescription_recent_screen.dart',
      'lib/screens/audiodescription_film_screen.dart',
      'lib/screens/audiodescription_series_screen.dart',
      'lib/screens/raiplaysound_screen.dart',
    ];
    for (final path in screens) {
      final source = File(path).readAsStringSync();
      expect(source, contains('visualActionId:'), reason: path);
      expect(source, contains("'preserve_media'"), reason: path);
      expect(source, contains('ExcludeSemantics('), reason: path);
      expect(source, contains('Icons.download'), reason: path);
      expect(source, contains('CustomSemanticsAction'), reason: path);
    }

    final shared = File('lib/widgets/universal_accessible_view.dart')
        .readAsStringSync();
    expect(shared, contains('final String? visualActionId;'));
    expect(shared, contains('return ExcludeSemantics('));
    expect(shared, contains("type: 'customAction'"));

    final native = File('ios/Runner/SonarpadNativeAccessibleView.swift')
        .readAsStringSync();
    expect(native, contains('button.isAccessibilityElement = false'));
    expect(native, contains('button.accessibilityElementsHidden = true'));
    expect(native, contains('handleVisualAction'));
    expect(native, contains('cell.accessibilityCustomActions'));
  });

}
