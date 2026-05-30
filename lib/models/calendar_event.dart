class CalendarEvent {
  final String id;
  final DateTime date;
  final String text;

  CalendarEvent({
    required this.id,
    required this.date,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'text': text,
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      text: json['text'] as String,
    );
  }
}
