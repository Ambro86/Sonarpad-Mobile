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
      appBar: AppBar(
        title: Text(l10n.meteoTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.weatherCity,
                      hintText: l10n.weatherCityHint,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _fetchWeather(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _fetchWeather,
                  child: Text(l10n.search),
                ),
              ],
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
    return _weatherCodeLabel(l10n.localeName, code);
  }

  String _weatherCodeLabel(String localeName, int code) {
    final languageCode = localeName.split('_').first.split('-').first;
    final labels = switch (languageCode) {
      'en' => _weatherCodeLabelsEn,
      'fr' => _weatherCodeLabelsFr,
      'es' => _weatherCodeLabelsEs,
      'pt' || 'pt_BR' => _weatherCodeLabelsPt,
      'pl' => _weatherCodeLabelsPl,
      'de' => _weatherCodeLabelsDe,
      'uk' => _weatherCodeLabelsUk,
      'zh' => _weatherCodeLabelsZh,
      _ => _weatherCodeLabelsIt,
    };
    return labels[code] ?? code.toString();
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
                trailing: Text('${forecast.current['relative_humidity_2m']}%'),
              ),
            ),
        ],
      ),
    );
  }
}

const Map<int, String> _weatherCodeLabelsIt = {
  0: 'Sereno',
  1: 'Prevalentemente sereno',
  2: 'Parzialmente nuvoloso',
  3: 'Coperto',
  45: 'Nebbia',
  48: 'Nebbia con brina',
  51: 'Pioviggine leggera',
  53: 'Pioviggine moderata',
  55: 'Pioviggine intensa',
  56: 'Pioviggine gelata leggera',
  57: 'Pioviggine gelata intensa',
  61: 'Pioggia leggera',
  63: 'Pioggia moderata',
  65: 'Pioggia intensa',
  66: 'Pioggia gelata leggera',
  67: 'Pioggia gelata intensa',
  71: 'Neve leggera',
  73: 'Neve moderata',
  75: 'Neve intensa',
  77: 'Granelli di neve',
  80: 'Rovesci leggeri',
  81: 'Rovesci moderati',
  82: 'Rovesci violenti',
  85: 'Rovesci di neve leggeri',
  86: 'Rovesci di neve intensi',
  95: 'Temporale',
  96: 'Temporale con grandine leggera',
  99: 'Temporale con grandine intensa',
};

const Map<int, String> _weatherCodeLabelsEn = {
  0: 'Clear sky',
  1: 'Mainly clear',
  2: 'Partly cloudy',
  3: 'Overcast',
  45: 'Fog',
  48: 'Depositing rime fog',
  51: 'Light drizzle',
  53: 'Moderate drizzle',
  55: 'Dense drizzle',
  56: 'Light freezing drizzle',
  57: 'Dense freezing drizzle',
  61: 'Slight rain',
  63: 'Moderate rain',
  65: 'Heavy rain',
  66: 'Light freezing rain',
  67: 'Heavy freezing rain',
  71: 'Slight snow fall',
  73: 'Moderate snow fall',
  75: 'Heavy snow fall',
  77: 'Snow grains',
  80: 'Slight rain showers',
  81: 'Moderate rain showers',
  82: 'Violent rain showers',
  85: 'Slight snow showers',
  86: 'Heavy snow showers',
  95: 'Thunderstorm',
  96: 'Thunderstorm with slight hail',
  99: 'Thunderstorm with heavy hail',
};

const Map<int, String> _weatherCodeLabelsFr = {
  0: 'Ciel degage',
  1: 'Principalement clair',
  2: 'Partiellement nuageux',
  3: 'Couvert',
  45: 'Brouillard',
  48: 'Brouillard givrant',
  51: 'Bruine legere',
  53: 'Bruine moderee',
  55: 'Bruine dense',
  56: 'Bruine verglaçante legere',
  57: 'Bruine verglaçante dense',
  61: 'Pluie faible',
  63: 'Pluie moderee',
  65: 'Pluie forte',
  66: 'Pluie verglaçante legere',
  67: 'Pluie verglaçante forte',
  71: 'Faibles chutes de neige',
  73: 'Chutes de neige moderees',
  75: 'Fortes chutes de neige',
  77: 'Grains de neige',
  80: 'Averses faibles',
  81: 'Averses moderees',
  82: 'Averses violentes',
  85: 'Faibles averses de neige',
  86: 'Fortes averses de neige',
  95: 'Orage',
  96: 'Orage avec grele legere',
  99: 'Orage avec forte grele',
};

const Map<int, String> _weatherCodeLabelsEs = {
  0: 'Cielo despejado',
  1: 'Principalmente despejado',
  2: 'Parcialmente nublado',
  3: 'Cubierto',
  45: 'Niebla',
  48: 'Niebla con escarcha',
  51: 'Llovizna ligera',
  53: 'Llovizna moderada',
  55: 'Llovizna intensa',
  56: 'Llovizna helada ligera',
  57: 'Llovizna helada intensa',
  61: 'Lluvia ligera',
  63: 'Lluvia moderada',
  65: 'Lluvia intensa',
  66: 'Lluvia helada ligera',
  67: 'Lluvia helada intensa',
  71: 'Nevada ligera',
  73: 'Nevada moderada',
  75: 'Nevada intensa',
  77: 'Granulos de nieve',
  80: 'Chubascos ligeros',
  81: 'Chubascos moderados',
  82: 'Chubascos violentos',
  85: 'Chubascos de nieve ligeros',
  86: 'Chubascos de nieve intensos',
  95: 'Tormenta',
  96: 'Tormenta con granizo ligero',
  99: 'Tormenta con granizo intenso',
};

