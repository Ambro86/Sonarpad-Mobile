import 'dart:async';

import 'package:archive/archive.dart';
import 'dart:convert' as convert;
import 'package:collection/collection.dart' show IterableExtension;
import 'package:xml/xml.dart' as xml;

class RootFilePathReader {
  static const containerPath = 'META-INF/container.xml';

  static ArchiveFile? findContainerFile(Archive archive) {
    final exact = archive.findFile(containerPath);
    if (exact != null) return exact;
    return archive.files
        .where((file) =>
            file.isFile && file.name.toLowerCase() == 'meta-inf/container.xml')
        .singleOrNull;
  }

  static Future<String?> getRootFilePath(Archive epubArchive) async {
    final containerFileEntry = findContainerFile(epubArchive);
    if (containerFileEntry == null) {
      throw Exception(
          'EPUB parsing error: $containerPath file not found in archive.');
    }

    var containerDocument =
        xml.XmlDocument.parse(convert.utf8.decode(containerFileEntry.content));
    var packageElement = containerDocument
        .findAllElements('container',
            namespace: 'urn:oasis:names:tc:opendocument:xmlns:container')
        .firstWhereOrNull((xml.XmlElement? elem) => elem != null);
    if (packageElement == null) {
      throw Exception('EPUB parsing error: Invalid epub container');
    }

    var rootFileElement = packageElement.descendants.firstWhereOrNull(
        (xml.XmlNode testElem) =>
            (testElem is xml.XmlElement) &&
            'rootfile' == testElem.name.local) as xml.XmlElement;

    return rootFileElement.getAttribute('full-path');
  }
}
