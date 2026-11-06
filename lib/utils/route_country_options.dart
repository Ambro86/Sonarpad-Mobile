import '../l10n/app_localizations.dart';
import '../widgets/universal_accessible_view.dart';
import 'country_name_helper.dart';

String defaultRouteCountry(String code) => switch (code) {
  'es' => 'es',
  'fr' => 'fr',
  'pt' => 'pt',
  'pt_BR' => 'br',
  'pl' => 'pl',
  'cs' => 'cz',
  'de' => 'de',
  'nl' => 'nl',
  'zh_CN' => 'cn',
  'uk' => 'ua',
  'ro' => 'ro',
  'tr' || 'tr_TR' || 'tr-TR' => 'tr',
  _ => 'it',
};

List<AccessibleOption> routeCountryOptions(AppLocalizations l10n) => [
  AccessibleOption(value: 'it', label: l10n.routeCountryItaly),
  AccessibleOption(value: 'fr', label: l10n.routeCountryFrance),
  AccessibleOption(value: 'es', label: l10n.routeCountrySpain),
  AccessibleOption(value: 'pt', label: l10n.radioCountryOptionPt),
  AccessibleOption(value: 'br', label: l10n.radioCountryOptionBr),
  AccessibleOption(value: 'pl', label: l10n.radioCountryOptionPl),
  AccessibleOption(value: 'cz', label: l10n.routeCountryCzechRepublic),
  AccessibleOption(value: 'au', label: l10n.radioCountryOptionAu),
  AccessibleOption(value: 'ca', label: l10n.radioCountryOptionCa),
  AccessibleOption(value: 'de', label: l10n.radioCountryOptionDe),
  AccessibleOption(value: 'nl', label: l10n.radioCountryOptionNl),
  AccessibleOption(value: 'gb', label: l10n.radioCountryOptionGb),
  AccessibleOption(value: 'us', label: l10n.radioCountryOptionUs),
  AccessibleOption(
    value: 'ua',
    label: localizedCountryDisplayName('UA', localeName: l10n.localeName),
  ),
  AccessibleOption(
    value: 'ro',
    label: localizedCountryDisplayName(
      'RO',
      localeName: l10n.localeName,
      fallbackLabel: 'România',
    ),
  ),
  AccessibleOption(value: 'tr', label: l10n.radioCountryOptionTr),
  AccessibleOption(value: 'cn', label: l10n.chinaCountryName),
];

// A visible, editable default: multi-zone countries can select the origin zone.
String defaultRouteTimeZone(String country) => switch (country.toLowerCase()) {
  'fr' => 'Europe/Paris',
  'es' => 'Europe/Madrid',
  'pt' => 'Europe/Lisbon',
  'br' => 'America/Sao_Paulo',
  'pl' => 'Europe/Warsaw',
  'cz' => 'Europe/Prague',
  'de' => 'Europe/Berlin',
  'nl' => 'Europe/Amsterdam',
  'gb' => 'Europe/London',
  'us' => 'America/New_York',
  'ca' => 'America/Toronto',
  'au' => 'Australia/Sydney',
  'ua' => 'Europe/Kyiv',
  'ro' => 'Europe/Bucharest',
  'tr' => 'Europe/Istanbul',
  'cn' => 'Asia/Shanghai',
  _ => 'Europe/Rome',
};
