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
  final bool isFolder;
  final String? parentId;

  const DocumentItem({
    required this.id,
    required this.name,
    required this.path,
    required this.extension,
    required this.addedAt,
    this.bookmarkIndex = 0,
    this.editedTextPath,
    this.isTemporary = false,
    this.isFolder = false,
    this.parentId,
  });

  String get displayName {
    final suffix = '.${extension.toLowerCase()}';
    if (suffix.length <= 1 || !name.toLowerCase().endsWith(suffix)) {
      return name;
    }
    return name.substring(0, name.length - suffix.length);
  }

  DocumentItem copyWith({
    String? parentId,
    bool clearParentId = false,
  }) {
    return DocumentItem(
      id: id,
      name: name,
      path: path,
      extension: extension,
      addedAt: addedAt,
      bookmarkIndex: bookmarkIndex,
      editedTextPath: editedTextPath,
      isTemporary: isTemporary,
      isFolder: isFolder,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'extension': extension,
        'addedAt': addedAt.toIso8601String(),
        'bookmarkIndex': bookmarkIndex,
        if (editedTextPath != null) 'editedTextPath': editedTextPath,
        'isTemporary': isTemporary,
        'isFolder': isFolder,
        if (parentId != null) 'parentId': parentId,
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
        isFolder: json['isFolder'] as bool? ?? false,
        parentId: json['parentId'] as String?,
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
