part of 'document_text_extractor.dart';

// Word 97–2003 stores its text and piece table in separate CFB streams.
String _readBinaryWord(Uint8List bytes) {
  final file = _WordCompoundFile(bytes);
  final word = file.stream('WordDocument');
  final fib = ByteData.sublistView(word);
  int u16(int offset) => fib.getUint16(offset, Endian.little);
  int u32(int offset) => fib.getUint32(offset, Endian.little);
  if (u16(0) != 0xa5ec || u16(2) < 0xc1 || (u16(10) & 0x8100) != 0) {
    throw const FormatException('Unsupported Word document');
  }
  final table = file.stream((u16(10) & 0x0200) != 0 ? '1Table' : '0Table');
  final start = u32(0x1a2);
  final clx = ByteData.sublistView(table, start, start + u32(0x1a6));
  var at = 0;
  while (clx.getUint8(at) == 1) {
    at += 3 + clx.getUint16(at + 1, Endian.little);
  }
  final size = clx.getUint32(at + 1, Endian.little);
  if (clx.getUint8(at) != 2 ||
      size < 4 ||
      (size - 4) % 12 != 0 ||
      at + 5 + size != clx.lengthInBytes) {
    throw const FormatException('Invalid Word piece table');
  }
  final count = (size - 4) ~/ 12;
  final cps = at + 5;
  final descriptors = cps + (count + 1) * 4;
  final mainLength = u32(0x4c);
  if (clx.getUint32(cps, Endian.little) != 0 ||
      mainLength > word.length ||
      clx.getUint32(cps + count * 4, Endian.little) < mainLength) {
    throw const FormatException('Invalid Word text length');
  }
  final result = StringBuffer();
  for (var i = 0; i < count; i++) {
    final first = clx.getUint32(cps + i * 4, Endian.little);
    if (first >= mainLength) break;
    final next = clx.getUint32(cps + (i + 1) * 4, Endian.little);
    if (next < first) throw const FormatException('Invalid Word piece length');
    final length = (next > mainLength ? mainLength : next) - first;
    final fc = clx.getUint32(descriptors + i * 8 + 2, Endian.little);
    final offset = fc & 0x3fffffff;
    if ((fc & 0x40000000) != 0) {
      final data = Uint8List.sublistView(
        word,
        offset ~/ 2,
        offset ~/ 2 + length,
      );
      result.write(DocumentTextExtractor._decodeSingleByte(data, _windows1252));
    } else {
      for (var j = 0; j < length; j++) {
        result.writeCharCode(u16(offset + j * 2));
      }
    }
  }
  return result.toString().replaceAll(RegExp(r'[\r\x07\x0b]'), '\n');
}

class _WordCompoundFile {
  static const end = 0xfffffffe;
  final Uint8List bytes;
  late final int sectorSize;
  final fat = <int>[];
  late final ByteData directory;
  late final miniFat = _integers(
    _chain(_header(60), fat, _sector, _header(64) * sectorSize),
  );
  late final miniStream = _entryData(0, mini: false);

  _WordCompoundFile(this.bytes) {
    final header = ByteData.sublistView(bytes);
    final shift = header.getUint16(30, Endian.little);
    if ((shift != 9 && shift != 12) ||
        header.getUint16(32, Endian.little) != 6 ||
        header.getUint16(28, Endian.little) != 0xfffe ||
        _header(56) != 4096) {
      throw const FormatException('Invalid Word compound file header');
    }
    sectorSize = 1 << shift;
    final seen = <int>{};
    void addFat(int sector) {
      if (sector == 0xffffffff) return;
      if (!seen.add(sector)) throw const FormatException('Repeated FAT sector');
      fat.addAll(_integers(_sector(sector)));
    }

    for (var i = 0; i < 109; i++) {
      addFat(_header(76 + i * 4));
    }
    var next = _header(68);
    for (var i = 0; i < _header(72); i++) {
      if (!seen.add(next)) throw const FormatException('Repeated DIFAT sector');
      final entries = _integers(_sector(next));
      for (var j = 0; j < entries.length - 1; j++) {
        addFat(entries[j]);
      }
      next = entries.last;
    }
    directory = ByteData.sublistView(_chain(_header(48), fat, _sector, null));
  }

  int _header(int offset) =>
      ByteData.sublistView(bytes).getUint32(offset, Endian.little);
  Uint8List _sector(int index) => Uint8List.sublistView(
    bytes,
    (index + 1) * sectorSize,
    (index + 2) * sectorSize,
  );
  List<int> _integers(Uint8List data) {
    final view = ByteData.sublistView(data);
    return List.generate(
      data.length ~/ 4,
      (i) => view.getUint32(i * 4, Endian.little),
    );
  }

  Uint8List _chain(
    int id,
    List<int> links,
    Uint8List Function(int) read,
    int? length,
  ) {
    if (length != null && length > bytes.length) {
      throw const FormatException('Invalid stream size');
    }
    final seen = <int>{};
    final result = BytesBuilder(copy: false);
    while (id != end && (length == null || result.length < length)) {
      if (id >= links.length || !seen.add(id)) {
        throw const FormatException('Invalid sector chain');
      }
      result.add(read(id));
      id = links[id];
    }
    final data = result.takeBytes();
    return length == null ? data : Uint8List.sublistView(data, 0, length);
  }

  Uint8List _entryData(int at, {required bool mini}) {
    final size = directory.getUint32(at + 120, Endian.little);
    final start = directory.getUint32(at + 116, Endian.little);
    if (mini && size < 4096) {
      return _chain(
        start,
        miniFat,
        (id) => Uint8List.sublistView(miniStream, id * 64, (id + 1) * 64),
        size,
      );
    }
    return _chain(start, fat, _sector, size);
  }

  Uint8List stream(String name) {
    // Only inspect the root storage's child tree, not embedded documents.
    final pending = [directory.getUint32(76, Endian.little)];
    final seen = <int>{};
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (id == 0xffffffff) continue;
      if (!seen.add(id)) throw const FormatException('Invalid directory tree');
      final at = id * 128;
      final size = directory.getUint16(at + 64, Endian.little);
      if (directory.getUint8(at + 66) == 2 && size == (name.length + 1) * 2) {
        final text = String.fromCharCodes(
          List.generate(
            name.length,
            (i) => directory.getUint16(at + 2 * i, Endian.little),
          ),
        );
        if (text == name) return _entryData(at, mini: true);
      }
      pending.add(directory.getUint32(at + 68, Endian.little));
      pending.add(directory.getUint32(at + 72, Endian.little));
    }
    throw FormatException('Missing Word stream: $name');
  }
}
