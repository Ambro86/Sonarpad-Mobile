import 'app_localizations.dart';

extension UiRadioLocalizations on AppLocalizations {
  bool get _isEn => localeName == 'en';
  bool get _isFr => localeName == 'fr';
  bool get _isEs => localeName == 'es';

  String radioLanguageLabel(String code) => switch (code) {
        'it' => _isEn
            ? 'Italian'
            : (_isFr ? 'Italien' : (_isEs ? 'Italiano' : 'Italiano')),
        'en' => _isEn
            ? 'English'
            : (_isFr ? 'Anglais' : (_isEs ? 'Inglés' : 'English')),
        'de' => _isEn
            ? 'German'
            : (_isFr ? 'Allemand' : (_isEs ? 'Alemán' : 'Tedesco')),
        'country:ch' => _isEn
            ? 'Switzerland'
            : (_isFr ? 'Suisse' : (_isEs ? 'Suiza' : 'Svizzera')),
        'es' => _isEn
            ? 'Spanish'
            : (_isFr ? 'Espagnol' : (_isEs ? 'Español' : 'Spagnolo')),
        'pt' => _isEn
            ? 'Portuguese'
            : (_isFr ? 'Portugais' : (_isEs ? 'Portugués' : 'Portoghese')),
        'sv' => _isEn
            ? 'Swedish'
            : (_isFr ? 'Suédois' : (_isEs ? 'Sueco' : 'Svedese')),
        'vi' => _isEn
            ? 'Vietnamese'
            : (_isFr ? 'Vietnamien' : (_isEs ? 'Vietnamita' : 'Vietnamita')),
        'cs' =>
          _isEn ? 'Czech' : (_isFr ? 'Tchèque' : (_isEs ? 'Checo' : 'Ceco')),
        'pl' => _isEn
            ? 'Polish'
            : (_isFr ? 'Polonais' : (_isEs ? 'Polaco' : 'Polacco')),
        'fr' => _isEn
            ? 'French'
            : (_isFr ? 'Français' : (_isEs ? 'Francés' : 'Français')),
        'sr' =>
          _isEn ? 'Serbian' : (_isFr ? 'Serbe' : (_isEs ? 'Serbio' : 'Serbo')),
        'uk' => _isEn
            ? 'Ukrainian'
            : (_isFr ? 'Ukrainien' : (_isEs ? 'Ucraniano' : 'Ucraino')),
        'hi' =>
          _isEn ? 'Hindi' : (_isFr ? 'Hindi' : (_isEs ? 'Hindi' : 'Hindi')),
        'lt' => _isEn
            ? 'Lithuanian'
            : (_isFr ? 'Lituanien' : (_isEs ? 'Lituano' : 'Lituano')),
        'ru' =>
          _isEn ? 'Russian' : (_isFr ? 'Russe' : (_isEs ? 'Ruso' : 'Russo')),
        'zh' => _isEn
            ? 'Chinese'
            : (_isFr ? 'Chinois' : (_isEs ? 'Chino' : 'Cinese')),
        _ => code,
      };

