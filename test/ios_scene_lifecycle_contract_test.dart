import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

ProcessResult verify(List<String> args) => Process.runSync(Platform.isWindows ? 'python' : 'python3', [
  'tools/verify_ios_scene_manifest.py', ...args,
]);

void main() {
  test('iOS launch manifest connects the existing Flutter scene and storyboard', () {
    final result = verify([]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final app = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(app, contains('FlutterImplicitEngineDelegate'));
    expect(app, contains('didInitializeImplicitFlutterEngine'));
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();
    expect(scene, contains('class SceneDelegate: FlutterSceneDelegate'));
    expect(scene, contains('super.scene(scene, openURLContexts: URLContexts)'));
    final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(project, contains('SceneDelegate.swift in Sources'));
  });

  test('missing manifest is rejected instead of publishing a crashing app', () {
    final temp = Directory.systemTemp.createTempSync('sonarpad-scene-test-');
    try {
      final plist = File('${temp.path}/Info.plist');
      plist.writeAsStringSync('<?xml version="1.0"?><plist version="1.0"><dict>'
          '<key>UILaunchStoryboardName</key><string>LaunchScreen</string>'
          '</dict></plist>');
      final result = verify([plist.path]);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('UIApplicationSceneManifest'));
    } finally {
      temp.deleteSync(recursive: true);
    }
  });

  test('signed delivery verifies the final IPA before uploading', () {
    final workflow = File('.github/workflows/ios_testflight.yml').readAsStringSync();
    final check = workflow.indexOf('verify_ios_scene_manifest.py "\$IPA_PATH"');
    expect(check, greaterThan(0));
    expect(check, lessThan(workflow.indexOf('- name: Install fastlane')));
    expect(workflow, contains("IPHONEOS_DEPLOYMENT_TARGET'] = '15.5'"));
  });
}
