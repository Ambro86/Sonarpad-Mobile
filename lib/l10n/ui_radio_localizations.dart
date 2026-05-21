import 'app_localizations.dart';

extension UiRadioLocalizations on AppLocalizations {
  String get radio => 'Radio';
  String get radioHint =>
      'Cerca radio, ascolta streaming e gestisci le preferite';
  String get radioTitle => 'Radio da tutto il mondo';
  String get radioFavoritesButton => 'Radio preferite';
  String get radioNoFavorites => 'Nessuna radio preferita.';
  String get radioSearchText => 'Cerca radio';
  String get radioSearchHint => 'Nome radio, emittente o città...';
  String get radioLanguage => 'Lingua';
  String get radioGenre => 'Genere';
  String get radioSearch => 'Ricerca';
  String get radioSearching => 'Caricamento radio...';
  String get radioSearchResults => 'Risultati radio';
  String get radioNoResults => 'Nessuna radio trovata.';
  String radioResultsFound(int count) => 'Trovate $count radio';
  String radioSearchError(Object error) => 'Errore ricerca radio: $error';
  String radioNowPlaying(String name) => 'Riproduco $name';
  String radioPlayError(Object error) => 'Errore streaming radio: $error';
  String get radioAddFavorite => 'Aggiungi ai preferiti';
  String get radioRemoveFavorite => 'Rimuovi dai preferiti';
  String radioFavoriteAdded(String name) => '$name aggiunta ai preferiti.';
  String radioFavoriteRemoved(String name) => '$name rimossa dai preferiti.';
  String get radioAddCommunity => 'Aggiungi radio alla comunità Sonarpad';
  String get radioAddName => 'Nome radio';
  String get radioAddUrl => 'Indirizzo streaming';
  String get radioAddSubmit => 'Verifica e aggiungi';
  String get radioAddMissingFields =>
      'Inserisci nome radio e indirizzo streaming.';
  String get radioCommunityAdded =>
      'Radio aggiunta correttamente alla comunità Sonarpad.';
  String radioCommunityAddError(Object error) =>
      'Errore durante l\'aggiunta della radio: $error';
  String get radioPlay => 'Riproduci';

  String radioLanguageLabel(String code) => switch (code) {
        'it' => 'Italiano',
        'en' => 'English',
        'de' => 'Tedesco',
        'country:ch' => 'Svizzera',
        'es' => 'Spagnolo',
        'pt' => 'Portoghese',
        'sv' => 'Svedese',
        'vi' => 'Vietnamita',
        'cs' => 'Ceco',
        'pl' => 'Polacco',
        'fr' => 'Français',
        'sr' => 'Serbo',
        'uk' => 'Ucraino',
        'hi' => 'Hindi',
        'lt' => 'Lituano',
        'ru' => 'Russo',
        'zh' => 'Cinese',
        _ => code,
      };

  String radioGenreLabel(String value) => switch (value) {
        'all' => 'Tutti i generi',
        'news' => 'Notizie',
        'music' => 'Musica',
        'sport' => 'Sport',
        'talk' => 'Talk e approfondimenti',
        'pop' => 'Pop',
        'rock' => 'Rock',
        'classical' => 'Classica',
        'jazz' => 'Jazz',
        'dance' => 'Dance',
        'blues' => 'Blues',
        'country' => 'Country',
        'hiphop' => 'Hip hop',
        'electronic' => 'Elettronica',
        'latin' => 'Latina',
        'reggae' => 'Reggae',
        'metal' => 'Metal',
        'folk' => 'Folk',
        'religion' => 'Religione',
        'local' => 'Locale',
        'culture' => 'Cultura',
        'oldies' => 'Anni 70 / 80 / 90',
        'kids' => 'Bambini',
        'ambient' => 'Ambient',
        _ => value,
      };

  String radioCommunityLanguageLabel(String value) => switch (value) {
        'italian' => 'Italiano',
        'english' => 'Inglese',
        'spanish' => 'Spagnolo',
        'french' => 'Francese',
        'german' => 'Tedesco',
        'portuguese' => 'Portoghese',
        'swedish' => 'Svedese',
        'vietnamese' => 'Vietnamita',
        'czech' => 'Ceco',
        'polish' => 'Polacco',
        'serbian' => 'Serbo',
        'ukrainian' => 'Ucraino',
        'lithuanian' => 'Lituano',
        'russian' => 'Russo',
        'chinese' => 'Cinese',
        'hindi' => 'Hindi',
        _ => value,
      };
}
