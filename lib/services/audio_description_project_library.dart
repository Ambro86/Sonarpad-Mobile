import 'dart:convert';
import 'dart:io';

import '../models/document_item.dart';
import 'document_library_service.dart';

Future<List<DocumentItem>> loadAudioDescriptionProjects(
  DocumentLibraryService library,
) async {
  await library.load();
  final projects = <DocumentItem>[];
  for (final document in library.documents) {
    if (document.isFolder || document.extension.toLowerCase() != 'json') {
      continue;
    }
    final path = await library.resolveFilePath(document);
    final file = File(path);
    if (!await file.exists()) continue;
    // Do not inspect protected contents before the user supplies the password.
    if (document.isPasswordProtected) {
      projects.add(document);
      continue;
    }
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is Map &&
          (data['format'] == 'sonarpad-audio-description-project' ||
              data['schema'] == 'sonarpad-audio-description-project')) {
        projects.add(document);
      }
    } on FormatException {
      continue;
    } on FileSystemException {
      continue;
    }
  }
  projects.sort((a, b) => b.addedAt.compareTo(a.addedAt));
  return projects;
}
