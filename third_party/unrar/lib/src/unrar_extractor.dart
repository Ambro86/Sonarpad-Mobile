// ignore_for_file: constant_identifier_names

import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'unrar_exception.dart';
import 'archive_entry.dart';
import 'unrar_bindings.dart' as bindings;

/// Native signature of `UNRARCALLBACK` from dll.hpp.
typedef _UnrarCallback =
    Int Function(UnsignedInt msg, IntPtr userData, IntPtr p1, IntPtr p2);

/// High-level interface for extracting RAR archives.
///
/// The native library is bundled by the package's build hook and bound with
/// `@Native`, so it is resolved by the Dart/Flutter native assets system.
class UnrarExtractor {
  // Constants from dll.hpp
  static const int ERAR_END_ARCHIVE = 10;
  static const int ERAR_NO_MEMORY = 11;
  static const int ERAR_BAD_DATA = 12;
  static const int ERAR_BAD_ARCHIVE = 13;
  static const int ERAR_UNKNOWN_FORMAT = 14;
  static const int ERAR_EOPEN = 15;
  static const int ERAR_ECREATE = 16;
  static const int ERAR_ECLOSE = 17;
  static const int ERAR_EREAD = 18;
  static const int ERAR_EWRITE = 19;
  static const int ERAR_SMALL_BUF = 20;
  static const int ERAR_UNKNOWN = 21;
  static const int ERAR_MISSING_PASSWORD = 22;
  static const int ERAR_EREFERENCE = 23;
  static const int ERAR_BAD_PASSWORD = 24;
  static const int ERAR_LARGE_DICT = 25;

  static const int RAR_OM_LIST = 0;
  static const int RAR_OM_EXTRACT = 1;
  static const int RAR_OM_LIST_INCSPLIT = 2;

  static const int RAR_SKIP = 0;
  static const int RAR_TEST = 1;
  static const int RAR_EXTRACT = 2;

  @Deprecated('Unused; the header struct is defined in the bindings.')
  static const int HEADER_SIZE = 560;

  /// Lists all files in a RAR archive.
  ///
  /// [password] is needed for archives with encrypted file names.
  ///
  /// Returns a list of [ArchiveEntry] objects representing each file.
  /// Throws [UnrarException] if the archive cannot be opened or read.
  List<ArchiveEntry> listFiles(String archivePath, {String? password}) {
    final entries = <ArchiveEntry>[];
    _Archive.use(archivePath, bindings.RAR_OM_LIST, password, (archive) {
      while (archive.readHeader()) {
        entries.add(archive.entry);
        archive.process(bindings.RAR_SKIP);
      }
    });
    return entries;
  }

  /// Extracts all files from a RAR archive to the specified output directory.
  ///
  /// [archivePath]: Path to the RAR archive file.
  /// [outputPath]: Directory where files will be extracted.
  /// [password]: Optional password for encrypted archives.
  ///
  /// Throws [UnrarException] if extraction fails.
  void extractAll(String archivePath, String outputPath, {String? password}) {
    _Archive.use(archivePath, bindings.RAR_OM_EXTRACT, password, (archive) {
      final destPath = archive.wide(outputPath);
      while (archive.readHeader()) {
        archive.process(bindings.RAR_EXTRACT, destPath: destPath);
      }
    });
  }

  /// Extracts a single file from a RAR archive and returns its contents.
  ///
  /// The file is decompressed straight into memory; nothing is written to
  /// disk.
  ///
  /// [archivePath]: Path to the RAR archive file.
  /// [fileName]: Name of the file to extract, as reported by [listFiles].
  /// [password]: Optional password for encrypted archives.
  ///
  /// Returns the file contents as a [Uint8List].
  /// Throws [UnrarException] if the file is not found or extraction fails.
  Uint8List extractFile(
    String archivePath,
    String fileName, {
    String? password,
  }) {
    Uint8List? data;
    _Archive.use(archivePath, bindings.RAR_OM_EXTRACT, password, (archive) {
      while (archive.readHeader()) {
        if (archive.entry.name != fileName) {
          archive.process(bindings.RAR_SKIP);
          continue;
        }
        final builder = BytesBuilder(copy: false);
        // RAR_TEST decompresses and verifies the file without writing it,
        // handing the data to the callback as UCM_PROCESSDATA.
        archive.onData = builder.add;
        archive.process(bindings.RAR_TEST);
        data = builder.takeBytes();
        return;
      }
    });
    return data ??
        (throw UnrarException('File not found in archive: $fileName'));
  }

