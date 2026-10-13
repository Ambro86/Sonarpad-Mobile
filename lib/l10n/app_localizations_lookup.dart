import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Resolves ARB-backed strings for services that do not have a BuildContext.
/// Both underscore and BCP-47 locale names are accepted. Regional variants
/// retain their own translations when the app provides them.
AppLocalizations lookupSupportedAppLocalizations(
  String localeName, {
  String fallbackLanguage = 'en',
}) {
  Locale? supportedLocale(String value) {
    final parts = value.trim().replaceAll('_', '-').split('-');
    final language = parts.first.toLowerCase();
    if (!AppLocalizations.supportedLocales
        .any((locale) => locale.languageCode == language)) {
      return null;
    }
    String? country;
    for (final part in parts.skip(1)) {
      if (RegExp(r'^[a-zA-Z]{2}$|^[0-9]{3}$').hasMatch(part)) {
        country = part.toUpperCase();
        break;
      }
    }
    return Locale(language, country);
  }

  final locale = supportedLocale(localeName) ??
      supportedLocale(fallbackLanguage) ??
      const Locale('en');
  return lookupAppLocalizations(locale);
}
