import '../services/document_text_extractor.dart';
import 'document_unicode_normalizer.dart';

class EpubIndexRemapResult {
  final List<DocumentTableOfContentsEntry> entries;
  final int exactCount;
  final int anchoredCount;
  final int skippedCount;
  final int anchorCount;

  const EpubIndexRemapResult({
    required this.entries,
    required this.exactCount,
    required this.anchoredCount,
    required this.skippedCount,
    required this.anchorCount,
  });
}

/// Rimappa un indice EPUB calcolato sui chunk originali verso una copia di
/// testo modificata.
///
/// La regola fondamentale e' monotona: non cerchiamo mai il titolo dell'indice
/// in tutto il documento modificato. Usiamo invece chunk lunghi e univoci che
/// esistono identici in entrambe le versioni come ancore stabili. Le voci che
/// cadono tra due ancore vicine vengono proiettate soltanto dentro quel piccolo
/// intervallo. Se non c'e' abbastanza evidenza, la voce viene scartata.
EpubIndexRemapResult remapEpubIndexToEditedChunks({
  required List<DocumentTableOfContentsEntry> originalEntries,
  required List<String> originalChunks,
  required List<String> editedChunks,
}) {
  if (originalEntries.isEmpty ||
      originalChunks.isEmpty ||
      editedChunks.isEmpty) {
    return EpubIndexRemapResult(
      entries: const <DocumentTableOfContentsEntry>[],
      exactCount: 0,
      anchoredCount: 0,
      skippedCount: originalEntries.length,
      anchorCount: 0,
    );
  }

  final originalNormalized = originalChunks.map(_normalizeChunk).toList();
  final editedNormalized = editedChunks.map(_normalizeChunk).toList();

  final originalPositions = <String, List<int>>{};
  final editedPositions = <String, List<int>>{};
  for (var i = 0; i < originalNormalized.length; i++) {
    final value = originalNormalized[i];
    if (!_isUsefulAnchor(value)) continue;
    originalPositions.putIfAbsent(value, () => <int>[]).add(i);
  }
  for (var i = 0; i < editedNormalized.length; i++) {
    final value = editedNormalized[i];
    if (!_isUsefulAnchor(value)) continue;
    editedPositions.putIfAbsent(value, () => <int>[]).add(i);
  }

  final anchors = <_ChunkAnchor>[];
  for (final entry in originalPositions.entries) {
    if (entry.value.length != 1) continue;
    final editedMatches = editedPositions[entry.key];
    if (editedMatches == null || editedMatches.length != 1) continue;
    anchors.add(_ChunkAnchor(entry.value.single, editedMatches.single));
  }
  anchors.sort((a, b) => a.originalIndex.compareTo(b.originalIndex));

  // Un testo modificato deve mantenere l'ordine. Se una rara coincidenza
  // produce ancore incrociate, la scartiamo invece di contaminare la mappa.
  final monotonicAnchors = <_ChunkAnchor>[];
  var lastEdited = -1;
  for (final anchor in anchors) {
    if (anchor.editedIndex <= lastEdited) continue;
    monotonicAnchors.add(anchor);
    lastEdited = anchor.editedIndex;
  }

  final exactMap = <int, int>{
    for (final anchor in monotonicAnchors)
      anchor.originalIndex: anchor.editedIndex,
  };

  var exactCount = 0;
  var anchoredCount = 0;
  var skippedCount = 0;
  final remapped = <DocumentTableOfContentsEntry>[];

  for (final entry in originalEntries) {
    final originalIndex = entry.chunkIndex;
    if (originalIndex < 0 || originalIndex >= originalChunks.length) {
      skippedCount++;
      continue;
    }

    final exact = exactMap[originalIndex];
    int? editedIndex;
    var exactMatch = false;
    if (exact != null) {
      editedIndex = exact;
      exactMatch = true;
    } else {
      editedIndex = _remapBetweenAnchors(
        originalIndex: originalIndex,
        originalChunk: originalNormalized[originalIndex],
        editedNormalized: editedNormalized,
        anchors: monotonicAnchors,
      );
    }

    if (editedIndex == null ||
        editedIndex < 0 ||
        editedIndex >= editedChunks.length) {
      skippedCount++;
      continue;
    }

    remapped.add(
      DocumentTableOfContentsEntry(
        title: entry.title,
        chunkIndex: editedIndex,
        level: entry.level,
      ),
    );
    if (exactMatch) {
      exactCount++;
    } else {
      anchoredCount++;
    }
  }

  return EpubIndexRemapResult(
    entries: remapped,
    exactCount: exactCount,
    anchoredCount: anchoredCount,
    skippedCount: skippedCount,
    anchorCount: monotonicAnchors.length,
  );
}

