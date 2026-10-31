import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/app_logger.dart';
import 'app_settings_service.dart';
import 'audiodescription_service.dart';

class ActivationLinkService {
  ActivationLinkService({
    Future<void> Function(String)? validate,
    Future<void> Function(String)? save,
  }) : _validate = validate ?? _validateCode,
       _save = save ?? AppSettingsService().setTvSecretCode;

  // Notify existing screens without rebuilding the navigator or losing user work.
  static final changes = ValueNotifier<int>(0);
  final Future<void> Function(String) _validate;
  final Future<void> Function(String) _save;

  static Future<String> diagnosticSummary() async {
    final info = await PackageInfo.fromPlatform();
    final code = await AppSettingsService().getTvSecretCode();
    return 'package=${info.packageName} version=${info.version} '
        'build=${info.buildNumber} codePresent=${code.trim().isNotEmpty}';
  }

  static Future<void> logContext(String source) async {
    try {
      await AppLogger.log(
        'Activation context: source=$source ${await diagnosticSummary()}',
      );
    } catch (_) {
      unawaited(
        AppLogger.log('Activation context: source=$source unavailable'),
      );
    }
  }

  static bool recognizes(Uri uri) =>
      uri.scheme == 'sonarpad' && uri.host == 'activate';

  static Uri linkForCode(String code) => Uri(
    scheme: 'sonarpad',
    host: 'activate',
    queryParameters: {'code': code},
  );

  static String codeFromLink(Uri uri) {
    if (!recognizes(uri) ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasFragment) {
      throw const FormatException('Invalid activation link');
    }
    final values = uri.queryParametersAll['code'];
    if (values == null || values.length != 1) {
      throw const FormatException('Invalid activation code');
    }
    final code = values.single.trim();
    if (code.isEmpty ||
        code.length > 4096 ||
        code.runes.any((c) => c < 32 || c == 127)) {
      throw const FormatException('Invalid activation code');
    }
    return code;
  }

  static Future<void> _validateCode(String code) async {
    await AudiodescriptionService()
        .fetchRecentCatalog(code)
        .timeout(const Duration(seconds: 30));
  }

  Future<void> activate(Uri uri) async {
    final code = codeFromLink(uri);
    unawaited(logContext('activation_started'));
    unawaited(AppLogger.log('Activation link: validation started'));
    await _validate(code);
    unawaited(AppLogger.log('Activation link: validation succeeded; saving'));
    await _save(code);
    unawaited(AppLogger.log('Activation link: persistence completed'));
    unawaited(logContext('activation_saved'));
    changes.value++;
  }
}
