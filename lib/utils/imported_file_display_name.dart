import 'package:path/path.dart' as p;

final _legacyImportPrefix = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}_(.+)$',
);

/// Display a selected file without exposing Sonarpad's import identifiers.
/// Only the known legacy cache layout is decoded; real filenames elsewhere
/// (including names beginning with a UUID) are left unchanged.
String importedFileDisplayName(String path) {
  final name = p.basename(path);
  if (p.basename(p.dirname(path)) == 'sonarpad_cloud_import') {
    return _legacyImportPrefix.firstMatch(name)?.group(1) ?? name;
  }
  return name;
}
