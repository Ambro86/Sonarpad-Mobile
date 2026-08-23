import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tmdb_movie.dart';

class TmdbService {
  // Usa il proxy PHP per nascondere la chiave API
  static const String _baseUrl = 'https://sonarpad.com/api/tmdb.php';
  
  static const _clientToken =
      String.fromEnvironment('SONARPAD_ROUTE_CLIENT_TOKEN');

  Map<String, String> get _headers => {
        'User-Agent': 'Sonarpad/1.0.0',
        'Accept': 'application/json',
        'X-Sonarpad-Route-Token': _clientToken,
      };

  String _tmdbLanguage(String languageCode) {
    final normalized = languageCode.replaceAll('-', '_');
    if (normalized.toLowerCase() == 'pt_br') return 'pt-BR';
    final lang = normalized.split('_').first;
    return switch (lang) {
      'it' => 'it-IT',
      'fr' => 'fr-FR',
      'es' => 'es-ES',
      'pt' => 'pt-PT',
      'pl' => 'pl-PL',
      'cs' => 'cs-CZ',
      'de' => 'de-DE',
      'zh' => 'zh-CN',
      'uk' => 'uk-UA',
      _ => 'en-US',
    };
  }

  Future<List<TmdbMovie>> getNowPlaying({String languageCode = 'it'}) async {
    final langParam = _tmdbLanguage(languageCode);
    final url = Uri.parse('$_baseUrl?action=now_playing&language=$langParam');
    
    final response = await http.get(
      url,
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final jsonBody = jsonDecode(response.body);
      final List<dynamic> results = jsonBody['results'] ?? [];
      return results.map((json) => TmdbMovie.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load now playing movies: ${response.statusCode}');
    }
  }

  Future<List<TmdbMovie>> getUpcoming({String languageCode = 'it'}) async {
    final langParam = _tmdbLanguage(languageCode);
    final url = Uri.parse('$_baseUrl?action=upcoming&language=$langParam');
    
    final response = await http.get(
      url,
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final jsonBody = jsonDecode(response.body);
      final List<dynamic> results = jsonBody['results'] ?? [];
      return results.map((json) => TmdbMovie.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load upcoming movies: ${response.statusCode}');
    }
  }

  Future<String?> getTrailerUrl(int movieId, {String languageCode = 'it'}) async {
    final langParam = _tmdbLanguage(languageCode);
    final url = Uri.parse('$_baseUrl?action=trailer&movie_id=$movieId&language=$langParam');
    
    final response = await http.get(
      url,
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final jsonBody = jsonDecode(response.body);
      final List<dynamic> results = jsonBody['results'] ?? [];
      
      // Cerca un trailer, preferibilmente su YouTube
      for (var video in results) {
        if (video['type'] == 'Trailer' && video['site'] == 'YouTube') {
          final key = video['key'];
          if (key != null) {
            return 'https://www.youtube.com/watch?v=$key';
          }
        }
      }
    }
    
    return null;
  }
}
