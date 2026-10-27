// Category IDs verified against localized Google News navigation and RSS, 2026-10-26.
Uri normalizeGoogleNewsCategoryUri(Uri uri) {
  if (uri.host.toLowerCase() != 'news.google.com') return uri;
  final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
  const prefixes = [
    '/news/rss/headlines/section/topic/',
    '/rss/headlines/section/topic/',
  ];
  String? topic;
  for (final prefix in prefixes) {
    if (path.startsWith(prefix)) {
      topic = path.substring(prefix.length);
      break;
    }
  }
  final id = switch ((uri.queryParameters['ceid'], topic)) {
    ('BR:pt-419', 'NATION') =>
      'CAAqJQgKIh9DQkFTRVFvSUwyMHZNREUxWm5JU0JYQjBMVUpTS0FBUAE',
    ('BR:pt-419', 'TECHNOLOGY') =>
      'CAAqLAgKIiZDQkFTRmdvSkwyMHZNR1ptZHpWbUVnVndkQzFDVWhvQ1FsSW9BQVAB',
    ('CZ:cs', 'NATION') => 'CAAqIQgKIhtDQkFTRGdvSUwyMHZNREZ0YW5FU0FtTnpLQUFQAQ',
    ('CZ:cs', 'TECHNOLOGY') =>
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSmpjeG9DUTFvb0FBUAE',
    ('US:en', 'NATION') =>
      'CAAqIggKIhxDQkFTRHdvSkwyMHZNRGxqTjNjd0VnSmxiaWdBUAE',
    ('FR:fr', 'NATION') =>
      'CAAqIggKIhxDQkFTRHdvSkwyMHZNR1k0YkRsakVnSm1jaWdBUAE',
    ('FR:fr', 'TECHNOLOGY') =>
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSm1jaG9DUmxJb0FBUAE',
    ('DE:de', 'NATION') => 'CAAqIQgKIhtDQkFTRGdvSUwyMHZNRE0wTldnU0FtUmxLQUFQAQ',
    ('DE:de', 'TECHNOLOGY') =>
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSmtaUm9DUkVVb0FBUAE',
    ('IT:it', 'NATION') => 'CAAqIQgKIhtDQkFTRGdvSUwyMHZNRE55YW1vU0FtbDBLQUFQAQ',
    ('IT:it', 'TECHNOLOGY') =>
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSnBkQm9DU1ZRb0FBUAE',
    ('PL:pl', 'NATION') => 'CAAqIQgKIhtDQkFTRGdvSUwyMHZNRFZ4YUhjU0FuQnNLQUFQAQ',
    ('PL:pl', 'TECHNOLOGY') =>
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSndiQm9DVUV3b0FBUAE',
    ('PT:pt-150', 'NATION') =>
      'CAAqJQgKIh9DQkFTRVFvSUwyMHZNRFZ5TkhjU0JYQjBMVkJVS0FBUAE',
    ('PT:pt-150', 'TECHNOLOGY') =>
      'CAAqLAgKIiZDQkFTRmdvSkwyMHZNR1ptZHpWbUVnVndkQzFRVkJvQ1VGUW9BQVAB',
    ('RO:ro', 'NATION') => 'CAAqIQgKIhtDQkFTRGdvSUwyMHZNRFpqTVhrU0FuSnZLQUFQAQ',
    ('CN:zh-Hans', 'NATION') =>
      'CAAqJggKIiBDQkFTRWdvSkwyMHZNR1F3TlhjekVnVjZhQzFEVGlnQVAB',
    ('ES:es', 'NATION') => 'CAAqIQgKIhtDQkFTRGdvSUwyMHZNRFp0YTJvU0FtVnpLQUFQAQ',
    ('ES:es', 'TECHNOLOGY') =>
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSmxjeG9DUlZNb0FBUAE',
    ('TR:tr', 'NATION') =>
      'CAAqIggKIhxDQkFTRHdvSkwyMHZNREY2Ym1OZkVnSjBjaWdBUAE',
    ('TR:tr', 'TECHNOLOGY') =>
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSjBjaG9DVkZJb0FBUAE',
    ('UA:uk', 'NATION') => 'CAAqIQgKIhtDQkFTRGdvSUwyMHZNRGQwTWpFU0FuVnJLQUFQAQ',
    ('UA:uk', 'TECHNOLOGY') =>
      'CAAqKAgKIiJDQkFTRXdvSkwyMHZNR1ptZHpWbUVnSjFheG9DVlVFb0FBUAE',
    _ => null,
  };
  return id == null ? uri : uri.replace(path: '/rss/topics/$id');
}
