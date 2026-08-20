import 'dart:async';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../utils/app_logger.dart';
import 'raiplay_service.dart';

enum La7PlayItemKind { page, media }

class La7PlayItem {
  const La7PlayItem({
    required this.title,
    required this.kind,
    required this.target,
    this.description,
  });

  final String title;
  final String? description;
  final La7PlayItemKind kind;
  final String target;
}

class La7PlayPage {
  const La7PlayPage({required this.title, required this.items});

  final String title;
  final List<La7PlayItem> items;
}

class La7PlayService {
  static const _base = 'https://www.la7.it';
  static const _rivedi = 'https://www.la7.it/rivedila7/0/la7';
  static const _programmi = 'https://www.la7.it/programmi';
  static const _tuttiProgrammi = 'https://www.la7.it/tutti-i-programmi';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/122.0.0.0 Safari/537.36';

  static const _programExclusions = <String>{
    '/meteola7',
    '/meteo-della-sera',
    '/tgla7',
    '/film',
    '/film-e-fiction',
  };

  static const _programMappings = <String, String>{
    '/facciaafaccia': '/faccia-a-faccia',
    '/il-boss-dei-comici': '/boss-dei-comici',
    '/lariadestate': '/laria-destate',
    '/taga-doc': '/tagada-doc',
  };

  bool isSecretCodeValid(String secretKey) =>
      RaiPlayService().isSecretCodeValid(secretKey);

  La7PlayPage rootPage() => const La7PlayPage(
        title: 'LA7 Play',
        items: [
          La7PlayItem(
            title: 'Rivedi LA7',
            kind: La7PlayItemKind.page,
            target: 'rivedi',
          ),
          La7PlayItem(
            title: 'Programmi',
            kind: La7PlayItemKind.page,
            target: 'programs',
          ),
        ],
      );

  Future<La7PlayPage> loadPage(String source) async {
    if (source == 'rivedi') return _rivediDays();
    if (source == 'programs') return _programsPage(null);
    if (source.startsWith('day:')) {
      return _rivediDay(source.substring(4));
    }
    if (source.startsWith('program:')) {
      return _programEpisodes(source.substring(8));
    }
    throw Exception('La sezione selezionata non è disponibile.');
  }