const Map<int, String> _weatherCodeLabelsPl = {
  0: 'Bezchmurnie',
  1: 'Przeważnie bezchmurnie',
  2: 'Częściowe zachmurzenie',
  3: 'Pochmurno',
  45: 'Mgła',
  48: 'Mgła osadzająca szadź',
  51: 'Lekka mżawka',
  53: 'Umiarkowana mżawka',
  55: 'Gęsta mżawka',
  56: 'Lekka marznąca mżawka',
  57: 'Gęsta marznąca mżawka',
  61: 'Lekki deszcz',
  63: 'Umiarkowany deszcz',
  65: 'Silny deszcz',
  66: 'Lekki marznący deszcz',
  67: 'Silny marznący deszcz',
  71: 'Lekki śnieg',
  73: 'Umiarkowany śnieg',
  75: 'Silny śnieg',
  77: 'Ziarnisty śnieg',
  80: 'Lekkie przelotne opady deszczu',
  81: 'Umiarkowane przelotne opady deszczu',
  82: 'Gwałtowne przelotne opady deszczu',
  85: 'Lekkie przelotne opady śniegu',
  86: 'Silne przelotne opady śniegu',
  95: 'Burza',
  96: 'Burza z lekkim gradem',
  99: 'Burza z silnym gradem',
};

const Map<int, String> _weatherCodeLabelsDe = {
  0: 'Klarer Himmel',
  1: 'Überwiegend klar',
  2: 'Teilweise bewölkt',
  3: 'Bedeckt',
  45: 'Nebel',
  48: 'Reifnebel',
  51: 'Leichter Nieselregen',
  53: 'Mäßiger Nieselregen',
  55: 'Starker Nieselregen',
  56: 'Leichter gefrierender Nieselregen',
  57: 'Starker gefrierender Nieselregen',
  61: 'Leichter Regen',
  63: 'Mäßiger Regen',
  65: 'Starker Regen',
  66: 'Leichter gefrierender Regen',
  67: 'Starker gefrierender Regen',
  71: 'Leichter Schneefall',
  73: 'Mäßiger Schneefall',
  75: 'Starker Schneefall',
  77: 'Schneegriesel',
  80: 'Leichte Regenschauer',
  81: 'Mäßige Regenschauer',
  82: 'Heftige Regenschauer',
  85: 'Leichte Schneeschauer',
  86: 'Starke Schneeschauer',
  95: 'Gewitter',
  96: 'Gewitter mit leichtem Hagel',
  99: 'Gewitter mit starkem Hagel',
};


const Map<int, String> _weatherCodeLabelsPt = {
  0: 'Céu limpo',
  1: 'Predominantemente limpo',
  2: 'Parcialmente nublado',
  3: 'Encoberto',
  45: 'Nevoeiro',
  48: 'Nevoeiro com geada',
  51: 'Chuvisco fraco',
  53: 'Chuvisco moderado',
  55: 'Chuvisco intenso',
  56: 'Chuvisco gelado fraco',
  57: 'Chuvisco gelado intenso',
  61: 'Chuva fraca',
  63: 'Chuva moderada',
  65: 'Chuva intensa',
  66: 'Chuva gelada fraca',
  67: 'Chuva gelada intensa',
  71: 'Neve fraca',
  73: 'Neve moderada',
  75: 'Neve intensa',
  77: 'Grãos de neve',
  80: 'Aguaceiros fracos',
  81: 'Aguaceiros moderados',
  82: 'Aguaceiros violentos',
  85: 'Aguaceiros de neve fracos',
  86: 'Aguaceiros de neve intensos',
  95: 'Trovoada',
  96: 'Trovoada com granizo fraco',
  99: 'Trovoada com granizo intenso',
};



const Map<int, String> _weatherCodeLabelsUk = {
  0: 'Ясно',
  1: 'Переважно ясно',
  2: 'Мінлива хмарність',
  3: 'Хмарно',
  45: 'Туман',
  48: 'Туман з памороззю',
  51: 'Слабка мряка',
  53: 'Помірна мряка',
  55: 'Сильна мряка',
  56: 'Слабка крижана мряка',
  57: 'Сильна крижана мряка',
  61: 'Слабкий дощ',
  63: 'Помірний дощ',
  65: 'Сильний дощ',
  66: 'Слабкий крижаний дощ',
  67: 'Сильний крижаний дощ',
  71: 'Слабкий сніг',
  73: 'Помірний сніг',
  75: 'Сильний сніг',
  77: 'Снігові зерна',
  80: 'Слабкі зливи',
  81: 'Помірні зливи',
  82: 'Сильні зливи',
  85: 'Слабкі снігові заряди',
  86: 'Сильні снігові заряди',
  95: 'Гроза',
  96: 'Гроза зі слабким градом',
  99: 'Гроза із сильним градом',
};


const Map<int, String> _weatherCodeLabelsZh = {
  0: '晴朗',
  1: '大部晴朗',
  2: '局部多云',
  3: '阴天',
  45: '雾',
  48: '冻雾',
  51: '小毛毛雨',
  53: '中等毛毛雨',
  55: '强毛毛雨',
  56: '轻微冻毛毛雨',
  57: '强冻毛毛雨',
  61: '小雨',
  63: '中雨',
  65: '大雨',
  66: '轻微冻雨',
  67: '强冻雨',
  71: '小雪',
  73: '中雪',
  75: '大雪',
  77: '米雪',
  80: '小阵雨',
  81: '中等阵雨',
  82: '强阵雨',
  85: '小阵雪',
  86: '强阵雪',
  95: '雷暴',
  96: '伴有小冰雹的雷暴',
  99: '伴有强冰雹的雷暴',
};

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
      appBar: AppBar(
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