int? _remapBetweenAnchors({
  required int originalIndex,
  required String originalChunk,
  required List<String> editedNormalized,
  required List<_ChunkAnchor> anchors,
}) {
  if (anchors.isEmpty) return null;

  var low = 0;
  var high = anchors.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (anchors[mid].originalIndex < originalIndex) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }

  final next = low < anchors.length ? anchors[low] : null;
  final previous = low > 0 ? anchors[low - 1] : null;

  late int estimate;
  int searchStart;
  int searchEnd;
  var allowTightAnchorFallback = false;

  if (previous != null && next != null) {
    final originalSpan = next.originalIndex - previous.originalIndex;
    final editedSpan = next.editedIndex - previous.editedIndex;
    if (originalSpan <= 0 || editedSpan < 0) return null;

    // Non interpoliamo attraverso grandi regioni prive di ancore: se il testo
    // e' stato riscritto pesantemente, e' piu' sicuro nascondere quella voce.
    if (originalSpan > 48) return null;

    final relative = originalIndex - previous.originalIndex;
    estimate = previous.editedIndex +
        ((relative * editedSpan) / originalSpan).round();
    allowTightAnchorFallback = originalSpan <= 6 && editedSpan >= originalSpan;
    searchStart = (previous.editedIndex + 1).clamp(0, editedNormalized.length - 1).toInt();
    searchEnd = (next.editedIndex - 1).clamp(0, editedNormalized.length - 1).toInt();
    if (searchStart > searchEnd) {
      searchStart = estimate.clamp(0, editedNormalized.length - 1).toInt();
      searchEnd = searchStart;
    }
  } else if (previous != null) {
    final distance = originalIndex - previous.originalIndex;
    if (distance > 8) return null;
    estimate = previous.editedIndex + distance;
    searchStart = previous.editedIndex.clamp(0, editedNormalized.length - 1).toInt();
    searchEnd = (estimate + 3).clamp(0, editedNormalized.length - 1).toInt();
  } else if (next != null) {
    final distance = next.originalIndex - originalIndex;
    if (distance > 8) return null;
    estimate = next.editedIndex - distance;
    searchStart = (estimate - 3).clamp(0, editedNormalized.length - 1).toInt();
    searchEnd = next.editedIndex.clamp(0, editedNormalized.length - 1).toInt();
  } else {
    return null;
  }

  estimate = estimate.clamp(0, editedNormalized.length - 1).toInt();

  // Se il chunk originale e' stato semplicemente spezzato o modificato poco,
  // scegliamo il frammento piu' simile solo nel piccolo intervallo delimitato
  // dalle ancore. Non facciamo mai una ricerca globale per titolo/testo.
  var bestIndex = estimate;
  var bestScore = _chunkSimilarity(originalChunk, editedNormalized[estimate]);
  for (var i = searchStart; i <= searchEnd; i++) {
    final score = _chunkSimilarity(originalChunk, editedNormalized[i]);
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }

  if (bestScore >= 0.30 || allowTightAnchorFallback) return bestIndex;
  return null;
}

bool _isUsefulAnchor(String value) {
  if (value.length < 40) return false;
  final words = value.split(' ');
  return words.length >= 6;
}

String _normalizeChunk(String value) {
  return normalizeDocumentUnicode(value)
      .toLowerCase()
      .replaceAll(RegExp(r'[\u2018\u2019\u201c\u201d]'), "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

double _chunkSimilarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 1;
  if (a.contains(b) || b.contains(a)) {
    final shorter = a.length < b.length ? a.length : b.length;
    final longer = a.length > b.length ? a.length : b.length;
    return shorter / longer;
  }

  final aWords = a.split(' ').where((word) => word.length >= 3).toSet();
  final bWords = b.split(' ').where((word) => word.length >= 3).toSet();
  if (aWords.isEmpty || bWords.isEmpty) return 0;
  var intersection = 0;
  for (final word in aWords) {
    if (bWords.contains(word)) intersection++;
  }
  return intersection / aWords.length;
}

class _ChunkAnchor {
  final int originalIndex;
  final int editedIndex;

  const _ChunkAnchor(this.originalIndex, this.editedIndex);
}
