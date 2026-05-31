import 'package:flutter/material.dart';
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
            const Expanded(child: Center(child: CircularProgressIndicator())),
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
    if (day >= 0 && day < times.length) return times[day].toString();
    return '${l10n.weatherChooseDay} ${day + 1}';
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
