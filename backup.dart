import 'dart:io';

void main() {
  File('lib/screens/documents_screen.dart').copySync('lib/screens/documents_screen.dart.bac');
  File('lib/services/raiplay_service.dart').copySync('lib/services/raiplay_service.dart.bac');
}
