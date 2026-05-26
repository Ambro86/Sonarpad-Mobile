import 'app_localizations.dart';

extension UiRadioLocalizations on AppLocalizations {
  String get radio => _isEn ? 'Radio' : (_isFr ? 'Radio' : (_isEs ? 'Radio' : 'Radio'));
  String get radioHint => _isEn
      ? 'Search radios, listen to streams and manage favorites'
      : (_isFr ? 'Rechercher des radios, écouter des flux et gérer les favoris' : (_isEs ? 'Busca radios, escucha streams y gestiona favoritos' : 'Cerca radio, ascolta streaming e gestisci le preferite'));
  String get radioTitle => _isEn ? 'Radios from all over the world' : (_isFr ? 'Radios du monde entier' : (_isEs ? 'Radios de todo el mundo' : 'Radio da tutto il mondo'));
  String get radioFavoritesButton => _isEn ? 'Favorite radios' : (_isFr ? 'Radios favorites' : (_isEs ? 'Radios favoritas' : 'Radio preferite'));
  String get radioNoFavorites => _isEn ? 'No favorite radios.' : (_isFr ? 'Aucune radio favorite.' : (_isEs ? 'No hay radios favoritas.' : 'Nessuna radio preferita.'));
  String get radioSearchText => _isEn ? 'Search radio' : (_isFr ? 'Rechercher une radio' : (_isEs ? 'Buscar radio' : 'Cerca radio'));
  String get radioSearchHint => _isEn ? 'Radio name, station or city...' : (_isFr ? 'Nom de la radio, station ou ville...' : (_isEs ? 'Nombre de la radio, emisora o ciudad...' : 'Nome radio, emittente o città...'));
  String get radioLanguage => _isEn ? 'Language' : (_isFr ? 'Langue' : (_isEs ? 'Idioma' : 'Lingua'));
  String get radioGenre => _isEn ? 'Genre' : (_isFr ? 'Genre' : (_isEs ? 'Género' : 'Genere'));
  String get radioSearch => _isEn ? 'Search' : (_isFr ? 'Recherche' : (_isEs ? 'Buscar' : 'Ricerca'));
  String get radioSearching => _isEn ? 'Loading radios...' : (_isFr ? 'Chargement des radios...' : (_isEs ? 'Cargando radios...' : 'Caricamento radio...'));
  String get radioSearchResults => _isEn ? 'Radio results' : (_isFr ? 'Résultats radio' : (_isEs ? 'Resultados de radio' : 'Risultati radio'));
  String get radioNoResults => _isEn ? 'No radios found.' : (_isFr ? 'Aucune radio trouvée.' : (_isEs ? 'No se encontraron radios.' : 'Nessuna radio trovata.'));
  String radioResultsFound(int count) => _isEn ? 'Found $count radios' : (_isFr ? '$count radios trouvées' : (_isEs ? '$count radios encontradas' : 'Trovate $count radio'));
  String radioSearchError(Object error) => _isEn ? 'Radio search error: $error' : (_isFr ? 'Erreur de recherche radio : $error' : (_isEs ? 'Error en la búsqueda de radio: $error' : 'Errore ricerca radio: $error'));
  String radioNowPlaying(String name) => _isEn ? 'Playing $name' : (_isFr ? 'Lecture de $name' : (_isEs ? 'Reproduciendo $name' : 'Riproduco $name'));
  String radioPlayError(Object error) => _isEn ? 'Radio stream error: $error' : (_isFr ? 'Erreur de flux radio : $error' : (_isEs ? 'Error en la transmisión de radio: $error' : 'Errore streaming radio: $error'));
  String get radioAddFavorite => _isEn ? 'Add to favorites' : (_isFr ? 'Ajouter aux favoris' : (_isEs ? 'Añadir a favoritos' : 'Aggiungi ai preferiti'));
  String get radioRemoveFavorite => _isEn ? 'Remove from favorites' : (_isFr ? 'Retirer des favoris' : (_isEs ? 'Eliminar de favoritos' : 'Rimuovi dai preferiti'));
  String radioFavoriteAdded(String name) => _isEn ? '$name added to favorites.' : (_isFr ? '$name ajoutée aux favoris.' : (_isEs ? '$name añadida a favoritos.' : '$name aggiunta ai preferiti.'));
  String radioFavoriteRemoved(String name) => _isEn ? '$name removed from favorites.' : (_isFr ? '$name retirée des favoris.' : (_isEs ? '$name eliminada de favoritos.' : '$name rimossa dai preferiti.'));
  String get radioAddCommunity => _isEn ? 'Add radio to Sonarpad community' : (_isFr ? 'Ajouter une radio à la communauté Sonarpad' : (_isEs ? 'Añadir radio a la comunidad Sonarpad' : 'Aggiungi radio alla comunità Sonarpad'));
  String get radioAddName => _isEn ? 'Radio name' : (_isFr ? 'Nom de la radio' : (_isEs ? 'Nombre de la radio' : 'Nome radio'));
  String get radioAddUrl => _isEn ? 'Stream address' : (_isFr ? 'Adresse du flux' : (_isEs ? 'Dirección de la transmisión' : 'Indirizzo streaming'));
  String get radioAddSubmit => _isEn ? 'Verify and add' : (_isFr ? 'Vérifier et ajouter' : (_isEs ? 'Verificar y añadir' : 'Verifica e aggiungi'));
  String get radioAddMissingFields => _isEn
      ? 'Please enter radio name and stream address.'
      : (_isFr ? 'Veuillez saisir le nom de la radio et l\'adresse du flux.' : (_isEs ? 'Por favor ingresa el nombre de la radio y la dirección de la transmisión.' : 'Inserisci nome radio e indirizzo streaming.'));
  String get radioCommunityAdded => _isEn
      ? 'Radio successfully added to Sonarpad community.'
      : (_isFr ? 'Radio ajoutée avec succès à la communauté Sonarpad.' : (_isEs ? 'Radio añadida con éxito a la comunidad Sonarpad.' : 'Radio aggiunta correttamente alla comunità Sonarpad.'));
  String radioCommunityAddError(Object error) => _isEn
      ? 'Error adding radio: $error'
      : (_isFr ? 'Erreur lors de l\'ajout de la radio : $error' : (_isEs ? 'Error al añadir la radio: $error' : 'Errore durante l\'aggiunta della radio: $error'));
  String get radioPlay => _isEn ? 'Play' : (_isFr ? 'Lire' : (_isEs ? 'Reproducir' : 'Riproduci'));

