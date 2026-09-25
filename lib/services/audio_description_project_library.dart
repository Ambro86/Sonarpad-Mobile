import 'dart:convert';
import 'dart:io';

import '../models/document_item.dart';
import 'document_library_service.dart';

Future<bool> isAudioDescriptionProjectFile(String path) async {
  try {
    final data = jsonDecode(await File(path).readAsString());
    return data is Map &&
        (data['format'] == 'sonarpad-audio-description-project' ||
            data['schema'] == 'sonarpad-audio-description-project');
  } on FormatException {
    return false;
  } on FileSystemException {
    return false;
  }
}

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
    if (await isAudioDescriptionProjectFile(path)) {
      projects.add(document);
    }
  }
  projects.sort((a, b) => b.addedAt.compareTo(a.addedAt));
  return projects;
}
