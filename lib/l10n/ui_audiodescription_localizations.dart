import 'app_localizations.dart';

extension UiAudiodescriptionLocalizations on AppLocalizations {
  String get audiodescriptionTitle => locale.languageCode == 'en' ? 'Audio Descriptions' : 'Audiodescrizioni Rai';
  String get audiodescriptionRecent => locale.languageCode == 'en' ? 'Recent' : 'Recenti';
  String get audiodescriptionAll => locale.languageCode == 'en' ? 'All Audio Descriptions' : 'Tutte le audiodescrizioni';
  String get audiodescriptionFilm => locale.languageCode == 'en' ? 'Movies' : 'Film';
  String get audiodescriptionSearch => locale.languageCode == 'en' ? 'Search...' : 'Cerca...';
  String get audiodescriptionLoading => locale.languageCode == 'en' ? 'Loading...' : 'Caricamento in corso...';
  String get audiodescriptionError => locale.languageCode == 'en' ? 'Error loading catalog' : 'Errore nel caricamento del catalogo';
  String get audiodescriptionEmpty => locale.languageCode == 'en' ? 'No items found' : 'Nessun elemento trovato';
}
