import 'dart:io';

void main() async {
  final text = await File(r'C:\Users\ambro\Downloads\Il libro del Dio vivente.txt').readAsString();
  final chunks = splitTextForStreaming(text);
  // print('Total chunks: ${chunks.length}');
  for (var i = 0; i < chunks.length; i++) {
    // print('Chunk $i length: ${chunks[i].length}');
  }
}

List<String> splitTextForStreaming(String text, {int maxChunkChars = 650}) {
  final chunks = <String>[];
  final normalizedText = text.replaceAll('\r\n', '\n');
  final paragraphs = normalizedText.split(RegExp(r'\n{2,}'));

  for (final p in paragraphs) {
    final cleaned = p
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('...', '.')
        .trim();

    if (cleaned.isEmpty) continue;

    final sentenceMatches =
        RegExp(r'[^.!??!?]+[.!??!?]?').allMatches(cleaned);
    final sentences = sentenceMatches
        .map((m) => m.group(0)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final buffer = StringBuffer();

    void flush() {
      final value = buffer.toString().trim();
      if (value.isNotEmpty) chunks.add(value);
      buffer.clear();
    }

    for (final sentence in sentences) {
      if (sentence.length > maxChunkChars) {
        flush();
        var start = 0;
        while (start < sentence.length) {
          var end = start + maxChunkChars;
          if (end >= sentence.length) {
            chunks.add(sentence.substring(start).trim());
            break;
          }
          final cut = sentence.lastIndexOf(' ', end);
          if (cut > start + 80) end = cut;
          chunks.add(sentence.substring(start, end).trim());
          start = end;
        }
      } else {
        if (buffer.length + sentence.length > maxChunkChars) {
          flush();
        }
        buffer.write(sentence);
        buffer.write(' ');
      }
    }
    flush();
  }
  return chunks;
}
