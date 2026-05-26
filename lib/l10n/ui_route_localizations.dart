import 'app_localizations.dart';

extension UiRouteLocalizations on AppLocalizations {
  bool get _isEn => locale.languageCode == 'en';
  bool get _isFr => locale.languageCode == 'fr';

  String get routeTitle => _isEn ? 'Street Routes' : (_isFr ? 'Itinéraires routiers' : 'Percorsi Stradali');
  String get routeFrom => _isEn ? 'From' : (_isFr ? 'De' : 'Da');
  String get routeTo => _isEn ? 'To' : (_isFr ? 'À' : 'A');
  String get routeCountry => _isEn ? 'Country' : (_isFr ? 'Pays' : 'Paese');
  String get routeVehicle => _isEn ? 'Vehicle' : (_isFr ? 'Véhicule' : 'Mezzo');
  String get routeType => _isEn ? 'Type' : (_isFr ? 'Type' : 'Tipo');
  
  String get routeWalking => _isEn ? 'Walking' : (_isFr ? 'À pied' : 'A piedi');
  String get routeCycling => _isEn ? 'Cycling' : (_isFr ? 'À vélo' : 'In bicicletta');
  String get routeDriving => _isEn ? 'Driving' : (_isFr ? 'En voiture' : 'In auto');
  String get routeWheelchair => _isEn ? 'Wheelchair' : (_isFr ? 'En fauteuil roulant' : 'In sedia a rotelle');
  
  String get routeFastest => _isEn ? 'Fastest' : (_isFr ? 'Le plus rapide' : 'Più veloce');
  String get routeShortest => _isEn ? 'Shortest' : (_isFr ? 'Le plus court' : 'Più corto');

  String get routeCalculate => _isEn ? 'Calculate Route' : (_isFr ? 'Calculer l\'itinéraire' : 'Calcola percorso');
  String get routeCalculating => _isEn ? 'Calculating...' : (_isFr ? 'Calcul en cours...' : 'Calcolo in corso...');
  String get routeErrorMissingFields => _isEn ? 'Please enter departure and arrival' : (_isFr ? 'Veuillez saisir le départ et l\'arrivée' : 'Inserisci partenza e arrivo');
  
  String get routeResultsTitle => _isEn ? 'Available Routes' : (_isFr ? 'Itinéraires disponibles' : 'Percorsi disponibili');
  String get routeDistance => _isEn ? 'Distance' : (_isFr ? 'Distance' : 'Distanza');
  String get routeDuration => _isEn ? 'Duration' : (_isFr ? 'Durée' : 'Durata');
  String get routeNavigation => _isEn ? 'Navigation Details' : (_isFr ? 'Détails de la navigation' : 'Dettagli Navigazione');
  
  String routeError(Object error) => _isEn ? 'Error: \$error' : (_isFr ? 'Erreur : \$error' : 'Errore: \$error');
  
  String formatDistance(double meters) {
    if (meters < 1000) return '\${meters.round()} m';
    return '\${(meters / 1000).toStringAsFixed(1)} km';
  }

  String formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '\$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '\${hours}h \${mins}m';
  }
}
