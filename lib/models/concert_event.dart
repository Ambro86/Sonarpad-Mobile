class ConcertEvent {
  final String id;
  final String name;
  final String date;
  final String time;
  final String venueName;
  final String city;
  final String url;
  
  ConcertEvent({
    required this.id,
    required this.name,
    required this.date,
    required this.time,
    required this.venueName,
    required this.city,
    required this.url,
  });

  factory ConcertEvent.fromJson(Map<String, dynamic> json) {
    final dates = json['dates']?['start'] ?? {};
    final embedded = json['_embedded'] ?? {};
    final venues = embedded['venues'] as List<dynamic>? ?? [];
    final firstVenue = venues.isNotEmpty ? venues.first : {};
    final cityObj = firstVenue['city'] ?? {};

    return ConcertEvent(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Evento Sconosciuto',
      date: dates['localDate'] ?? '',
      time: dates['localTime'] ?? '',
      venueName: firstVenue['name'] ?? 'Location sconosciuta',
      city: cityObj['name'] ?? '',
      url: json['url'] ?? '',
    );
  }
}
