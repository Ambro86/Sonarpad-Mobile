import 'dart:io';

void main() {
  File('lib/screens/documents_screen.dart').copySync('lib/screens/documents_screen.dart.bac');
  File('lib/screens/document_reader_screen.dart').copySync('lib/screens/document_reader_screen.dart.bac');
}
