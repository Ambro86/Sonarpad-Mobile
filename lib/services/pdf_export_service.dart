import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Builds a text PDF using an embedded font that includes Turkish letters.
/// The bundled font preserves supported Unicode text independently of the
/// app locale and does not require installed fonts or a network download.
class PdfExportService {
  PdfExportService({AssetBundle? assets}) : _assets = assets ?? rootBundle;

  static const fontAssetPath = 'assets/fonts/DejaVuSans.ttf';
  final AssetBundle _assets;

  Future<List<int>> buildPdf(String text) async {
    final fontData = await _assets.load(fontAssetPath);
    final font = PdfTrueTypeFont(
      fontData.buffer.asUint8List(
        fontData.offsetInBytes,
        fontData.lengthInBytes,
      ),
      12,
    );
    final document = PdfDocument();
    try {
      final page = document.pages.add();
      PdfTextElement(
        text: normalizePdfExportText(text),
        font: font,
      ).draw(
        page: page,
        bounds: Rect.fromLTWH(
          0,
          0,
          page.getClientSize().width,
          page.getClientSize().height,
        ),
        format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
      );
      return await document.save();
    } finally {
      document.dispose();
    }
  }
}

/// Remove invisible transport markers, without substituting letters or
/// typography with ASCII approximations or question marks.
String normalizePdfExportText(String text) => text
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll('\u200B', '')
    .replaceAll('\uFEFF', '');
