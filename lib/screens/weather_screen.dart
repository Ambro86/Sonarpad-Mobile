import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import '../services/news/weather_service.dart';
import '../utils/text_input_normalizer.dart';
import '../widgets/universal_accessible_view.dart';

WeatherGeocodingResult? _deserializeCity(String data) {
  try {
    final map = jsonDecode(data);
    if (map is Map<String, dynamic> && map.containsKey('latitude')) {
      return WeatherGeocodingResult.fromJson(map);
    }
  } catch (_) {}
  return null;
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final _settings = AppSettingsService();
  final _weatherService = OpenMeteoWeatherService();
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final GlobalKey _searchFocusTargetKey = GlobalKey(
    debugLabel: 'weather_search_focus_target',
  );
  WeatherForecast? _forecast;
  List<WeatherGeocodingResult> _cityResults = const [];
  bool _isLoading = false;
  _WeatherError? _error;
  int _selectedDay = 0;
  WeatherTemperatureUnit _temperatureUnit = WeatherTemperatureUnit.celsius;

  bool _hasRecentCities = false;

  @override
  void initState() {
    super.initState();
    _loadTemperatureUnit();
    _checkRecentCities();
    _loadSavedCity();
  }

  Future<void> _loadTemperatureUnit() async {
    final unit = await _settings.loadWeatherTemperatureUnit();
    if (mounted) setState(() => _temperatureUnit = unit);
  }

  Future<void> _clearSearchText() async {
    final previousValue = _searchCtrl.text;
    if (previousValue.isEmpty) return;
    _searchCtrl.clear();
    announceClearedEditableText(context, previousValue);
    _searchFocusNode.requestFocus();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _searchFocusTargetKey.currentContext
        ?.findRenderObject()
        ?.sendSemanticsEvent(const FocusSemanticEvent());
  }

  Future<void> _checkRecentCities() async {
    final cities = await _settings.getWeatherRecentCities();
    if (mounted) setState(() => _hasRecentCities = cities.isNotEmpty);
  }

  Future<void> _openRecentCities() async {
    final cityData = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const _WeatherRecentCitiesScreen(),
      ),
    );
    _checkRecentCities();
    if (cityData != null && cityData.isNotEmpty) {
      final cityObj = _deserializeCity(cityData);
      if (cityObj != null) {
        _searchCtrl.text = cityObj.name;
        _fetchForecastFor(cityObj, cityData, skipSave: true);
      } else {
        _searchCtrl.text = cityData;
        _fetchWeather(autoSelectFirst: true);
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCity() async {
    final savedData = await _settings.getWeatherCity();
    if (!mounted) return;
    if (savedData.isEmpty) return;
    
    final cityObj = _deserializeCity(savedData);
    if (cityObj != null) {
      _searchCtrl.text = cityObj.name;
      await _fetchForecastFor(cityObj, savedData, skipSave: true);
      return;
    }

    final shouldIgnoreOldDefault = savedData.trim().toLowerCase() == 'roma';
    if (shouldIgnoreOldDefault) return;
    _searchCtrl.text = savedData;
    await _fetchWeather(autoSelectFirst: true);
  }

  Future<void> _fetchWeather({bool autoSelectFirst = false}) async {
    final city = normalizeSearchInput(_searchCtrl.text);
    if (city.isEmpty) return;
    if (_searchCtrl.text != city) {
      _searchCtrl.text = city;
      _searchCtrl.selection = TextSelection.collapsed(offset: city.length);
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _forecast = null;
      _cityResults = const [];
      _selectedDay = 0;
    });

    try {
      final cities = await _weatherService.searchCity(
        city,
        localeName: AppLocalizations.of(context).localeName,
      );
      if (cities.isNotEmpty) {
        if (cities.length > 1 && !autoSelectFirst) {
          if (mounted) {
            setState(() {
              _cityResults = cities;
              _isLoading = false;
            });
          }
          return;
        }
        await _fetchForecastFor(cities.first, city);
      } else {
        if (mounted) {
          setState(() {
            _error = _WeatherError.cityNotFound;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _WeatherError.searchError;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectCity(WeatherGeocodingResult city) async {
    final cityName = city.name;
    _searchCtrl.text = cityName;
    setState(() {
      _isLoading = true;
      _error = null;
      _forecast = null;
      _cityResults = const [];
      _selectedDay = 0;
    });
    await _fetchForecastFor(city, cityName);
  }

  Future<void> _fetchForecastFor(
    WeatherGeocodingResult city,
    String savedCity, {
    bool skipSave = false,
  }) async {
    final forecast = await _weatherService.getForecast(
      city.latitude,
      city.longitude,
    );
    if (forecast == null) {
      if (mounted) {
        setState(() {
          _error = _WeatherError.searchError;
          _isLoading = false;
        });
      }
      return;
    }
    
    if (!skipSave) {
      final dataToSave = jsonEncode(city.toJson());
      await _settings.setWeatherCity(dataToSave);
      await _settings.addWeatherRecentCity(dataToSave);
      _checkRecentCities();
    }
    
    if (mounted) {
      setState(() {
        _forecast = forecast;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: SonarpadAppBar(
        title: Text(l10n.meteoTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      sortKey: const OrdinalSortKey(1),
                      child: KeyedSubtree(
                        key: _searchFocusTargetKey,
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            labelText: l10n.weatherCity,
                            hintText: l10n.weatherCityHint,
                            border: const OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _fetchWeather(),
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchCtrl,
                    builder: (context, value, _) {
                      if (value.text.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Semantics(
                          sortKey: const OrdinalSortKey(2),
                          child: IconButton(
                            tooltip: l10n.clearSearch,
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearchText,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    sortKey: const OrdinalSortKey(3),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _fetchWeather,
                      child: Text(l10n.search),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_hasRecentCities && !_isLoading && _cityResults.isEmpty)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(l10n.weatherRecentCities),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openRecentCities,
            ),
          if (_isLoading)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.loading,
                ),
              ),
            ),
          if (_error != null)
            Expanded(child: Center(child: Text(_error!.label(l10n)))),
          if (_cityResults.isNotEmpty && !_isLoading)
            _WeatherCityResultsView(
              cities: _cityResults,
              onCitySelected: _selectCity,
            ),
          if (_forecast != null && !_isLoading)
            _WeatherForecastView(
              forecast: _forecast!,
              selectedDay: _selectedDay,
              temperatureUnit: _temperatureUnit,
              onDayChanged: (value) {
                setState(() {
                  _selectedDay = value;
                });
              },
            ),
        ],
      ),
    );
  }
}

class _WeatherCityResultsView extends StatelessWidget {
  const _WeatherCityResultsView({
    required this.cities,
    required this.onCitySelected,
  });

  final List<WeatherGeocodingResult> cities;
  final ValueChanged<WeatherGeocodingResult> onCitySelected;

  String _subtitle(WeatherGeocodingResult city) => city.locationSubtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (useSharedAccessibleViewModel) {
      return Expanded(
        child: UniversalAccessibleList(
          sections: [
            AccessibleListSection(
              header: l10n.weatherCity,
              rows: [
                for (var i = 0; i < cities.length; i++)
                  AccessibleListRow(
                    id: 'city_$i',
                    title: cities[i].name,
                    subtitle: _subtitle(cities[i]),
                  ),
              ],
            ),
          ],
          onEvent: (event) {
            if (event.type != 'activate' || event.id == null) return;
            final i = int.tryParse(event.id!.replaceFirst('city_', ''));
            if (i != null && i < cities.length) onCitySelected(cities[i]);
          },
        ),
      );
    }

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            l10n.weatherCity,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final city in cities)
            Card(
              child: ListTile(
                title: Text(city.name),
                subtitle: Text(_subtitle(city)),
                onTap: () => onCitySelected(city),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeatherForecastView extends StatelessWidget {
  const _WeatherForecastView({
    required this.forecast,
    required this.selectedDay,
    required this.temperatureUnit,
    required this.onDayChanged,
  });

  final WeatherForecast forecast;
  final int selectedDay;
  final WeatherTemperatureUnit temperatureUnit;
  final ValueChanged<int> onDayChanged;

  List<dynamic> _dailyValues(String key) {
    final values = forecast.daily[key];
    return values is List ? values : const [];
  }

  String _value(String key, int day, String unit) {
    final values = _dailyValues(key);
    if (day < 0 || day >= values.length) return '-';
    final value = values[day];
    if (value == null) return '-';
    return '$value $unit';
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _temperatureSymbol() {
    return switch (temperatureUnit) {
      WeatherTemperatureUnit.celsius => '°C',
      WeatherTemperatureUnit.fahrenheit => '°F',
    };
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String _formatTemperature(dynamic value) {
    final celsius = _asDouble(value);
    if (celsius == null) return '-';
    final converted = switch (temperatureUnit) {
      WeatherTemperatureUnit.celsius => celsius,
      WeatherTemperatureUnit.fahrenheit => (celsius * 9 / 5) + 32,
    };
    return '${_formatNumber(converted)} ${_temperatureSymbol()}';
  }

  String _temperatureValue(String key, int day) {
    final values = _dailyValues(key);
    if (day < 0 || day >= values.length) return '-';
    return _formatTemperature(values[day]);
  }

  String _currentPercentage(String key) {
    final value = _asDouble(forecast.current[key]);
    if (value == null) return '-';
    return '${_formatNumber(value)}%';
  }

  String _currentAirQuality(AppLocalizations l10n) {
    final value = _asDouble(forecast.airQualityCurrent['european_aqi']);
    if (value == null) return '-';

    final label = switch (value) {
      <= 20 => l10n.weatherAirQualityGood,
      <= 40 => l10n.weatherAirQualityFair,
      <= 60 => l10n.weatherAirQualityModerate,
      <= 80 => l10n.weatherAirQualityPoor,
      <= 100 => l10n.weatherAirQualityVeryPoor,
      _ => l10n.weatherAirQualityExtremelyPoor,
    };
    return '$label (${_formatNumber(value)})';
  }

  String _dayLabel(AppLocalizations l10n, int day) {
    if (day == 0) return l10n.weatherToday;
    if (day == 1) return l10n.weatherTomorrow;
    final times = _dailyValues('time');
    if (day >= 0 && day < times.length) {
      final date = DateTime.tryParse(times[day].toString());
      if (date != null) {
        return DateFormat.yMMMMd(l10n.localeName).format(date);
      }
      return times[day].toString();
    }
    return '${l10n.weatherChooseDay} ${day + 1}';
  }

  int? _currentWeatherCode() {
    final value = forecast.current['weather_code'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _currentSituation(AppLocalizations l10n) {
    final code = _currentWeatherCode();
    if (code == null) return '-';
    return weatherConditionLabel(l10n, code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dayCount = _dailyValues('time').length;
    final availableDays = dayCount > 0 ? dayCount : 1;
    final day = selectedDay.clamp(0, availableDays - 1);

    if (useSharedAccessibleViewModel) {
      final dayOptions = [
        for (var i = 0; i < availableDays; i++)
          AccessibleOption(value: i, label: _dayLabel(l10n, i)),
      ];
      return Expanded(
        child: UniversalAccessibleList(
          sections: [
            AccessibleListSection(rows: [
              AccessibleListRow(
                id: 'day',
                title: l10n.weatherChooseDay,
                kind: 'picker',
                value: day.toString(),
                valueLabel: _dayLabel(l10n, day),
                options: dayOptions,
              ),
              AccessibleListRow(id: 'day_title', kind: 'header', title: _dayLabel(l10n, day)),
              if (day == 0)
                AccessibleListRow(id: 'situation', kind: 'text', title: l10n.weatherCurrentSituation, valueLabel: _currentSituation(l10n)),
              if (day == 0)
                AccessibleListRow(id: 'current_temp', kind: 'text', title: l10n.weatherCurrentTemperature, valueLabel: _formatTemperature(forecast.current['temperature_2m'])),
              AccessibleListRow(id: 'max_temp', kind: 'text', title: l10n.weatherMaxTemperature, valueLabel: _temperatureValue('temperature_2m_max', day)),
              AccessibleListRow(id: 'min_temp', kind: 'text', title: l10n.weatherMinTemperature, valueLabel: _temperatureValue('temperature_2m_min', day)),
              AccessibleListRow(id: 'rain', kind: 'text', title: l10n.weatherPrecipitation, valueLabel: _value('precipitation_sum', day, 'mm')),
              AccessibleListRow(id: 'wind', kind: 'text', title: l10n.weatherWind, valueLabel: _value('wind_speed_10m_max', day, 'km/h')),
              if (day == 0)
                AccessibleListRow(
                  id: 'humidity',
                  kind: 'text',
                  title: l10n.weatherRelativeHumidity,
                  valueLabel: _currentPercentage('relative_humidity_2m'),
                ),
              if (day == 0)
                AccessibleListRow(
                  id: 'air_quality',
                  kind: 'text',
                  title: l10n.weatherAirQuality,
                  valueLabel: _currentAirQuality(l10n),
                ),
            ]),
          ],
          onEvent: (event) {
            if (event.id == 'day' && event.type == 'picker') {
              final value = event.value;
              final i = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
              if (i != null) onDayChanged(i);
            }
          },
        ),
      );
    }

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          DropdownButtonFormField<int>(
            initialValue: day,
            decoration: InputDecoration(
              labelText: l10n.weatherChooseDay,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (var i = 0; i < availableDays; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(_dayLabel(l10n, i)),
                ),
            ],
            onChanged: (value) {
              if (value != null) onDayChanged(value);
            },
          ),
          const SizedBox(height: 16),
          Text(
            _dayLabel(l10n, day),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          if (day == 0)
            Card(
              child: ListTile(
                title: Text(l10n.weatherCurrentSituation),
                trailing: Text(_currentSituation(l10n)),
              ),
            ),
          if (day == 0)
            Card(
              child: ListTile(
                title: Text(l10n.weatherCurrentTemperature),
                trailing: Text(
                  _formatTemperature(forecast.current['temperature_2m']),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          Card(
            child: ListTile(
              title: Text(l10n.weatherMaxTemperature),
              trailing: Text(
                _temperatureValue('temperature_2m_max', day),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(l10n.weatherMinTemperature),
              trailing: Text(_temperatureValue('temperature_2m_min', day)),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(l10n.weatherPrecipitationProbability),
              trailing: Text(_value('precipitation_probability_max', day, '%')),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(l10n.weatherPrecipitation),
              trailing: Text(_value('precipitation_sum', day, 'mm')),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(l10n.weatherWind),
              trailing: Text(_value('wind_speed_10m_max', day, 'km/h')),
            ),
          ),
          if (day == 0)
            Card(
              child: ListTile(
                title: Text(l10n.weatherRelativeHumidity),
                trailing: Text(_currentPercentage('relative_humidity_2m')),
              ),
            ),
          if (day == 0)
            Card(
              child: ListTile(
                title: Text(l10n.weatherAirQuality),
                trailing: Text(_currentAirQuality(l10n)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Resolves the existing WMO conditions without changing unknown-code fallback.
String weatherConditionLabel(AppLocalizations l10n, int code) {
  return switch (code) {
    0 => l10n.weatherConditionClearSky,
    1 => l10n.weatherConditionMainlyClear,
    2 => l10n.weatherConditionPartlyCloudy,
    3 => l10n.weatherConditionOvercast,
    45 => l10n.weatherConditionFog,
    48 => l10n.weatherConditionRimeFog,
    51 => l10n.weatherConditionLightDrizzle,
    53 => l10n.weatherConditionModerateDrizzle,
    55 => l10n.weatherConditionDenseDrizzle,
    56 => l10n.weatherConditionLightFreezingDrizzle,
    57 => l10n.weatherConditionDenseFreezingDrizzle,
    61 => l10n.weatherConditionLightRain,
    63 => l10n.weatherConditionModerateRain,
    65 => l10n.weatherConditionHeavyRain,
    66 => l10n.weatherConditionLightFreezingRain,
    67 => l10n.weatherConditionHeavyFreezingRain,
    71 => l10n.weatherConditionLightSnowfall,
    73 => l10n.weatherConditionModerateSnowfall,
    75 => l10n.weatherConditionHeavySnowfall,
    77 => l10n.weatherConditionSnowGrains,
    80 => l10n.weatherConditionLightRainShowers,
    81 => l10n.weatherConditionModerateRainShowers,
    82 => l10n.weatherConditionViolentRainShowers,
    85 => l10n.weatherConditionLightSnowShowers,
    86 => l10n.weatherConditionHeavySnowShowers,
    95 => l10n.weatherConditionThunderstorm,
    96 => l10n.weatherConditionThunderstormLightHail,
    99 => l10n.weatherConditionThunderstormHeavyHail,
    _ => code.toString(),
  };
}

enum _WeatherError {
  cityNotFound,
  searchError;

  String label(AppLocalizations l10n) {
    return switch (this) {
      _WeatherError.cityNotFound => l10n.weatherCityNotFound,
      _WeatherError.searchError => l10n.weatherSearchError,
    };
  }
}

class _WeatherRecentCitiesScreen extends StatefulWidget {
  const _WeatherRecentCitiesScreen();

  @override
  State<_WeatherRecentCitiesScreen> createState() =>
      _WeatherRecentCitiesScreenState();
}

class _WeatherRecentCitiesScreenState
    extends State<_WeatherRecentCitiesScreen> {
  final _settings = AppSettingsService();
  List<String> _cities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cities = await _settings.getWeatherRecentCities();
    if (!mounted) return;
    setState(() {
      _cities = cities;
      _loading = false;
    });
  }

  Future<void> _deleteCity(String cityData) async {
    await _settings.removeWeatherRecentCity(cityData);
    await _load();
  }

  Future<void> _clearHistory() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearHistory),
        content: Text(l10n.confirmClearHistory),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.clearHistory),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _settings.clearWeatherRecentCities();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: SonarpadAppBar(
        title: Text(l10n.weatherRecentCities),
        actions: [
          if (_cities.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: l10n.clearHistory,
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cities.isEmpty
              ? Center(child: Text(l10n.weatherCityNotFound)) // Or another localized string
              : useSharedAccessibleViewModel
                  ? UniversalAccessibleList(
                      sections: [AccessibleListSection(rows: [
                        for (var i = 0; i < _cities.length; i++)
                          AccessibleListRow(
                            id: 'city_$i',
                            title: _deserializeCity(_cities[i])?.name ?? _cities[i],
                            subtitle: (() {
                              final cityObj = _deserializeCity(_cities[i]);
                              if (cityObj == null) return null;
                              final subtitle = cityObj.locationSubtitle;
                              return subtitle.isEmpty ? null : subtitle;
                            })(),
                            actions: [AccessibleCustomAction(id: 'delete', label: l10n.deleteItem)],
                          ),
                      ])],
                      onEvent: (event) async {
                        if (event.id?.startsWith('city_') != true) return;
                        final i = int.tryParse(event.id!.substring(5));
                        if (i == null || i >= _cities.length) return;
                        if (event.type == 'customAction' && event.action == 'delete') {
                          await _deleteCity(_cities[i]);
                        } else if (event.type == 'activate') {
                          Navigator.pop(context, _cities[i]);
                        }
                      },
                    )
                  : ListView.separated(
                  itemCount: _cities.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final cityData = _cities[index];
                    final cityObj = _deserializeCity(cityData);
                    final displayName = cityObj != null ? cityObj.name : cityData;
                    String? subtitle;
                    if (cityObj != null) {
                      final details = cityObj.locationSubtitle;
                      if (details.isNotEmpty) subtitle = details;
                    }
                    
                    return Semantics(
                      key: ValueKey('weather_recent_city_semantics_$cityData'),
                      container: true,
                      customSemanticsActions: {
                        CustomSemanticsAction(label: l10n.deleteItem): () =>
                            _deleteCity(cityData),
                      },
                      child: ListTile(
                        title: Text(displayName),
                        subtitle: subtitle != null ? Text(subtitle) : null,
                        trailing: ExcludeSemantics(
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: l10n.deleteItem,
                            onPressed: () => _deleteCity(cityData),
                          ),
                        ),
                        onTap: () => Navigator.pop(context, cityData),
                      ),
                    );
                  },
                ),
    );
  }
}
