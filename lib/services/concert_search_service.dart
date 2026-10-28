import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_logger.dart';

class ConcertMarket {
  const ConcertMarket(
    this.country,
    this.host,
    this.webId,
    this.partner,
    this.language,
    this.category,
  );
  final String country, host, webId, partner, language, category;
  static const all = [
    ConcertMarket(
      'IT',
      'www.ticketone.it',
      'web__ticketone-it',
      'ITT',
      'it',
      'Concerti',
    ),
    ConcertMarket(
      'DE',
      'www.eventim.de',
      'web__eventim-de',
      'EVE',
      'de',
      'Konzerte',
    ),
    ConcertMarket(
      'AT',
      'www.oeticket.com',
      'web__oeticket-at',
      'EOE',
      'de',
      'Konzerte',
    ),
    ConcertMarket(
      'CH',
      'www.ticketcorner.ch',
      'web__ticketcorner-ch',
      'TCS',
      'de',
      'Musik',
    ),
    ConcertMarket(
      'ES',
      'www.entradas.com',
      'web__entradas-com',
      'EES',
      'es',
      'Conciertos y festivales',
    ),
    ConcertMarket(
      'GB',
      'www.eventim.co.uk',
      'web__eventim-co-uk',
      'EUK',
      'en',
      'Music',
    ),
    ConcertMarket(
      'NL',
      'www.eventim.nl',
      'web__eventim-nl',
      'ENL',
      'nl',
      'Concerten',
    ),
    ConcertMarket(
      'PL',
      'www.eventim.pl',
      'web__eventim-pl',
      'PLE',
      'pl',
      'Koncerty',
    ),
    ConcertMarket(
      'SE',
      'www.eventim.se',
      'web__eventim-se',
      'ESE',
      'sv',
      'Musik',
    ),
    ConcertMarket(
      'NO',
      'www.eventim.no',
      'web__eventim-no',
      'N11',
      'no',
      'Musikk',
    ),
    ConcertMarket(
      'RO',
      'www.eventim.ro',
      'web__eventim-rou',
      'ROF',
      'ro',
      'Muzică',
    ),
    ConcertMarket(
      'FR',
      'www.eventim.fr',
      'web__eventim-fr',
      'FTT',
      'fr',
      'Concerts & Festivals',
    ),
    ConcertMarket(
      'BR',
      'www.eventim.com.br',
      'web__eventim-com-br',
      'BR1',
      'pt',
      'Shows & Música',
    ),
  ];
}

class ConcertSearchException implements Exception {
  const ConcertSearchException(this.code);
  final String code;
}

class ConcertPage {
  ConcertPage(this.items, this.page, this.pages, this.total);
  final List<Map<String, dynamic>> items;
  final int page, pages, total;
}

class ConcertSearchService {
  ConcertSearchService({
    http.Client? client,
    Future<void> Function(String)? logger,
  }) : _client = client ?? http.Client(),
       _logger = logger ?? AppLogger.log;
  final http.Client _client;
  bool _closed = false;
  final Future<void> Function(String) _logger;
  void close() {
    _closed = true;
    _client.close();
  }

  Future<ConcertPage> _get(
    ConcertMarket market,
    String endpoint,
    Map<String, String> params,
  ) async {
    if (_closed) throw const ConcertSearchException('closed');
    final uri = Uri.https(
      'public-api.eventim.com',
      '/websearch/search/api/exploration/v1/$endpoint',
      {
        'webId': market.webId,
        'retail_partner': market.partner,
        'language': market.language,
        'page_size': '20',
        ...params,
      },
    );
    for (var attempt = 1; attempt <= 2; attempt++) {
      final watch = Stopwatch()..start();
      try {
        final response = await _client
            .get(uri)
            .timeout(const Duration(seconds: 30));
        await _logger(
          '[Concerts] endpoint=$endpoint market=${market.country} page=${params['page']} http=${response.statusCode} attempt=$attempt elapsed_ms=${watch.elapsedMilliseconds}',
        );
        if ([401, 403, 429].contains(response.statusCode)) {
          throw const ConcertSearchException('access');
        }
        if (response.statusCode >= 500 && attempt < 2) {
          await Future<void>.delayed(const Duration(seconds: 1));
          continue;
        }
        if (response.statusCode != 200) {
          throw const ConcertSearchException('http');
        }
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final key = endpoint == 'cities' ? 'cities' : 'products';
        if (data is! Map ||
            data[key] is! List ||
            data['totalResults'] is! int ||
            data['totalPages'] is! int ||
            data['page'] is! int) {
          throw const ConcertSearchException('response');
        }
        return ConcertPage(
          (data[key] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList(),
          data['page'] as int,
          data['totalPages'] as int,
          data['totalResults'] as int,
        );
      } on ConcertSearchException {
        rethrow;
      } catch (_) {
        await _logger(
          '[Concerts] endpoint=$endpoint market=${market.country} attempt=$attempt transport_or_format_error elapsed_ms=${watch.elapsedMilliseconds}',
        );
        if (attempt == 2 || _closed) {
          throw const ConcertSearchException('network');
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    throw const ConcertSearchException('network');
  }

  Future<ConcertPage> cities(
    ConcertMarket market,
    String term, {
    int page = 1,
  }) => _get(market, 'cities', {'search_term': term.trim(), 'page': '$page'});

  static String iso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  Future<ConcertPage> search(
    ConcertMarket market, {
    String term = '',
    String city = '',
    DateTime? from,
    DateTime? to,
    int page = 1,
  }) {
    if (page < 1 || (from != null && to != null && to.isBefore(from))) {
      throw const ConcertSearchException('dates');
    }
    return _get(market, 'products', {
      'categories': market.category,
      'sort': 'DateAsc',
      'page': '$page',
      if (term.trim().isNotEmpty) 'search_term': term.trim(),
      if (city.isNotEmpty) 'city_names': city,
      if (from != null) 'date_from': iso(from),
      if (to != null) 'date_to': iso(to),
    });
  }

  static Uri eventUrl(ConcertMarket market, dynamic link) {
    final uri = Uri.tryParse(link is String ? link : '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443) ||
        ![
          market.host,
          market.host.replaceFirst('www.', ''),
        ].contains(uri.host)) {
      throw const ConcertSearchException('link');
    }
    return uri;
  }
}
