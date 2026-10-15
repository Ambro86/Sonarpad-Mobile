import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'rai_native_player_service.dart';

/// Android implements the same command/event contract; iOS stays unchanged.
class RaiAndroidPlayerService extends RaiNativePlayerService {
  @override
  bool get isSupported => Platform.isAndroid;
}

class RaiAndroidVideoView extends StatelessWidget {
  const RaiAndroidVideoView({super.key});
  @override
  Widget build(BuildContext context) => const AndroidView(
    viewType: 'sonarpad/rai_android_player_view',
    creationParamsCodec: StandardMessageCodec(),
  );
}