  /// Tests a RAR archive for integrity.
  ///
  /// Returns true if the archive is valid and can be extracted.
  /// Throws [UnrarException] if the archive is corrupted or cannot be opened.
  bool testArchive(String archivePath, {String? password}) {
    _Archive.use(archivePath, bindings.RAR_OM_EXTRACT, password, (archive) {
      while (archive.readHeader()) {
        archive.process(bindings.RAR_TEST);
      }
    });
    return true;
  }
}

/// An open archive handle together with the native memory it uses.
final class _Archive {
  _Archive._(this._password);

  /// Opens [path], runs [body] and always closes the archive afterwards.
  static void use(
    String path,
    int openMode,
    String? password,
    void Function(_Archive archive) body,
  ) {
    final archive = _Archive._(password);
    try {
      archive._open(path, openMode);
      body(archive);
    } finally {
      archive._close();
    }
  }

  /// Size of unrar's FileNameEx buffer, in characters (MAXPATHSIZE).
  static const int _maxPathSize = 0x10000;

  final String? _password;
  final Arena _arena = Arena();
  late final NativeCallable<_UnrarCallback> _callback =
      NativeCallable<_UnrarCallback>.isolateLocal(
        _onCallback,
        exceptionalReturn: -1,
      );
  late final Pointer<bindings.RARHeaderDataEx> _header;
  Pointer<Void> _handle = nullptr;

  /// Receives decompressed data during [bindings.RAR_TEST] and
  /// [bindings.RAR_EXTRACT].
  void Function(Uint8List chunk)? onData;

  void _open(String path, int openMode) {
    final openData = _arena<bindings.RAROpenArchiveDataEx>();
    // Pass the name as wchar_t so non-ASCII paths don't depend on the C locale.
    openData.ref.ArcNameW = wide(path);
    openData.ref.OpenMode = openMode;
    // The password callback must be installed at open time: archives with
    // encrypted headers ask for it while opening.
    openData.ref.Callback = _callback.nativeFunction;

    _handle = bindings.RAROpenArchiveEx(openData);
    final result = openData.ref.OpenResult;
    if (result != bindings.ERAR_SUCCESS || _handle == nullptr) {
      _handle = nullptr;
      throw UnrarException(_errorMessage(result), result);
    }

    _header = _arena<bindings.RARHeaderDataEx>();
    _header.ref.FileNameEx = _arena<WChar>(_maxPathSize);
    _header.ref.FileNameExSize = _maxPathSize;
  }

  void _close() {
    if (_handle != nullptr) bindings.RARCloseArchive(_handle);
    _handle = nullptr;
    _callback.close();
    _arena.releaseAll();
  }

  /// Reads the next file header. Returns false at the end of the archive.
  bool readHeader() {
    final result = bindings.RARReadHeaderEx(_handle, _header);
    if (result == bindings.ERAR_END_ARCHIVE) return false;
    _check(result);
    _entry = null;
    return true;
  }

  /// Skips, tests or extracts the file whose header was last read.
  void process(int operation, {Pointer<WChar>? destPath}) {
    try {
      _check(
        bindings.RARProcessFileW(
          _handle,
          operation,
          destPath ?? nullptr,
          nullptr,
        ),
      );
    } finally {
      onData = null;
    }
  }

  ArchiveEntry? _entry;

  /// The entry described by the header last read with [readHeader].
  ArchiveEntry get entry => _entry ??= _readEntry(_header.ref);

  /// Copies [value] into a NUL-terminated wchar_t string owned by this
  /// archive.
  Pointer<WChar> wide(String value) {
    // wchar_t is UTF-16 on Windows and UTF-32 everywhere else.
    final units = sizeOf<WChar>() == 2 ? value.codeUnits : value.runes.toList();
    final pointer = _arena<WChar>(units.length + 1);
    for (var i = 0; i < units.length; i++) {
      pointer[i] = units[i];
    }
    pointer[units.length] = 0;
    return pointer;
  }

