import 'package:flutter/material.dart';
import '../services/news/weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final _weatherService = OpenMeteoWeatherService();
  final _searchCtrl = TextEditingController(text: 'Roma');
  WeatherForecast? _forecast;
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    final city = _searchCtrl.text.trim();
    if (city.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = '';
      _forecast = null;
    });

    try {
      final cities = await _weatherService.searchCity(city);
      if (cities.isNotEmpty) {
        final loc = cities.first;
        final forecast = await _weatherService.getForecast(loc.latitude, loc.longitude);
        if (mounted) {
          setState(() {
            _forecast = forecast;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Città non trovata';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Errore durante la ricerca';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meteo'),
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
                    decoration: const InputDecoration(
                      labelText: 'Città',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _fetchWeather(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _fetchWeather,
                  child: const Text('Cerca'),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator())),
          if (_error.isNotEmpty)
            Expanded(child: Center(child: Text(_error))),
          if (_forecast != null && !_isLoading)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Text('Oggi', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      title: Text('Temperatura Attuale'),
                      trailing: Text('${_forecast!.current['temperature_2m']} °C', style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: Text('Vento'),
                      trailing: Text('${_forecast!.current['wind_speed_10m']} km/h'),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: Text('Umidità Relativa'),
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
