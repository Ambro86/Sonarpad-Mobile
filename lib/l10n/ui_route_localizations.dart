import 'app_localizations.dart';

extension UiRouteLocalizations on AppLocalizations {
  String get routeTitle => locale.languageCode == 'en' ? 'Street Routes' : 'Percorsi Stradali';
  String get routeFrom => locale.languageCode == 'en' ? 'From' : 'Da';
  String get routeTo => locale.languageCode == 'en' ? 'To' : 'A';
  String get routeCountry => locale.languageCode == 'en' ? 'Country' : 'Paese';
  String get routeVehicle => locale.languageCode == 'en' ? 'Vehicle' : 'Mezzo';
  String get routeType => locale.languageCode == 'en' ? 'Type' : 'Tipo';
  
  String get routeWalking => locale.languageCode == 'en' ? 'Walking' : 'A piedi';
  String get routeCycling => locale.languageCode == 'en' ? 'Cycling' : 'In bicicletta';
  String get routeDriving => locale.languageCode == 'en' ? 'Driving' : 'In auto';
  String get routeWheelchair => locale.languageCode == 'en' ? 'Wheelchair' : 'In sedia a rotelle';
  
  String get routeFastest => locale.languageCode == 'en' ? 'Fastest' : 'Più veloce';
  String get routeShortest => locale.languageCode == 'en' ? 'Shortest' : 'Più corto';

  String get routeCalculate => locale.languageCode == 'en' ? 'Calculate Route' : 'Calcola percorso';
  String get routeCalculating => locale.languageCode == 'en' ? 'Calculating...' : 'Calcolo in corso...';
  String get routeErrorMissingFields => locale.languageCode == 'en' ? 'Please enter departure and arrival' : 'Inserisci partenza e arrivo';
  
  String get routeResultsTitle => locale.languageCode == 'en' ? 'Available Routes' : 'Percorsi disponibili';
  String get routeDistance => locale.languageCode == 'en' ? 'Distance' : 'Distanza';
  String get routeDuration => locale.languageCode == 'en' ? 'Duration' : 'Durata';
  String get routeNavigation => locale.languageCode == 'en' ? 'Navigation Details' : 'Dettagli Navigazione';
  
  String routeError(Object error) => locale.languageCode == 'en' ? 'Error: $error' : 'Errore: $error';
  
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