  static String _fromWide(Pointer<WChar> pointer, int maxLength) {
    final units = <int>[];
    for (var i = 0; i < maxLength; i++) {
      final unit = pointer[i];
      if (unit == 0) break;
      units.add(unit);
    }
    return String.fromCharCodes(units);
  }

  static ArchiveEntry _readEntry(bindings.RARHeaderDataEx header) {
    // MtimeLow/High is a Windows FILETIME: 100ns ticks since 1601-01-01 UTC.
    // (FileTime is MS-DOS packed local time, not a Unix timestamp.)
    const fileTimeToUnixEpochMicros = 11644473600000000;
    final fileTime = (header.MtimeHigh << 32) | header.MtimeLow;

    return ArchiveEntry(
      name: _fromWide(header.FileNameEx, header.FileNameExSize),
      size: (header.UnpSizeHigh << 32) | header.UnpSize,
      packedSize: (header.PackSizeHigh << 32) | header.PackSize,
      crc: header.FileCRC,
      attributes: header.FileAttr,
      modificationTime: DateTime.fromMicrosecondsSinceEpoch(
        fileTime ~/ 10 - fileTimeToUnixEpochMicros,
        isUtc: true,
      ),
      isDirectory: (header.Flags & bindings.RHDF_DIRECTORY) != 0,
    );
  }

  int _onCallback(int msg, int userData, int p1, int p2) {
    switch (msg) {
      case 1: // UCM_PROCESSDATA: p1 = data, p2 = length.
        onData?.call(
          Uint8List.fromList(Pointer<Uint8>.fromAddress(p1).asTypedList(p2)),
        );
        return 1;
      case 4: // UCM_NEEDPASSWORDW: p1 = wchar_t buffer, p2 = its length.
        final password = _password;
        if (password == null) return -1;
        final buffer = Pointer<WChar>.fromAddress(p1);
        final units = sizeOf<WChar>() == 2
            ? password.codeUnits
            : password.runes.toList();
        final length = units.length < p2 ? units.length : p2 - 1;
        for (var i = 0; i < length; i++) {
          buffer[i] = units[i];
        }
        buffer[length] = 0;
        return 1;
      case 0: // UCM_CHANGEVOLUME
      case 3: // UCM_CHANGEVOLUMEW: p2 = RAR_VOL_ASK or RAR_VOL_NOTIFY.
        // Continue when the next volume exists; abort when it's missing.
        return p2 == bindings.RAR_VOL_NOTIFY ? 1 : -1;
      default:
        // UCM_NEEDPASSWORD (ANSI fallback) and UCM_LARGEDICT: decline.
        return -1;
    }
  }

  static void _check(int result) {
    if (result != bindings.ERAR_SUCCESS) {
      throw UnrarException(_errorMessage(result), result);
    }
  }

  static String _errorMessage(int errorCode) {
    switch (errorCode) {
      case bindings.ERAR_NO_MEMORY:
        return 'Not enough memory';
      case bindings.ERAR_BAD_DATA:
        return 'Archive header or data is broken';
      case bindings.ERAR_BAD_ARCHIVE:
        return 'File is not a valid RAR archive';
      case bindings.ERAR_UNKNOWN_FORMAT:
        return 'Unknown archive format';
      case bindings.ERAR_EOPEN:
        return 'Cannot open file';
      case bindings.ERAR_ECREATE:
        return 'Cannot create file';
      case bindings.ERAR_ECLOSE:
        return 'Cannot close file';
      case bindings.ERAR_EREAD:
        return 'Read error';
      case bindings.ERAR_EWRITE:
        return 'Write error';
      case bindings.ERAR_SMALL_BUF:
        return 'Buffer too small';
      case bindings.ERAR_MISSING_PASSWORD:
        return 'Password required';
      case bindings.ERAR_EREFERENCE:
        return 'Cannot extract a file reference without its source';
      case bindings.ERAR_BAD_PASSWORD:
        return 'Incorrect password';
      case bindings.ERAR_LARGE_DICT:
        return 'Dictionary size exceeds the allowed limit';
      case bindings.ERAR_UNKNOWN:
      default:
        return 'Unknown error';
    }
  }
}
