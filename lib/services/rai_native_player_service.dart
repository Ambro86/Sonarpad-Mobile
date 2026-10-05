import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// iOS-only bridge used for Rai live streams.
///
/// RaiPlay itself uses AVPlayer/AVFoundation for HLS playback. Keeping the
/// complete master playlist inside AVFoundation lets the native stack manage
/// redirects, rendition selection and segment requests consistently instead
/// of mixing Dart HTTP with FFmpeg/mpv networking.
class RaiNativePlayerService {
  static const MethodChannel _commands = MethodChannel('sonarpad/rai_player');
  static const EventChannel _events = EventChannel('sonarpad/rai_player_events');

  Stream<dynamic>? _eventStream;

  bool get isSupported => Platform.isIOS;

  Stream<dynamic> get events =>
      _eventStream ??= _events.receiveBroadcastStream().asBroadcastStream();

  Future<void> open({
    required String url,
    required Map<String, String> headers,
    required bool preferAudioDescription,
    required bool videoEnabled,
    required double volume,
  }) async {
    if (!isSupported) return;
    await _commands.invokeMethod<void>('open', {
      'url': url,
      'headers': headers,
      'preferAudioDescription': preferAudioDescription,
      'videoEnabled': videoEnabled,
      'volume': volume.clamp(0.0, 1.0),
    });
  }

  Future<void> play() async {
    if (!isSupported) return;
    await _commands.invokeMethod<void>('play');
  }

  Future<void> pause() async {
    if (!isSupported) return;
    await _commands.invokeMethod<void>('pause');
  }

  Future<void> stop() async {
    if (!isSupported) return;
    await _commands.invokeMethod<void>('stop');
  }

  Future<void> dispose() async {
    if (!isSupported) return;
    await _commands.invokeMethod<void>('dispose');
  }

  Future<void> setVolume(double volume) async {
    if (!isSupported) return;
    await _commands.invokeMethod<void>(
      'setVolume',
      volume.clamp(0.0, 1.0),
    );
  }

  Future<void> setVideoEnabled(bool enabled) async {
    if (!isSupported) return;
    await _commands.invokeMethod<void>('setVideoEnabled', enabled);
  }

  Future<void> setPreferAudioDescription(bool enabled) async {
    if (!isSupported) return;
    await _commands.invokeMethod<void>('setPreferAudioDescription', enabled);
  }
}

/// Native AVPlayer surface shared by the Rai player bridge.
///
/// The platform view contains only the video layer. Controls and accessibility
/// remain in Flutter so the existing Sonarpad player UI and VoiceOver order do
/// not change.
class RaiNativeVideoView extends StatelessWidget {
  const RaiNativeVideoView({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) return const SizedBox.shrink();
    return const UiKitView(
      viewType: 'sonarpad/rai_player_view',
      creationParamsCodec: StandardMessageCodec(),
    );
  }
}