  String radioLanguageLabel(String code) => switch (code) {
        'it' => _isEn ? 'Italian' : (_isFr ? 'Italien' : (_isEs ? 'Italiano' : 'Italiano')),
        'en' => _isEn ? 'English' : (_isFr ? 'Anglais' : (_isEs ? 'Inglés' : 'English')),
        'de' => _isEn ? 'German' : (_isFr ? 'Allemand' : (_isEs ? 'Alemán' : 'Tedesco')),
        'country:ch' => _isEn ? 'Switzerland' : (_isFr ? 'Suisse' : (_isEs ? 'Suiza' : 'Svizzera')),
        'es' => _isEn ? 'Spanish' : (_isFr ? 'Espagnol' : (_isEs ? 'Español' : 'Spagnolo')),
        'pt' => _isEn ? 'Portuguese' : (_isFr ? 'Portugais' : (_isEs ? 'Portugués' : 'Portoghese')),
        'sv' => _isEn ? 'Swedish' : (_isFr ? 'Suédois' : (_isEs ? 'Sueco' : 'Svedese')),
        'vi' => _isEn ? 'Vietnamese' : (_isFr ? 'Vietnamien' : (_isEs ? 'Vietnamita' : 'Vietnamita')),
        'cs' => _isEn ? 'Czech' : (_isFr ? 'Tchèque' : (_isEs ? 'Checo' : 'Ceco')),
        'pl' => _isEn ? 'Polish' : (_isFr ? 'Polonais' : (_isEs ? 'Polaco' : 'Polacco')),
        'fr' => _isEn ? 'French' : (_isFr ? 'Français' : (_isEs ? 'Francés' : 'Français')),
        'sr' => _isEn ? 'Serbian' : (_isFr ? 'Serbe' : (_isEs ? 'Serbio' : 'Serbo')),
        'uk' => _isEn ? 'Ukrainian' : (_isFr ? 'Ukrainien' : (_isEs ? 'Ucraniano' : 'Ucraino')),
        'hi' => _isEn ? 'Hindi' : (_isFr ? 'Hindi' : (_isEs ? 'Hindi' : 'Hindi')),
        'lt' => _isEn ? 'Lithuanian' : (_isFr ? 'Lituanien' : (_isEs ? 'Lituano' : 'Lituano')),
        'ru' => _isEn ? 'Russian' : (_isFr ? 'Russe' : (_isEs ? 'Ruso' : 'Russo')),
        'zh' => _isEn ? 'Chinese' : (_isFr ? 'Chinois' : (_isEs ? 'Chino' : 'Cinese')),
        _ => code,
      };

