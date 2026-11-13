import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
import '../services/app_settings_service.dart';
import 'country_name_helper.dart';

String localizedEdgeLanguageLabel(
  TtsVoiceLanguage language,
  AppLocalizations l10n,
) {
  final normalized = language.code.trim().replaceAll('_', '-');
  final parts = normalized.split('-').where((part) => part.isNotEmpty).toList();
  final localizedLanguage = l10n.languageLabel(language.code);

  // If Sonarpad does not have a localized name for this language, keep the
  // human-readable Edge label instead of exposing a technical locale code.
  if (localizedLanguage == language.code || parts.isEmpty) {
    return language.label;
  }

  // Script/dialect variants such as iu-Cans-CA or zh-CN-liaoning carry
  // useful information in Edge's friendly label. Preserve that text rather
  // than collapsing it to a country code.
  if (parts.length > 2) {
    final openParen = language.label.indexOf('(');
    if (openParen != -1) {
      return '$localizedLanguage ${language.label.substring(openParen)}';
    }
    return localizedLanguage;
  }

  final region = parts.length == 2 && parts[1].length == 2
      ? parts[1].toUpperCase()
      : null;
  if (region == null) return localizedLanguage;

  final fallbackCountry = _edgeCountryFromLanguageLabel(language.label);
  final country = localizedCountryDisplayName(
    region,
    localeName: l10n.localeName,
    fallbackLabel: fallbackCountry,
  );
  if (country.isEmpty || country.toUpperCase() == region) {
    return language.label;
  }
  return '$localizedLanguage ($country)';
}

String _edgeCountryFromLanguageLabel(String label) {
  final openParen = label.lastIndexOf('(');
  final closeParen = label.lastIndexOf(')');
  if (openParen == -1 || closeParen <= openParen) return '';
  final inside = label.substring(openParen + 1, closeParen).trim();
  if (inside.contains(',')) {
    return inside.split(',').last.trim();
  }
  return inside;
}

