import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:flutter/foundation.dart';

class OrariSearchResult {
  final String title;
  final String url;
  final String address;
  final String status;

  OrariSearchResult({
    required this.title,
    required this.url,
    this.address = '',
    this.status = '',
  });
}

class OrariDetailResult {
  final String title;
  final String status;
  final List<String> hours;

  OrariDetailResult({
    required this.title,
    required this.status,
    required this.hours,
  });
}

class OrariAperturaService {
  static const String _baseUrl = 'https://www.oraridiapertura24.it';

  Future<List<OrariSearchResult>> search({
    required String cosa,
    required String dove,
    int distanza = 30,
  }) async {
    final formattedCosa = cosa.trim().replaceAll(RegExp(r'\s+'), '+');
    final formattedDove = dove.trim().replaceAll(RegExp(r'\s+'), '+');
    
    String path = '/cercaI/filiale-';
    if (formattedDove.isNotEmpty) {
      path += '$formattedDove-';
      if (distanza > 0) {
        path += '$distanza+km-';
      }
    }
    path += '$formattedCosa-1.html';
    
    final url = Uri.parse('$_baseUrl$path');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final doc = parser.parse(response.body);
        final containers = doc.querySelectorAll('.cboxinnerL');
        
        final results = <OrariSearchResult>[];
        for (var container in containers) {
          final link = container.querySelector('a.serpFtitleT');
          if (link == null) continue;
          
          final title = link.text.trim();
          final href = link.attributes['href'];
          
          final addrDiv = container.querySelector('.cboxAddr');
          final address = addrDiv != null ? addrDiv.text.trim().replaceAll(RegExp(r'\s+'), ' ') : '';
          
          final statusSpan = container.querySelector('#ozstatus_');
          String status = statusSpan != null ? statusSpan.text.trim().replaceAll(RegExp(r'\s+'), ' ') : '';
          status = _formatStatus(status);
          
          if (title.isNotEmpty && href != null) {
            results.add(OrariSearchResult(
              title: title,
              url: href,
              address: address,
              status: status,
            ));
          }
        }
        
        // Return unique results based on URL
        final uniqueResults = <String, OrariSearchResult>{};
        for (var res in results) {
          uniqueResults[res.url] = res;
        }
        return uniqueResults.values.toList();
      }
    } catch (e) {
      debugPrint('Errore durante la ricerca orari: $e');
    }
    
    return [];
  }

  Future<OrariDetailResult?> getOrari(String detailUrl) async {
    try {
      final url = Uri.parse(detailUrl);
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final doc = parser.parse(response.body);
        String title = '';
        final h1 = doc.querySelector('h1');
        if (h1 != null) {
          title = h1.text.trim();
        }

        String status = '';
        final badge = doc.querySelector('#badge_mobile');
        if (badge != null) {
          status = badge.text.trim();
        }
        status = _formatStatus(status);

        final hoursList = <String>[];
        final table = doc.querySelector('table.zeitenTbl');
        if (table != null) {
          final rows = table.querySelectorAll('tr');
          for (var row in rows) {
            final cols = row.querySelectorAll('td, th');
            if (cols.length >= 2) {
              final day = cols[0].text.trim().replaceAll(RegExp(r'\s+'), ' ');
              final hours = cols[1].text.trim().replaceAll(RegExp(r'\s+'), ' ');
              hoursList.add('$day: $hours');
            }
          }
        }
        
        return OrariDetailResult(
          title: title,
          status: status,
          hours: hoursList,
        );
      }
    } catch (e) {
      debugPrint('Errore durante il fetch dei dettagli orari: $e');
    }
    
    return null;
  }

  static String _formatStatus(String input) {
    if (input.isEmpty) return input;
    final regex = RegExp(r'(\d{2}):(\d{2})');
    final match = regex.firstMatch(input);
    if (match != null) {
      int hours = int.parse(match.group(1)!);
      int minutes = int.parse(match.group(2)!);
      
      String timeStr = '';
      if (hours > 0) {
        timeStr += hours.toString() + (hours == 1 ? ' ora' : ' ore');
      }
      if (minutes > 0) {
        if (timeStr.isNotEmpty) timeStr += ' e ';
        timeStr += '$minutes${minutes == 1 ? ' minuto' : ' minuti'}';
      }
      if (timeStr.isEmpty) {
        timeStr = 'meno di un minuto';
      }

      String res = input.replaceAll('${match.group(0)} ore', timeStr);
      res = res.replaceAll(match.group(0)!, timeStr);
      res = res.replaceAll('Apre in', 'Apre tra');
      res = res.replaceAll('Chiude in', 'Chiude tra');
      return res.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return input;
  }
}
