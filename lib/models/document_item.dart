import 'dart:convert';

/// Rappresenta un documento aggiunto alla libreria dell'utente.
class DocumentItem {
  final String id;
  final String name;
  final String path;
  final String extension;
  final DateTime addedAt;
  final int bookmarkIndex;
  final String? editedTextPath;
  final bool isTemporary;

  const DocumentItem({
    required this.id,
    required this.name,
    required this.path,
    required this.extension,
    required this.addedAt,
    this.bookmarkIndex = 0,
    this.editedTextPath,
    this.isTemporary = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'extension': extension,
        'addedAt': addedAt.toIso8601String(),
        'bookmarkIndex': bookmarkIndex,
        if (editedTextPath != null) 'editedTextPath': editedTextPath,
        'isTemporary': isTemporary,
      };

  factory DocumentItem.fromJson(Map<String, dynamic> json) => DocumentItem(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        extension: json['extension'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
        bookmarkIndex: json['bookmarkIndex'] as int? ?? 0,
        editedTextPath: json['editedTextPath'] as String?,
        isTemporary: json['isTemporary'] as bool? ?? false,
      );

  static DocumentItem? tryFromJson(Map<String, dynamic> json) {
    try {
      return DocumentItem.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static List<DocumentItem> listFromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(tryFromJson)
        .whereType<DocumentItem>()
        .toList();
  }

  static String listToJsonString(List<DocumentItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());
}
