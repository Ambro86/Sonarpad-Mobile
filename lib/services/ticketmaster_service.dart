import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/concert_event.dart';

class TicketmasterService {
  static const String _baseUrl = 'https://sonarpad.com/api/ticketmaster.php';
  
  static const _clientToken =
      String.fromEnvironment('SONARPAD_ROUTE_CLIENT_TOKEN');

  Map<String, String> get _headers => {
        'User-Agent': 'Sonarpad/1.0.0',
        'Accept': 'application/json',
        'X-Sonarpad-Route-Token': _clientToken,
      };

  Future<List<ConcertEvent>> getConcertsByCity(String city) async {
    final url = Uri.parse('$_baseUrl?city=${Uri.encodeComponent(city)}');
    
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final jsonBody = jsonDecode(response.body);
      
      if (jsonBody['ok'] == false) {
         throw Exception(jsonBody['error'] ?? 'Errore dal server');
      }

      final embedded = jsonBody['_embedded'];
      if (embedded == null) return []; // Nessun concerto
      
      final List<dynamic> events = embedded['events'] ?? [];
      return events.map((json) => ConcertEvent.fromJson(json)).toList();
    } else {
      throw Exception('Caricamento concerti fallito (Errore ${response.statusCode})');
    }
  }
}
