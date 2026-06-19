import 'package:l10n_countries/l10n_countries.dart';
import 'package:sealed_countries/sealed_countries.dart';

/// Converts Radio Browser country codes into readable, localized names.
///
/// Radio Browser exposes countries as short ISO 3166 alpha-2 codes such as
/// `TR`, `SG` or `AG`. Sonarpad still uses those codes internally for the API
/// request, but displays a localized country name for users and screen readers.
final Map<String, String> _countryDisplayNameCache = <String, String>{};

String localizedCountryDisplayName(
  String code, {
  required String localeName,
  String fallbackLabel = '',
}) {
  final normalizedCode = code.trim().toUpperCase();
  if (normalizedCode.isEmpty) return fallbackLabel.trim();

  final locale = _countryNameLocale(localeName);
  final cacheKey = '$locale|$normalizedCode|${fallbackLabel.trim()}';
  final cached = _countryDisplayNameCache[cacheKey];
  if (cached != null) return cached;

  final iso3Code = _toAlpha3Code(normalizedCode);
  if (iso3Code != null) {
    try {
      // CountriesLocaleMapper works with ISO alpha-3 codes and is single-use:
      // create it here, cache the resulting string, and never reuse the mapper.
      final localized = CountriesLocaleMapper().localize(
        {iso3Code},
        mainLocale: locale,
        fallbackLocale: 'en',
      );

      String? preferredName;
      String? fallbackName;
      localized.forEach((country, countryName) {
        final name = countryName.trim();
        if (!_isUsefulCountryName(name, normalizedCode)) return;

        fallbackName ??= name;
        final countryLocale = country.locale.toLowerCase();
        if (preferredName == null && countryLocale.startsWith(locale)) {
          preferredName = name;
        }
      });

      final resolvedName = preferredName ?? fallbackName;
      if (resolvedName != null) {
        _countryDisplayNameCache[cacheKey] = resolvedName;
        return resolvedName;
      }
    } catch (_) {
      // Fall through to app/Radio Browser fallback labels.
    }
  }

  final cleanedFallback = fallbackLabel.trim();
  if (_isUsefulCountryName(cleanedFallback, normalizedCode)) {
    final value = _titleCaseCountryLabel(cleanedFallback);
    _countryDisplayNameCache[cacheKey] = value;
    return value;
  }

  _countryDisplayNameCache[cacheKey] = normalizedCode;
  return normalizedCode;
}

String countryDisplayNameWithCode(
  String code, {
  required String localeName,
  String fallbackLabel = '',
}) {
  final normalizedCode = code.trim().toUpperCase();
  final name = localizedCountryDisplayName(
    normalizedCode,
    localeName: localeName,
    fallbackLabel: fallbackLabel,
  );
  if (normalizedCode.isEmpty || name.toUpperCase() == normalizedCode) {
    return name;
  }
  return '$name ($normalizedCode)';
}

String _countryNameLocale(String localeName) {
  final normalized = localeName.trim().toLowerCase().replaceAll('-', '_');
  if (normalized.startsWith('pt')) return 'pt';
  if (normalized.startsWith('en')) return 'en';
  if (normalized.startsWith('es')) return 'es';
  if (normalized.startsWith('fr')) return 'fr';
  if (normalized.startsWith('pl')) return 'pl';
  if (normalized.startsWith('cs')) return 'cs';
  return 'it';
}

String? _toAlpha3Code(String normalizedCode) {
  if (normalizedCode.length == 3) return normalizedCode;
  try {
    return WorldCountry.maybeFromCodeShort(normalizedCode)?.code.toUpperCase();
  } catch (_) {
    return null;
  }
}

bool _isUsefulCountryName(String value, String code) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  final compact = trimmed.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
  return compact != code.toUpperCase();
}

String _titleCaseCountryLabel(String value) {
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word.length == 1
          ? word.toUpperCase()
          : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