  Future<La7PlayPage> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw Exception('Inserisci il nome di un programma da cercare.');
    }
    return _programsPage(trimmed);
  }

  Future<String> resolveVod(String pageUrl) async {
    final html = await _get(pageUrl);
    final content = RegExp(
      r'\.net/i/.*?content/(.*?)(?:\.mp4)',
      caseSensitive: false,
    ).firstMatch(html);
    final contentPath = content?.group(1);
    if (contentPath != null && contentPath.isNotEmpty) {
      return 'https://awsvodpkg.iltrovatore.it/local/hls/,/content/'
          '$contentPath.mp4.urlset/master.m3u8';
    }

    final m3u8 = RegExp(
      r'''m3u8:\s*["'](.*?)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    final direct = m3u8?.group(1);
    if (direct != null && direct.isNotEmpty) {
      return direct.replaceAll(r'\/', '/');
    }

    final lower = html.toLowerCase();
    if (lower.contains('widevine') ||
        (lower.contains('license') && lower.contains('dash'))) {
      throw Exception(
        'Questo contenuto richiede Widevine e non può essere riprodotto da Sonarpad.',
      );
    }
    throw Exception(
      'Il contenuto selezionato non dispone di un flusso riproducibile.',
    );
  }

  Future<La7PlayPage> _rivediDays() async {
    final document = html_parser.parse(await _get(_rivedi));
    final items = <La7PlayItem>[];

    for (final row in document.querySelectorAll(
      'div.item--menu-guida-tv, div.item.item--menu-guida-tv',
    )) {
      final href = row.querySelector('a')?.attributes['href']?.trim() ?? '';
      if (href.isEmpty) continue;
      final title = _normalizeWhitespace([
        _text(row, '.giorno-text'),
        _text(row, '.giorno-numero'),
        _text(row, '.giorno-mese'),
      ].where((value) => value.isNotEmpty).join(' '));
      if (title.isEmpty) continue;
      items.add(
        La7PlayItem(
          title: title,
          kind: La7PlayItemKind.page,
          target: 'day:${_absolute(href)}',
        ),
      );
    }

    return La7PlayPage(
      title: 'Rivedi LA7',
      items: items.reversed.toList(growable: false),
    );
  }

  Future<La7PlayPage> _rivediDay(String url) async {
    final document = html_parser.parse(await _get(url));
    final items = <La7PlayItem>[];

    for (final row in document.querySelectorAll(
      '#content_guida_tv_rivedi div.item--guida-tv',
    )) {
      final href = row.querySelector('a')?.attributes['href']?.trim() ?? '';
      if (href.isEmpty) continue;
      final time = _text(row, '.orario');
      final name = _text(row, '.property');
      final title = time.isEmpty ? name : '$time — $name';
      if (title.trim().isEmpty) continue;
      items.add(
        La7PlayItem(
          title: title,
          description: _optionalText(row, '.occhiello'),
          kind: La7PlayItemKind.media,
          target: _absolute(href),
        ),
      );
    }

    return La7PlayPage(title: 'Rivedi LA7', items: items);
  }

  Future<La7PlayPage> _programsPage(String? query) async {
    final programs = <({String title, String target})>[];
    final seen = <String>{};

    for (final url in const [_programmi, _tuttiProgrammi]) {
      String html;
      try {
        html = await _get(url);
      } catch (_) {
        continue;
      }
      final document = html_parser.parse(html);
      for (final row in document.querySelectorAll(
        '#container-programmi-list div.list-item, div.list-item',
      )) {
        final rawHref =
            row.querySelector('a')?.attributes['href']?.trim() ?? '';
        if (rawHref.isEmpty) continue;
        final href = _mapProgramHref(rawHref);
        if (_isExcludedProgramHref(href)) continue;
        final target = _absolute(href);
        var title = _text(row, '.titolo');
        if (title.isEmpty) title = _programTitleFromHref(href);
        if (title.isEmpty) continue;

        final dedupeKey =
            '${_normalizeSearchText(title)}|${_normalizeSearchText(target)}';
        if (!seen.add(dedupeKey)) continue;
        programs.add((title: title, target: target));
      }
    }

    if (!programs.any(
      (program) => _normalizeSearchText(program.title) ==
          'la mala educaxxxion 2',
    )) {
      programs.add((
        title: 'LA MALA EDUCAXXXION 2',
        target: '$_base/la-mala-educaxxxion',
      ));
    }

    final matched = programs
        .where(
          (program) => query == null ||
              _matchesProgramQuery(program.title, program.target, query),
        )
        .toList(growable: false)
      ..sort(
        (a, b) => _normalizeSearchText(a.title)
            .compareTo(_normalizeSearchText(b.title)),
      );

    final items = <La7PlayItem>[];
    final mediaSeen = <String>{};
    for (final program in matched) {
      items.add(
        La7PlayItem(
          title: program.title,
          kind: La7PlayItemKind.page,
          target: 'program:${program.target}',
        ),
      );

      if (query != null) {
        for (final clip in await _programSearchClips(program.target)) {
          if (!mediaSeen.add(clip.target)) continue;
          items.add(
            La7PlayItem(
              title: clip.title,
              description: clip.description ?? program.title,
              kind: La7PlayItemKind.media,
              target: clip.target,
            ),
          );
        }
      }
    }

    await AppLogger.log(
      'La7PlayService: programs query=$query discovered=${programs.length} '
      'results=${items.length}',
    );

    return La7PlayPage(
      title: query == null ? 'Programmi' : 'Risultati: $query',
      items: items,
    );
  }

  Future<List<La7PlayItem>> _programSearchClips(String programUrl) async {
    String html;
    try {
      html = await _get(programUrl);
    } catch (_) {
      return const [];
    }
    final document = html_parser.parse(html);
    final seen = <String>{};
    final clips = <La7PlayItem>[];

    for (final row in document.querySelectorAll(
      '.home-block__content-inner div.item',
    )) {
      final href = row.querySelector('a')?.attributes['href']?.trim() ?? '';
      if (href.isEmpty) continue;
      final link = _absolute(href);
      if (_isProgramEpisodeUrl(link) ||
          _sameUrlWithoutQuery(link, programUrl) ||
          !seen.add(link)) {
        continue;
      }

      var title = _text(row, '.occhiello');
      if (title.isEmpty) title = _text(row, '.title, .title_puntata');
      if (title.isEmpty) continue;
      final date = _text(row, '.data');
      if (date.isNotEmpty) title = '$title ($date)';
      clips.add(
        La7PlayItem(
          title: title,
          kind: La7PlayItemKind.media,
          target: link,
        ),
      );
    }
    return clips;
  }

  Future<La7PlayPage> _programEpisodes(String url) async {
    final items = <La7PlayItem>[];
    final seen = <String>{};

    try {
      final document = html_parser.parse(await _get(url));
      for (final row in document.querySelectorAll('.ultima_puntata')) {
        _pushProgramEpisode(items, seen, row);
      }
    } catch (_) {}

    final rivediUrl = '${url.replaceFirst(RegExp(r'/+$'), '')}/rivedila7';
    try {
      final document = html_parser.parse(await _get(rivediUrl));
      final latest = document.querySelector(
        '.ultima_puntata, .contenitoreUltimaReplicaLa7d, '
        '.contenitoreUltimaReplicaNoLuminosa',
      );
      if (latest != null) _pushProgramEpisode(items, seen, latest);

      for (final row in document.querySelectorAll(
        '.home-block__content-carousel.container-vetrina div.item',
      )) {
        _pushProgramEpisode(items, seen, row);
      }
      for (final row in document.querySelectorAll(
        '.view-content.clearfix .views-row, .view-content .views-row',
      )) {
        _pushProgramEpisode(items, seen, row);
      }
    } catch (_) {}

    return La7PlayPage(title: _programTitleFromHref(url), items: items);
  }

  void _pushProgramEpisode(
    List<La7PlayItem> items,
    Set<String> seen,
    dom.Element row,
  ) {
    final href = row.querySelector('a')?.attributes['href']?.trim() ?? '';
    if (href.isEmpty) return;
    final link = _absolute(href);
    if (!_isProgramEpisodeUrl(link) || !seen.add(link)) return;

    var title = _text(row, '.title_puntata, .title');
    if (title.isEmpty) title = 'Puntata';
    final date = _text(row, '.scritta_ultima, .data');
    if (date.isNotEmpty) title = '$title ($date)';
    items.add(
      La7PlayItem(
        title: title,
        description: _optionalText(row, '.occhiello'),
        kind: La7PlayItemKind.media,
        target: link,
      ),
    );
  }

  Future<String> _get(String url) async {
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: const {
              'User-Agent': _userAgent,
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'it-IT,it;q=0.9,en;q=0.8',
              'Referer': _base,
              'Origin': _base,
            },
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      return response.body;
    } catch (error) {
      throw Exception('Impossibile caricare LA7 Play: $error');
    }
  }

  String _text(dom.Element node, String selector) {
    final element = node.querySelector(selector);
    return _normalizeWhitespace(element?.text ?? '');
  }

  String? _optionalText(dom.Element node, String selector) {
    final value = _text(node, selector);
    return value.isEmpty ? null : value;
  }

  String _absolute(String href) {
    try {
      return Uri.parse(_base).resolve(href).toString();
    } catch (_) {
      return href;
    }
  }

  String _mapProgramHref(String href) {
    final path = _programRulePath(href).toLowerCase();
    return _programMappings[path] ?? href;
  }

  bool _isExcludedProgramHref(String href) =>
      _programExclusions.contains(_programRulePath(href).toLowerCase());

  String _programRulePath(String href) {
    try {
      final uri = Uri.parse(href);
      if (uri.hasScheme) return _trimTrailingSlash(uri.path);
    } catch (_) {}
    return _trimTrailingSlash(href.split(RegExp(r'[?#]')).first);
  }

  String _programTitleFromHref(String href) {
    final path = _programRulePath(href);
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    return parts.last
        .split(RegExp(r'[-_]'))
        .where((part) => part.isNotEmpty)
        .map(_capitalizeWord)
        .join(' ');
  }

  String _capitalizeWord(String word) {
    if (word.isEmpty) return '';
    final lower = word.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  bool _matchesProgramQuery(String title, String url, String query) {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) return false;
    final words = normalizedQuery.split(' ').where((word) => word.isNotEmpty);
    final normalizedTitle = _normalizeSearchText(title);
    final normalizedUrl = _normalizeSearchText(url);
    return _queryMatchesText(normalizedQuery, words, normalizedTitle) ||
        _queryMatchesText(normalizedQuery, words, normalizedUrl);
  }

  bool _queryMatchesText(
    String query,
    Iterable<String> words,
    String text,
  ) =>
      text.contains(query) || words.isNotEmpty && words.every((word) => text.contains(word));

  String _normalizeSearchText(String value) {
    var normalized = value.trim().toLowerCase();
    const apostrophes = ["'", '’', '`', '´', 'ʼ'];
    for (final apostrophe in apostrophes) {
      normalized = normalized.replaceAll(apostrophe, '');
    }
    const folds = <String, String>{
      'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    folds.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isProgramEpisodeUrl(String url) {
    try {
      return Uri.parse(url).path.toLowerCase().contains('/rivedila7/');
    } catch (_) {
      return url.toLowerCase().contains('/rivedila7/');
    }
  }

  bool _sameUrlWithoutQuery(String left, String right) =>
      _normalizedUrlPath(left) == _normalizedUrlPath(right);

  String _normalizedUrlPath(String value) {
    try {
      return _trimTrailingSlash(Uri.parse(value).path).toLowerCase();
    } catch (_) {
      return _trimTrailingSlash(value.split(RegExp(r'[?#]')).first)
          .toLowerCase();
    }
  }

  String _trimTrailingSlash(String value) =>
      value.length > 1 ? value.replaceFirst(RegExp(r'/+$'), '') : value;

  String _normalizeWhitespace(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