  String radioGenreLabel(String value) => switch (value) {
        'all' => _isEn ? 'All genres' : (_isFr ? 'Tous les genres' : (_isEs ? 'Todos los géneros' : 'Tutti i generi')),
        'news' => _isEn ? 'News' : (_isFr ? 'Actualités' : (_isEs ? 'Noticias' : 'Notizie')),
        'music' => _isEn ? 'Music' : (_isFr ? 'Musique' : (_isEs ? 'Música' : 'Musica')),
        'sport' => _isEn ? 'Sport' : (_isFr ? 'Sport' : (_isEs ? 'Deporte' : 'Sport')),
        'talk' => _isEn ? 'Talk and insights' : (_isFr ? 'Talk et insights' : (_isEs ? 'Charlas y debates' : 'Talk e approfondimenti')),
        'pop' => _isEn ? 'Pop' : (_isFr ? 'Pop' : (_isEs ? 'Pop' : 'Pop')),
        'rock' => _isEn ? 'Rock' : (_isFr ? 'Rock' : (_isEs ? 'Rock' : 'Rock')),
        'classical' => _isEn ? 'Classical' : (_isFr ? 'Classique' : (_isEs ? 'Clásica' : 'Classica')),
        'jazz' => _isEn ? 'Jazz' : (_isFr ? 'Jazz' : (_isEs ? 'Jazz' : 'Jazz')),
        'dance' => _isEn ? 'Dance' : (_isFr ? 'Dance' : (_isEs ? 'Dance' : 'Dance')),
        'blues' => _isEn ? 'Blues' : (_isFr ? 'Blues' : (_isEs ? 'Blues' : 'Blues')),
        'country' => _isEn ? 'Country' : (_isFr ? 'Country' : (_isEs ? 'Country' : 'Country')),
        'hiphop' => _isEn ? 'Hip hop' : (_isFr ? 'Hip hop' : (_isEs ? 'Hip hop' : 'Hip hop')),
        'electronic' => _isEn ? 'Electronic' : (_isFr ? 'Électronique' : (_isEs ? 'Electrónica' : 'Elettronica')),
        'latin' => _isEn ? 'Latin' : (_isFr ? 'Latine' : (_isEs ? 'Latina' : 'Latina')),
        'reggae' => _isEn ? 'Reggae' : (_isFr ? 'Reggae' : (_isEs ? 'Reggae' : 'Reggae')),
        'metal' => _isEn ? 'Metal' : (_isFr ? 'Metal' : (_isEs ? 'Metal' : 'Metal')),
        'folk' => _isEn ? 'Folk' : (_isFr ? 'Folk' : (_isEs ? 'Folk' : 'Folk')),
        'religion' => _isEn ? 'Religion' : (_isFr ? 'Religion' : (_isEs ? 'Religión' : 'Religione')),
        'local' => _isEn ? 'Local' : (_isFr ? 'Locale' : (_isEs ? 'Local' : 'Locale')),
        'culture' => _isEn ? 'Culture' : (_isFr ? 'Culture' : (_isEs ? 'Cultura' : 'Cultura')),
        'oldies' => _isEn ? '70s / 80s / 90s' : (_isFr ? 'Années 70 / 80 / 90' : (_isEs ? 'Años 70 / 80 / 90' : 'Anni 70 / 80 / 90')),
        'kids' => _isEn ? 'Kids' : (_isFr ? 'Enfants' : (_isEs ? 'Infantil' : 'Bambini')),
        'ambient' => _isEn ? 'Ambient' : (_isFr ? 'Ambient' : (_isEs ? 'Ambient' : 'Ambient')),
        _ => value,
      };

  String radioCommunityLanguageLabel(String value) => switch (value) {
        'italian' => _isEn ? 'Italian' : (_isFr ? 'Italien' : (_isEs ? 'Italiano' : 'Italiano')),
        'english' => _isEn ? 'English' : (_isFr ? 'Anglais' : (_isEs ? 'Inglés' : 'Inglese')),
        'spanish' => _isEn ? 'Spanish' : (_isFr ? 'Espagnol' : (_isEs ? 'Español' : 'Spagnolo')),
        'french' => _isEn ? 'French' : (_isFr ? 'Français' : (_isEs ? 'Francés' : 'Francese')),
        'german' => _isEn ? 'German' : (_isFr ? 'Allemand' : (_isEs ? 'Alemán' : 'Tedesco')),
        'portuguese' => _isEn ? 'Portuguese' : (_isFr ? 'Portugais' : (_isEs ? 'Portugués' : 'Portoghese')),
        'swedish' => _isEn ? 'Swedish' : (_isFr ? 'Suédois' : (_isEs ? 'Sueco' : 'Svedese')),
        'vietnamese' => _isEn ? 'Vietnamese' : (_isFr ? 'Vietnamien' : (_isEs ? 'Vietnamita' : 'Vietnamita')),
        'czech' => _isEn ? 'Czech' : (_isFr ? 'Tchèque' : (_isEs ? 'Checo' : 'Ceco')),
        'polish' => _isEn ? 'Polish' : (_isFr ? 'Polonais' : (_isEs ? 'Polaco' : 'Polacco')),
        'serbian' => _isEn ? 'Serbian' : (_isFr ? 'Serbe' : (_isEs ? 'Serbio' : 'Serbo')),
        'ukrainian' => _isEn ? 'Ukrainian' : (_isFr ? 'Ukrainien' : (_isEs ? 'Ucraniano' : 'Ucraino')),
        'lithuanian' => _isEn ? 'Lithuanian' : (_isFr ? 'Lituanien' : (_isEs ? 'Lituano' : 'Lituano')),
        'russian' => _isEn ? 'Russian' : (_isFr ? 'Russe' : (_isEs ? 'Ruso' : 'Russo')),
        'chinese' => _isEn ? 'Chinese' : (_isFr ? 'Chinois' : (_isEs ? 'Chino' : 'Cinese')),
        'hindi' => _isEn ? 'Hindi' : (_isFr ? 'Hindi' : (_isEs ? 'Hindi' : 'Hindi')),
        _ => value,
      };
}