  String radioGenreLabel(String value) => switch (value) {
        'all' => _isEn
            ? 'All genres'
            : (_isFr
                ? 'Tous les genres'
                : (_isEs ? 'Todos los géneros' : 'Tutti i generi')),
        'news' => _isEn
            ? 'News'
            : (_isFr ? 'Actualités' : (_isEs ? 'Noticias' : 'Notizie')),
        'music' =>
          _isEn ? 'Music' : (_isFr ? 'Musique' : (_isEs ? 'Música' : 'Musica')),
        'sport' =>
          _isEn ? 'Sport' : (_isFr ? 'Sport' : (_isEs ? 'Deporte' : 'Sport')),
        'talk' => _isEn
            ? 'Talk and analysis'
            : (_isFr
                ? 'Débats et analyses'
                : (_isEs ? 'Charlas y análisis' : 'Talk e approfondimenti')),
        'pop' => _isEn ? 'Pop' : (_isFr ? 'Pop' : (_isEs ? 'Pop' : 'Pop')),
        'rock' => _isEn ? 'Rock' : (_isFr ? 'Rock' : (_isEs ? 'Rock' : 'Rock')),
        'classical' => _isEn
            ? 'Classical'
            : (_isFr ? 'Classique' : (_isEs ? 'Clásica' : 'Classica')),
        'jazz' => _isEn ? 'Jazz' : (_isFr ? 'Jazz' : (_isEs ? 'Jazz' : 'Jazz')),
        'dance' =>
          _isEn ? 'Dance' : (_isFr ? 'Dance' : (_isEs ? 'Dance' : 'Dance')),
        'blues' =>
          _isEn ? 'Blues' : (_isFr ? 'Blues' : (_isEs ? 'Blues' : 'Blues')),
        'country' => _isEn
            ? 'Country'
            : (_isFr ? 'Country' : (_isEs ? 'Country' : 'Country')),
        'hiphop' => _isEn
            ? 'Hip hop'
            : (_isFr ? 'Hip hop' : (_isEs ? 'Hip hop' : 'Hip hop')),
        'electronic' => _isEn
            ? 'Electronic'
            : (_isFr
                ? 'Électronique'
                : (_isEs ? 'Electrónica' : 'Elettronica')),
        'latin' =>
          _isEn ? 'Latin' : (_isFr ? 'Latine' : (_isEs ? 'Latina' : 'Latina')),
        'reggae' =>
          _isEn ? 'Reggae' : (_isFr ? 'Reggae' : (_isEs ? 'Reggae' : 'Reggae')),
        'metal' =>
          _isEn ? 'Metal' : (_isFr ? 'Metal' : (_isEs ? 'Metal' : 'Metal')),
        'folk' => _isEn ? 'Folk' : (_isFr ? 'Folk' : (_isEs ? 'Folk' : 'Folk')),
        'religion' => _isEn
            ? 'Religion'
            : (_isFr ? 'Religion' : (_isEs ? 'Religión' : 'Religione')),
        'local' =>
          _isEn ? 'Local' : (_isFr ? 'Locale' : (_isEs ? 'Local' : 'Locale')),
        'culture' => _isEn
            ? 'Culture'
            : (_isFr ? 'Culture' : (_isEs ? 'Cultura' : 'Cultura')),
        'oldies' => _isEn
            ? '70s / 80s / 90s'
            : (_isFr
                ? 'Années 70 / 80 / 90'
                : (_isEs ? 'Años 70 / 80 / 90' : 'Anni 70 / 80 / 90')),
        'kids' => _isEn
            ? 'Kids'
            : (_isFr ? 'Enfants' : (_isEs ? 'Infantil' : 'Bambini')),
        'ambient' => _isEn
            ? 'Ambient'
            : (_isFr ? 'Ambient' : (_isEs ? 'Ambient' : 'Ambient')),
        _ => value,
      };

  String radioCommunityLanguageLabel(String value) => switch (value) {
        'italian' => _isEn
            ? 'Italian'
            : (_isFr ? 'Italien' : (_isEs ? 'Italiano' : 'Italiano')),
        'english' => _isEn
            ? 'English'
            : (_isFr ? 'Anglais' : (_isEs ? 'Inglés' : 'Inglese')),
        'spanish' => _isEn
            ? 'Spanish'
            : (_isFr ? 'Espagnol' : (_isEs ? 'Español' : 'Spagnolo')),
        'french' => _isEn
            ? 'French'
            : (_isFr ? 'Français' : (_isEs ? 'Francés' : 'Francese')),
        'german' => _isEn
            ? 'German'
            : (_isFr ? 'Allemand' : (_isEs ? 'Alemán' : 'Tedesco')),
        'portuguese' => _isEn
            ? 'Portuguese'
            : (_isFr ? 'Portugais' : (_isEs ? 'Portugués' : 'Portoghese')),
        'swedish' => _isEn
            ? 'Swedish'
            : (_isFr ? 'Suédois' : (_isEs ? 'Sueco' : 'Svedese')),
        'vietnamese' => _isEn
            ? 'Vietnamese'
            : (_isFr ? 'Vietnamien' : (_isEs ? 'Vietnamita' : 'Vietnamita')),
        'czech' =>
          _isEn ? 'Czech' : (_isFr ? 'Tchèque' : (_isEs ? 'Checo' : 'Ceco')),
        'polish' => _isEn
            ? 'Polish'
            : (_isFr ? 'Polonais' : (_isEs ? 'Polaco' : 'Polacco')),
        'serbian' =>
          _isEn ? 'Serbian' : (_isFr ? 'Serbe' : (_isEs ? 'Serbio' : 'Serbo')),
        'ukrainian' => _isEn
            ? 'Ukrainian'
            : (_isFr ? 'Ukrainien' : (_isEs ? 'Ucraniano' : 'Ucraino')),
        'lithuanian' => _isEn
            ? 'Lithuanian'
            : (_isFr ? 'Lituanien' : (_isEs ? 'Lituano' : 'Lituano')),
        'russian' =>
          _isEn ? 'Russian' : (_isFr ? 'Russe' : (_isEs ? 'Ruso' : 'Russo')),
        'chinese' => _isEn
            ? 'Chinese'
            : (_isFr ? 'Chinois' : (_isEs ? 'Chino' : 'Cinese')),
        'hindi' =>
          _isEn ? 'Hindi' : (_isFr ? 'Hindi' : (_isEs ? 'Hindi' : 'Hindi')),
        _ => value,
      };
}
