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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Text(
                    l10n.weatherToday,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      title: Text(l10n.weatherCurrentTemperature),
                      trailing: Text(
                        '${_forecast!.current['temperature_2m']} °C',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: Text(l10n.weatherWind),
                      trailing: Text('${_forecast!.current['wind_speed_10m']} km/h'),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: Text(l10n.weatherRelativeHumidity),
                      trailing: Text('${_forecast!.current['relative_humidity_2m']}%'),
                    ),
                  ),
                ],
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
