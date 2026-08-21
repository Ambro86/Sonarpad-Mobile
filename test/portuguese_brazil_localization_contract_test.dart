import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

int _arrayStringCount(String source, String name) {
  final start = source.indexOf('final $name = [');
  if (start < 0) return 0;
  final end = source.indexOf('];', start);
  if (end < 0) return 0;
  final body = source.substring(start, end);
  return RegExp(r'^\s*"', multiLine: true).allMatches(body).length;
}

String _arbText(Map<String, dynamic> arb) => _messageKeys(arb)
    .map((key) => arb[key])
    .whereType<String>()
    .join('\n');

String _portugueseSaintText(String source) => RegExp(
      r'^    "(?:pt|pt_BR)": "(.*)",$',
      multiLine: true,
    ).allMatches(source).map((match) => match.group(1) ?? '').join('\n');

void main() {
  test('Brazilian Portuguese ARB covers every Portuguese message', () {
    final portugal = _arb('lib/l10n/app_pt.arb');
    final brazil = _arb('lib/l10n/app_pt_BR.arb');

    expect(portugal['@@locale'], 'pt');
    expect(brazil['@@locale'], 'pt_BR');
    expect(_messageKeys(brazil), _messageKeys(portugal));
    expect(_messageKeys(brazil).length, 993);
  });

  test('Portugal and Brazil are distinct app language choices', () {
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final service =
        File('lib/services/app_settings_service.dart').readAsStringSync();
    final generated = File('lib/l10n/app_localizations.dart').readAsStringSync();

    expect(settings, contains("value: 'pt_BR'"));
    expect(settings, contains('radioCountryOptionBr'));
    expect(settings, contains('radioCountryOptionPt'));
    expect(service, contains("'pt_BR'"));
    expect(generated, contains("Locale('pt', 'BR')"));
    expect(generated, contains('AppLocalizationsPtBr'));
  });

  test('Brazilian news contains supplied feeds and Brazil Google News locale', () {
    final sources = File(
      'lib/services/news_sources/brazilian_portuguese_news_sources.dart',
    ).readAsStringSync();
    const expected = <String>[
      'https://agenciabrasil.ebc.com.br/rss/ultimasnoticias/feed.xml',
      'https://www.cnnbrasil.com.br/ultimas-noticias/feed/',
      'https://g1.globo.com/rss/g1/',
      'https://feeds.folha.uol.com.br/emcimadahora/rss091.xml',
      'https://rss.uol.com.br/feed/noticias.xml',
      'https://tecnoblog.net/feed/',
      'https://canaltech.com.br/rss/',
      'https://olhardigital.com.br/feed/',
    ];
    for (final url in expected) {
      expect(sources, contains(url));
    }
    expect(sources, contains('hl=pt-BR&gl=BR&ceid=BR:pt-419'));
  });

  test('Brazilian locale selects Brazil in dynamic services', () {
    final news = File('lib/screens/news_screen.dart').readAsStringSync();
    final podcasts = File('lib/screens/podcast_screen.dart').readAsStringSync();
    final radio = File('lib/screens/radio_screen.dart').readAsStringSync();
    final routes = File('lib/screens/route_screen.dart').readAsStringSync();
    final tmdb = File('lib/services/tmdb_service.dart').readAsStringSync();
    final cinema = File('lib/screens/cinema_screen.dart').readAsStringSync();
    final cinemaUpcoming =
        File('lib/screens/cinema_upcoming_screen.dart').readAsStringSync();
    final cinemaDetail =
        File('lib/screens/cinema_detail_screen.dart').readAsStringSync();
    final wikipedia = File('lib/screens/wikipedia_screen.dart').readAsStringSync();
    final gutenberg = File('lib/screens/gutenberg_screen.dart').readAsStringSync();

    expect(news, contains("'pt_BR' => NewsLanguage.portugueseBrazil"));
    expect(news, contains("NewsLanguage.portugueseBrazil => 'pt-419'"));
    expect(podcasts, contains("case 'pt_BR':"));
    expect(podcasts, contains("return 'br';"));
    expect(radio, contains("'pt_BR' => 'br'"));
    expect(routes, contains("'pt_BR' => 'br'"));
    expect(tmdb, contains("return 'pt-BR'"));
    expect(cinema, contains('Localizations.localeOf(context).toString()'));
    expect(cinemaUpcoming, contains('Localizations.localeOf(context).toString()'));
    expect(cinemaDetail, contains('Localizations.localeOf(context).toString()'));
    expect(cinema, isNot(contains('Localizations.localeOf(context).languageCode')));
    expect(cinemaUpcoming,
        isNot(contains('Localizations.localeOf(context).languageCode')));
    expect(cinemaDetail,
        isNot(contains('Localizations.localeOf(context).languageCode')));
    expect(wikipedia, contains("'pt_BR' => 'pt'"));
    expect(gutenberg, contains("locale == 'pt_BR' ? 'pt' : locale"));
  });

  test('calendar has separate Brazilian saints, holidays and quotes', () {
    final saints = File('lib/services/calendar/saints_data.dart').readAsStringSync();
    final calendar =
        File('lib/services/calendar/calendar_service.dart').readAsStringSync();

    expect(RegExp(r'^    "pt_BR":', multiLine: true).allMatches(saints).length, 365);
    expect(calendar, contains('Confraternização Universal'));
    expect(calendar, contains('Tiradentes'));
    expect(calendar, contains('Independência do Brasil'));
    expect(calendar, contains('Nossa Senhora Aparecida'));
    expect(calendar, contains('Proclamação da República'));
    expect(calendar, contains('Consciência Negra'));
    expect(calendar, contains('final quotesPtBr = ['));
    expect(_arrayStringCount(calendar, 'quotesPt'), 128);
    expect(_arrayStringCount(calendar, 'quotesPtBr'), 128);
    expect(calendar, contains('isBrazilianPortuguese ? quotesPtBr : quotesPt'));
    expect(calendar, contains('Séneca'));
    expect(calendar, contains('Sêneca'));
    expect(calendar, contains('Faça cada coisa com calma e ordem.'));
    expect(calendar, contains('Não chore porque acabou, sorria porque aconteceu.'));
    expect(calendar, contains('A vida é importante demais para ser levada a sério.'));
    expect(saints, contains('"pt": "Santo Antão, abade"'));
    expect(saints, contains('"pt_BR": "Santo Antão, abade"'));
  });

  test('Portuguese saint data is free of known Spanish contamination', () {
    final saints = File('lib/services/calendar/saints_data.dart').readAsStringSync();
    final portuguese = _portugueseSaintText(saints);
    const forbidden = <String>[
      'Nuestra Señora',
      'Miércoles de Ceniza',
      'Éxtasis de Santa Teresa',
      'Presentación de Maria',
      'Dedicación da Basílica',
      'Corazón de Jesús',
      'Ascensión de Jesús',
      'Congregación',
      'Santísima Trinidad',
      'Pentecostés',
      'Pavía',
      'Hungría',
      'João de Dios',
      'Macario I de Jerusalén',
      'Matilde de Alemania',
      'Teresa de Calcuta',
      'Mártires de Corea',
      'Marta de Betania',
      'Dulce Nombre',
      'Hermanas Pasionistas',
      'Muerte e funeral',
      'Padua',
      'Nursia',
      'Nereo e Aquileo',
    ];
    for (final value in forbidden) {
      expect(portuguese, isNot(contains(value)), reason: value);
    }
  });


  test('Portuguese ARBs contain no known Spanish or cross-variant residue', () {
    final portugal = _arb('lib/l10n/app_pt.arb');
    final brazil = _arb('lib/l10n/app_pt_BR.arb');
    final ptText = _arbText(portugal).toLowerCase();
    final brText = _arbText(brazil).toLowerCase();

    const spanishResidue = <String>[
      ' síntesis ',
      ' otra ',
      ' archivo ',
      ' carpeta ',
      ' pantalla ',
      ' listo',
      ' buscando',
      ' reproduciendo',
      ' guardando',
      ' descargando',
      ' selección ',
      ' añadir ',
      ' nuestra señora',
      ' miércoles',
      ' corazón',
      ' presentación',
      ' dedicación',
    ];
    for (final value in spanishResidue) {
      expect(' $ptText ', isNot(contains(value)), reason: 'pt: $value');
      expect(' $brText ', isNot(contains(value)), reason: 'pt_BR: $value');
    }

    const brazilianInPortugal = <String>[
      'preparando o audiolivro',
      'gerando áudio',
      'ouvir prévia',
      'digite a cidade',
      ' arquivo ',
      ' mídia ',
      ' configurações',
      ' tela ',
      ' celular ',
      ' aplicativo ',
      ' usuário ',
      ' compartilhar',
    ];
    for (final value in brazilianInPortugal) {
      expect(' $ptText ', isNot(contains(value)), reason: value);
    }

    const europeanInBrazil = <String>[
      'sistema operativo',
      'casa de banho',
      'a extrair texto',
      'a finalizar',
      'a atualizar países',
      'a mostrar o resumo',
      'ponto de paragem',
      'está a começar',
      ' ficheiro ',
      ' multimédia',
      ' definições',
      ' ecrã ',
      ' telemóvel',
      ' utilizador',
      ' partilhar',
    ];
    for (final value in europeanInBrazil) {
      expect(' $brText ', isNot(contains(value)), reason: value);
    }

    expect(brText, isNot(contains('parpesquisando')));
    expect(brText, isNot(contains('parreproduzindo')));
  });

  test('Portuguese runtime fallbacks do not leak known Italian UI text', () {
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final mediaCutter =
        File('lib/screens/media_cutter_screen.dart').readAsStringSync();
    final helper =
        File('lib/l10n/localized_dynamic_labels.dart').readAsStringSync();

    expect(settings, isNot(contains("'\$totalSeconds secondi'")));
    expect(settings, isNot(contains("'1 secondo'")));
    expect(settings, isNot(contains("'\$s secondi'")));
    expect(settings, contains('mediaCutterDurationSecondOne'));
    expect(settings, contains('mediaCutterDurationMinuteOne'));

    expect(mediaCutter, contains('localizeTechnicalError(error)'));
    expect(mediaCutter, contains('mediaCutterExportFinalVerification'));
    expect(mediaCutter, contains('mediaCutterExportMergeParts'));
    expect(mediaCutter, contains('mediaCutterExportFileCheck'));
    expect(mediaCutter, contains('mediaCutterExportPublishing'));
    expect(mediaCutter, contains('mediaCutterExportCompletion'));

    expect(helper, contains('Nessun testo trovato nel documento DOCX.'));
    expect(helper, contains('Audiolibro non trovato.'));
    expect(helper, contains('Errore nel login Dropbox:'));
    expect(helper, contains('Errore Gutenberg'));
    expect(helper, contains('Nessun flusso riproducibile disponibile.'));
    expect(helper, contains('Errore feed podcast:'));
    expect(helper, contains('Errore RSS'));
    expect(helper, contains('Errore PoetryDB'));
    expect(helper, contains('Cartella inaccessibile per via delle protezioni di sistema'));
    expect(helper, contains('Impossibile generare il pacchetto EPUB.'));
    expect(helper, contains('Impossibile generare il pacchetto DOCX.'));
    expect(helper,
        contains('Impossibile analizzare le tracce del file multimediale.'));

    final sonarTube =
        File('lib/screens/sonartube_screen.dart').readAsStringSync();
    final podcasts =
        File('lib/screens/podcast_screen.dart').readAsStringSync();
    final news = File('lib/screens/news_screen.dart').readAsStringSync();
    final poetry = File('lib/screens/poetrydb_screen.dart').readAsStringSync();
    final audio =
        File('lib/services/audio_player_service.dart').readAsStringSync();
    expect(sonarTube, contains('localizeTechnicalError(_error!)'));
    expect(podcasts, contains('localizeTechnicalError(snapshot.error!)'));
    expect(news, contains('localizeTechnicalError(snapshot.error!)'));
    expect(poetry, contains('localizeTechnicalError(snapshot.error!)'));
    expect(audio, isNot(contains('Lettura Documento')));
    expect(audio, isNot(contains('Lettura Vocale')));
    expect(audio, isNot(contains('Riproduzione Audio')));
  });

  test('Portuguese changelog is complete for Portugal and Brazil', () {
    final decoded = jsonDecode(
      File('assets/changelog.json').readAsStringSync(),
    ) as List<dynamic>;
    expect(decoded, isNotEmpty);
    for (final raw in decoded) {
      final entry = raw as Map<String, dynamic>;
      final portugal = (entry['pt'] as List<dynamic>)
          .whereType<String>()
          .toList();
      final brazil = (entry['pt_BR'] as List<dynamic>)
          .whereType<String>()
          .toList();
      expect(portugal, isNotEmpty);
      expect(brazil, isNotEmpty);
      expect(portugal.every((line) => line.trim().isNotEmpty), isTrue);
      expect(brazil.every((line) => line.trim().isNotEmpty), isTrue);
    }
  });

  test('iOS advertises Brazilian Portuguese and localized permissions', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final brazil =
        File('ios/Runner/pt-BR.lproj/InfoPlist.strings').readAsStringSync();
    expect(plist, contains('<string>pt-BR</string>'));
    expect(brazil, contains('NSCameraUsageDescription'));
    expect(brazil, contains('NSCalendarsUsageDescription'));
    expect(brazil, contains('NSContactsUsageDescription'));
  });
}

