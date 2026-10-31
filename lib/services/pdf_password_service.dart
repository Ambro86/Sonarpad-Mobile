import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Never retain the library's ArgumentError: its invalidValue is the password.
class PdfPasswordRequired implements Exception {
  const PdfPasswordRequired();

  @override
  String toString() => 'PDF password required or incorrect';
}

PdfDocument openPdfWithPassword(List<int> bytes, {String? password}) {
  try {
    return PdfDocument(inputBytes: bytes, password: password);
  } on ArgumentError catch (error) {
    if (error.name == 'password') throw const PdfPasswordRequired();
    rethrow;
  }
}

/// Save the loaded PDF itself, preserving its pages, rather than exporting text.
Future<Uint8List> pdfWithoutPassword(List<int> bytes, String password) async {
  final document = openPdfWithPassword(bytes, password: password);
  try {
    final pages = document.pages.count;
    document.security
      ..userPassword = ''
      ..ownerPassword = '';
    document.fileStructure.incrementalUpdate = false;
    final result = Uint8List.fromList(await document.save());
    final verified = openPdfWithPassword(result);
    try {
      if (verified.pages.count != pages) {
        throw StateError('pdf_page_count_mismatch');
      }
    } finally {
      verified.dispose();
    }
    return result;
  } finally {
    document.dispose();
  }
}
