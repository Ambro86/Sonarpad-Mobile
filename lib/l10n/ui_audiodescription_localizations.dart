import 'app_localizations.dart';

extension UiAudiodescriptionLocalizations on AppLocalizations {
  bool get _isEn => locale.languageCode == 'en';
  bool get _isFr => locale.languageCode == 'fr';
  bool get _isEs => locale.languageCode == 'es';

  String get audiodescriptionTitle => _isEn ? 'Audio descriptions' : (_isFr ? 'Audiodescriptions Rai' : (_isEs ? 'Audiodescripciones' : 'Audiodescrizioni Rai'));
  String get audiodescriptionRecent => _isEn ? 'Recent' : (_isFr ? 'Récents' : (_isEs ? 'Recientes' : 'Recenti'));
  String get audiodescriptionAll => _isEn ? 'All audio descriptions' : (_isFr ? 'Toutes les audiodescriptions' : (_isEs ? 'Todas las audiodescripciones' : 'Tutte le audiodescrizioni'));
  String get audiodescriptionFilm => _isEn ? 'Movies' : (_isFr ? 'Films' : (_isEs ? 'Películas' : 'Film'));
  String get audiodescriptionSearch => _isEn ? 'Search...' : (_isFr ? 'Rechercher...' : (_isEs ? 'Buscar...' : 'Cerca...'));
  String get audiodescriptionLoading => _isEn ? 'Loading...' : (_isFr ? 'Chargement en cours...' : (_isEs ? 'Cargando...' : 'Caricamento in corso...'));
  String get audiodescriptionError => _isEn ? 'Error loading catalog' : (_isFr ? 'Erreur de chargement du catalogue' : (_isEs ? 'Error al cargar el catálogo' : 'Errore nel caricamento del catalogo'));
  String get audiodescriptionEmpty => _isEn ? 'No items found' : (_isFr ? 'Aucun élément trouvé' : (_isEs ? 'No se encontraron elementos' : 'Nessun elemento trovato'));
}
