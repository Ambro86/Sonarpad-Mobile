import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import '../services/news/weather_service.dart';

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
  bool _isLoading = false;
  _WeatherError? _error;
  int _selectedDay = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedCity();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCity() async {
    final city = await _settings.getWeatherCity();
    if (!mounted) return;
    final shouldIgnoreOldDefault = city.trim().toLowerCase() == 'roma';
    if (shouldIgnoreOldDefault || city.isEmpty) return;
    _searchCtrl.text = city;
    await _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    final city = _searchCtrl.text.trim();
    if (city.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _forecast = null;
      _selectedDay = 0;
    });

    try {
      final cities = await _weatherService.searchCity(city);
      if (cities.isNotEmpty) {
        final loc = cities.first;
        final forecast = await _weatherService.getForecast(
          loc.latitude,
          loc.longitude,
        );
        await _settings.setWeatherCity(city);
        if (mounted) {
          setState(() {
            _forecast = forecast;
            _isLoading = false;
          });
        }
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
          if (_forecast != null && !_isLoading)
            _WeatherForecastView(
              forecast: _forecast!,
              selectedDay: _selectedDay,
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

class _WeatherForecastView extends StatelessWidget {
  const _WeatherForecastView({
    required this.forecast,
    required this.selectedDay,
    required this.onDayChanged,
  });

  final WeatherForecast forecast;
  final int selectedDay;
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
                  '${forecast.current['temperature_2m']} °C',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          Card(
            child: ListTile(
              title: Text(l10n.weatherMaxTemperature),
              trailing: Text(
                _value('temperature_2m_max', day, '°C'),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(l10n.weatherMinTemperature),
              trailing: Text(_value('temperature_2m_min', day, '°C')),
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
