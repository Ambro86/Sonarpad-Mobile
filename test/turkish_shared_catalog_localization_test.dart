import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations_lookup.dart';
import 'package:sonarpad_mobile_starter/services/internet_archive_service.dart';
import 'package:sonarpad_mobile_starter/services/librivox_service.dart';
import 'package:sonarpad_mobile_starter/services/poetrydb_service.dart';

http.Response _jsonResponse(Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  test('LibriVox missing metadata localizes after loading and library reload',
      () async {
    late Uri requested;
    final service = LibrivoxService(client: MockClient((request) async {
      requested = request.url;
      return _jsonResponse({
        'books': [
          {
            'id': '17',
            'language': 'English',
            'sections': [
              {
                'id': '4',
                'section_number': '2',
                'listen_url': 'https://example.org/17/4.mp3',
              },
            ],
          },
        ],
      });
    }));

    final book = await service.fetchBook(17);
    expect(requested.host, 'librivox.org');
    expect(requested.queryParameters['id'], '17');
    expect(book.title, isEmpty);
    expect(book.authors, isEmpty);
    expect(book.language, 'English');
    expect(book.sections.single.number, 2);
    expect(book.sections.single.listenUrl, 'https://example.org/17/4.mp3');

    final reloaded = librivoxBookFromLibraryPath(book.encodeForLibrary());
    for (final locale in ['tr', 'tr_TR', 'tr-TR']) {
      final l10n = lookupSupportedAppLocalizations(locale);
      expect(reloaded.titleLabel(l10n), 'Başlıksız');
      expect(reloaded.authorLabel(l10n), 'Bilinmeyen yazar');
      expect(reloaded.sections.single.titleLabel(l10n), 'Bölüm');
    }
    final italian = lookupSupportedAppLocalizations('it');
    expect(reloaded.titleLabel(italian), 'Senza titolo');
    expect(reloaded.authorLabel(italian), 'Autore sconosciuto');
    expect(reloaded.sections.single.titleLabel(italian), 'Capitolo');
    expect(reloaded.toLibraryJson(), book.toLibraryJson());
    expect(reloaded.title, isEmpty);
    expect(reloaded.sections.single.title, isEmpty);
  });

  test('real catalogue text is retained even when it resembles a fallback',
      () async {
    final l10n = lookupSupportedAppLocalizations('tr');
    final service = LibrivoxService(client: MockClient((_) async {
      return _jsonResponse({
        'books': [
          {
            'id': 1,
            'title': 'Senza titolo',
            'authors': [
              {'first_name': 'Autore', 'last_name': 'sconosciuto'},
            ],
            'sections': [
              {
                'id': 2,
                'title': 'Capitolo',
                'listen_url': 'https://example.org/track.mp3',
              },
            ],
          },
        ],
      });
    }));
    final book = await service.fetchBook(1);
    expect(book.titleLabel(l10n), 'Senza titolo');
    expect(book.authorLabel(l10n), 'Autore sconosciuto');
    expect(book.sections.single.titleLabel(l10n), 'Capitolo');

    const poem = PoetryDbPoem(
      title: 'Senza titolo',
      author: 'Autore sconosciuto',
      lines: ['Original poem text.'],
      lineCount: 1,
    );
    expect(poem.toDocumentText(localizations: l10n),
        'Senza titolo\nAutore sconosciuto\n\nOriginal poem text.');
    final track = InternetArchiveTrack.fromJson({'title': 'Audio'});
    expect(track.titleLabel(l10n), 'Audio');
  });

  test('LibriVox catalogue matching retains its previous fallback behavior',
      () async {
    final service = LibrivoxService(client: MockClient((_) async {
      return _jsonResponse({
        'books': [
          {'id': 19, 'title': 'An original title'},
        ],
      });
    }));
    final page = await service.searchBooks('sconosciuto');
    expect(page.books.single.id, 19);
    expect(page.books.single.authorLabel(lookupSupportedAppLocalizations('tr')),
        'Bilinmeyen yazar');
  });

  test('LibriVox HTTP errors keep status while 404 retains search semantics',
      () async {
    final l10n = lookupSupportedAppLocalizations('tr');
    final unavailable = LibrivoxService(
      client: MockClient((_) async => http.Response('', 503)),
    );
    await expectLater(
      unavailable.searchBooks(''),
      throwsA(isA<LibrivoxRequestException>()
          .having((error) => error.statusCode, 'status', 503)
          .having((error) => error.localizedMessage(l10n), 'app message',
              'LibriVox hatası: 503')),
    );

    final missing = LibrivoxService(
      client: MockClient((_) async => http.Response('', 404)),
    );
    expect((await missing.searchBooks('')).books, isEmpty);
    await expectLater(
      missing.fetchBook(17),
      throwsA(isA<LibrivoxRequestException>().having(
        (error) => error.localizedMessage(l10n),
        'app message',
        'Sesli kitap bulunamadı.',
      )),
    );
  });

  test('empty LibriVox book responses retain the not-found result', () async {
    final service = LibrivoxService(
      client: MockClient((_) async => _jsonResponse({'books': []})),
    );
    await expectLater(
      service.fetchBook(17),
      throwsA(isA<LibrivoxRequestException>().having(
        (error) => error.localizedMessage(lookupSupportedAppLocalizations('tr')),
        'app message',
        'Sesli kitap bulunamadı.',
      )),
    );
  });

  test('PoetryDB imports localized missing metadata with original poem lines',
      () async {
    late Uri requested;
    final service = PoetryDbService(client: MockClient((request) async {
      requested = request.url;
      return _jsonResponse([
        {
          'lines': ['The original first line.', '', 'The final line — unchanged.'],
          'linecount': '3',
        },
      ]);
    }));

    final poem = (await service.search('hope', field: PoetryDbSearchField.title))
        .single;
    expect(requested.host, 'poetrydb.org');
    expect(requested.pathSegments, ['title', 'hope']);
    expect(requested.queryParameters, isEmpty);
    expect(poem.lineCount, 3);
    expect(poem.title, isEmpty);
    expect(poem.author, isEmpty);
    for (final locale in ['tr', 'tr_TR', 'tr-TR']) {
      final l10n = lookupSupportedAppLocalizations(locale);
      expect(poem.toDocumentText(localizations: l10n),
          'Başlıksız\nBilinmeyen yazar\n\nThe original first line.\n\nThe final line — unchanged.');
    }
    expect(poem.toDocumentText(),
        'Senza titolo\nAutore sconosciuto\n\nThe original first line.\n\nThe final line — unchanged.');
    expect(poem.title, isEmpty);
    expect(poem.author, isEmpty);
  });

  test('PoetryDB localizes HTTP failure and preserves its no-results response',
      () async {
    final unavailable = PoetryDbService(
      client: MockClient((_) async => http.Response('', 502)),
    );
    await expectLater(
      unavailable.search('hope', field: PoetryDbSearchField.author),
      throwsA(isA<PoetryDbRequestException>()
          .having((error) => error.statusCode, 'status', 502)
          .having(
            (error) => error.localizedMessage(lookupSupportedAppLocalizations('tr')),
            'app message',
            'PoetryDB hatası: 502',
          )),
    );
    final noResults = PoetryDbService(
      client: MockClient((_) async => _jsonResponse({'status': 404})),
    );
    expect(await noResults.search('hope', field: PoetryDbSearchField.title), isEmpty);
  });

  test('Internet Archive saved audio fallback is localized without rewriting data',
      () {
    final item = InternetArchiveItem.fromLibraryJson({
      'identifier': 'original-identifier',
      'tracks': [
        {
          'fileName': 'original.mp3',
          'audioUrl': 'https://archive.org/download/original-identifier/original.mp3',
        },
      ],
    });
    final reloaded = internetArchiveItemFromLibraryPath(item.encodeForLibrary());
    expect(reloaded.title, 'Internet Archive');
    expect(reloaded.creatorLabel, 'original-identifier');
    expect(reloaded.tracks.single.title, isEmpty);
    expect(reloaded.tracks.single.titleLabel(lookupSupportedAppLocalizations('tr')),
        'Ses kaydı');
    expect(reloaded.tracks.single.titleLabel(lookupSupportedAppLocalizations('it')),
        'Audio');
    expect(reloaded.toLibraryJson(), item.toLibraryJson());
  });

  test('Internet Archive filename fallback remains original source content',
      () async {
    final service = InternetArchiveService(client: MockClient((_) async {
      return _jsonResponse({
        'files': [
          {'name': 'Original folder/Original title.mp3', 'format': 'VBR MP3'},
        ],
      });
    }));
    final item = InternetArchiveItem.fromLibraryJson({'identifier': 'original'});
    final loaded = await service.fetchItem(item);
    expect(loaded.tracks.single.titleLabel(lookupSupportedAppLocalizations('tr')),
        'Original title');
    expect(Uri.parse(loaded.tracks.single.audioUrl).pathSegments,
        ['download', 'original', 'Original folder', 'Original title.mp3']);
  });

  test('Internet Archive search and metadata failures use app-language messages',
      () async {
    final service = InternetArchiveService(
      client: MockClient((_) async => http.Response('', 503)),
    );
    final localizedFailure = throwsA(isA<InternetArchiveRequestException>()
        .having((error) => error.statusCode, 'status', 503)
        .having(
          (error) => error.localizedMessage(lookupSupportedAppLocalizations('tr')),
          'app message',
          'Internet Archive hatası: 503',
        ));
    await expectLater(
      service.searchItems(source: InternetArchiveSource.speeches, query: 'history'),
      localizedFailure,
    );
    await expectLater(
      service.fetchItem(InternetArchiveItem.fromLibraryJson({'identifier': 'original'})),
      localizedFailure,
    );
  });
}
