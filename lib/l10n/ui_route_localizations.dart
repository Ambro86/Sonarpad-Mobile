import 'app_localizations.dart';

extension UiRouteLocalizations on AppLocalizations {
  bool get _isEn => locale.languageCode == 'en';
  bool get _isFr => locale.languageCode == 'fr';
  bool get _isEs => locale.languageCode == 'es';

  String get routeTitle => _isEn
      ? 'Travel Routes'
      : (_isFr
          ? 'Itinéraires routiers'
          : (_isEs ? 'Rutas callejeras' : 'Percorsi Stradali'));
  String get routeFrom =>
      _isEn ? 'From' : (_isFr ? 'De' : (_isEs ? 'De' : 'Partenza'));
  String get routeTo => _isEn ? 'To' : (_isFr ? 'À' : (_isEs ? 'A' : 'Destinazione'));
  String get routeCountry =>
      _isEn ? 'Country' : (_isFr ? 'Pays' : (_isEs ? 'País' : 'Paese'));
  String get routeVehicle =>
      _isEn ? 'Vehicle' : (_isFr ? 'Véhicule' : (_isEs ? 'Vehículo' : 'Mezzo'));
  String get routeType =>
      _isEn ? 'Type' : (_isFr ? 'Type' : (_isEs ? 'Tipo' : 'Tipo'));
  String get routeIncludeMunicipalities => _isEn
      ? 'Include towns crossed'
      : (_isFr
          ? 'Inclure les communes traversées'
          : (_isEs
              ? 'Incluir los municipios atravesados'
              : 'Includi comuni attraversati'));

  String get routeWalking => _isEn
      ? 'Walking'
      : (_isFr ? 'À pied' : (_isEs ? 'Caminando' : 'A piedi'));
  String get routeCycling => _isEn
      ? 'Cycling'
      : (_isFr ? 'À vélo' : (_isEs ? 'En bicicleta' : 'In bicicletta'));
  String get routeDriving => _isEn
      ? 'Driving'
      : (_isFr ? 'En voiture' : (_isEs ? 'En coche' : 'In auto'));
  String get routeWheelchair => _isEn
      ? 'Wheelchair'
      : (_isFr
          ? 'En fauteuil roulant'
          : (_isEs ? 'En silla de ruedas' : 'In sedia a rotelle'));

  String get routeFastest => _isEn
      ? 'Fastest'
      : (_isFr ? 'Le plus rapide' : (_isEs ? 'Más rápido' : 'Più veloce'));
  String get routeShortest => _isEn
      ? 'Shortest'
      : (_isFr ? 'Le plus court' : (_isEs ? 'Más corto' : 'Più corto'));

  String get routeCalculate => _isEn
      ? 'Calculate Route'
      : (_isFr
          ? 'Calculer l\'itinéraire'
          : (_isEs ? 'Calcular ruta' : 'Calcola percorso'));
  String get routeCalculating => _isEn
      ? 'Calculating...'
      : (_isFr
          ? 'Calcul en cours...'
          : (_isEs ? 'Calculando...' : 'Calcolo in corso...'));
  String get routeChooseFrom => _isEn
      ? 'Choose starting point'
      : (_isFr
          ? 'Choisir le départ'
          : (_isEs ? 'Elige la salida' : 'Scegli punto di partenza'));
  String get routeChooseTo => _isEn
      ? 'Choose destination'
      : (_isFr
          ? 'Choisir la destination'
          : (_isEs ? 'Elige el destino' : 'Scegli destinazione'));
  String get routeCancel =>
      _isEn ? 'Cancel' : (_isFr ? 'Annuler' : (_isEs ? 'Cancelar' : 'Annulla'));
  String get routeErrorMissingFields => _isEn
      ? 'Please enter departure and arrival'
      : (_isFr
          ? 'Veuillez saisir le départ et l\'arrivée'
          : (_isEs
              ? 'Por favor introduce salida y llegada'
              : 'Inserisci partenza e arrivo'));
  String get routeErrorFromNotFound => _isEn
      ? 'No result found for the starting address'
      : (_isFr
          ? 'Aucun résultat trouvé pour l\'adresse de départ'
          : (_isEs
              ? 'No se encontró ningún resultado para la dirección de salida'
              : 'Nessun risultato trovato per l\'indirizzo di partenza'));
  String get routeErrorToNotFound => _isEn
      ? 'No result found for the destination address'
      : (_isFr
          ? 'Aucun résultat trouvé pour l\'adresse de destination'
          : (_isEs
              ? 'No se encontró ningún resultado para la dirección de llegada'
              : 'Nessun risultato trovato per l\'indirizzo di arrivo'));

  String get routeResultsTitle => _isEn
      ? 'Available Routes'
      : (_isFr
          ? 'Itinéraires disponibles'
          : (_isEs ? 'Rutas disponibles' : 'Percorsi disponibili'));
  String get routeDistance => _isEn
      ? 'Distance'
      : (_isFr ? 'Distance' : (_isEs ? 'Distancia' : 'Distanza'));
  String get routeDuration =>
      _isEn ? 'Duration' : (_isFr ? 'Durée' : (_isEs ? 'Duración' : 'Durata'));
  String get routeNavigation => _isEn
      ? 'Navigation Details'
      : (_isFr
          ? 'Détails de la navigation'
          : (_isEs ? 'Detalles de navegación' : 'Dettagli Navigazione'));
  String get routeStartMunicipality => _isEn
      ? 'Starting municipality'
      : (_isFr
          ? 'Commune de départ'
          : (_isEs ? 'Municipio de salida' : 'Comune di partenza'));
  String get routeEnterMunicipality => _isEn
      ? 'You enter the municipality of'
      : (_isFr
          ? 'Vous entrez dans la commune de'
          : (_isEs ? 'Entras en el municipio de' : 'Entri nel comune di'));

  String routeError(Object error) => _isEn
      ? 'Error: $error'
      : (_isFr
          ? 'Erreur : $error'
          : (_isEs ? 'Error: $error' : 'Errore: $error'));

  String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }
}
