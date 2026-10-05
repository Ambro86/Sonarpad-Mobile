import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Rai channels prefer native AVPlayer master HLS before MediaKit', () {
    final source =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(
      source,
      contains(
        'Platform.isIOS && _requiresRaiAudioDescriptionMediaKitPlayback',
      ),
    );
    expect(source, contains('await _playRaiNative('));
    expect(
      RegExp(
        r'_playRaiNative[\s\S]*?resolveStreamUrl\([\s\S]*?_raiNativePlayer\.open\([\s\S]*?url: masterUrl,',
      ).hasMatch(source),
      isTrue,
      reason: 'The native path must receive the resolved Rai master, not a child audio playlist.',
    );
    expect(source, contains('preferAudioDescription: _preferRaiAudioDescription'));
  });

  test('Rai native player uses AVFoundation and native audio media selection', () {
    final swift = File('ios/Runner/SonarpadRaiPlayer.swift').readAsStringSync();

    expect(swift, contains('AVURLAsset(url: url, options: options)'));
    expect(swift, contains('AVPlayerItem(asset: asset)'));
    expect(swift, contains('AVPlayer(playerItem: item)'));
    expect(swift, contains('appliesMediaSelectionCriteriaAutomatically = false'));
    expect(swift, contains('mediaSelectionGroup(forMediaCharacteristic: .audible)'));
    expect(swift, contains('option.hasMediaCharacteristic(.describesVideoForAccessibility)'));
    expect(swift, contains('normalizedLanguage == "des"'));
    expect(swift, contains('normalizedLanguage == "it"'));
    expect(swift, contains('item.select(selected, in: group)'));
    expect(swift, contains('if #available(iOS 16.0, *)'));
    expect(swift, contains('AVURLAssetHTTPUserAgentKey'));
    expect(swift, isNot(contains('options[AVURLAssetHTTPHeaderFieldsKey]')));
  });

  test('Rai native path retries fresh Mediapolis once then keeps old MediaKit fallback', () {
    final source =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(source, contains('_raiNativeRestartCount == 0'));
    expect(source, contains("await _play(reconnecting: true);"));
    expect(source, contains('_activateRaiNativeFallback'));
    expect(source, contains('_playRaiMediaKitFallback'));
    expect(
      source,
      contains('RAI AVPlayer fallback to existing MediaKit path'),
    );
    expect(
      source,
      contains("_recoverRaiNative(reason: 'startup_wait_exceeded')"),
    );
  });

  test('native Rai view is iOS-only and other TV playback stays on MediaKit', () {
    final service =
        File('lib/services/rai_native_player_service.dart').readAsStringSync();
    final player =
        File('lib/screens/radio_player_screen.dart').readAsStringSync();

    expect(service, contains("MethodChannel('sonarpad/rai_player')"));
    expect(service, contains("EventChannel('sonarpad/rai_player_events')"));
    expect(service, contains("viewType: 'sonarpad/rai_player_view'"));
    expect(service, contains('bool get isSupported => Platform.isIOS;'));

    final nativeBranch = player.indexOf('if (_useNativeRaiPlayback)');
    final genericTvBranch = player.indexOf('if (_requiresTvMediaKitPlayback)');
    expect(nativeBranch, greaterThanOrEqualTo(0));
    expect(genericTvBranch, greaterThan(nativeBranch));
    expect(
      player,
      contains("'RadioPlayer: TV MediaKit playback selected '"),
    );
  });

  test('Xcode project and AppDelegate register the native Rai player', () {
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(project, contains('SonarpadRaiPlayer.swift in Sources'));
    expect(
      appDelegate,
      contains('SonarpadRaiPlayerPlugin.register(with:'),
    );
  });
}
