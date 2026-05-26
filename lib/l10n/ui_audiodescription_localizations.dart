import 'app_localizations.dart';

extension UiAudiodescriptionLocalizations on AppLocalizations {
  bool get _isEn => locale.languageCode == 'en';
  bool get _isFr => locale.languageCode == 'fr';

  String get audiodescriptionTitle => _isEn ? 'Audio Descriptions' : (_isFr ? 'Audiodescriptions Rai' : 'Audiodescrizioni Rai');
  String get audiodescriptionRecent => _isEn ? 'Recent' : (_isFr ? 'Récents' : 'Recenti');
  String get audiodescriptionAll => _isEn ? 'All Audio Descriptions' : (_isFr ? 'Toutes les audiodescriptions' : 'Tutte le audiodescrizioni');
  String get audiodescriptionFilm => _isEn ? 'Movies' : (_isFr ? 'Films' : 'Film');
  String get audiodescriptionSearch => _isEn ? 'Search...' : (_isFr ? 'Rechercher...' : 'Cerca...');
  String get audiodescriptionLoading => _isEn ? 'Loading...' : (_isFr ? 'Chargement en cours...' : 'Caricamento in corso...');
  String get audiodescriptionError => _isEn ? 'Error loading catalog' : (_isFr ? 'Erreur de chargement du catalogue' : 'Errore nel caricamento del catalogo');
  String get audiodescriptionEmpty => _isEn ? 'No items found' : (_isFr ? 'Aucun élément trouvé' : 'Nessun elemento trovato');
}
