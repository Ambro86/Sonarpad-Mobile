import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Sources from the `lib` target of `third_party/unrar/makefile`
/// (OBJECTS + LIB_OBJ).
const _sources = [
  'rar.cpp',
  'strlist.cpp',
  'strfn.cpp',
  'pathfn.cpp',
  'smallfn.cpp',
  'global.cpp',
  'file.cpp',
  'filefn.cpp',
  'filcreat.cpp',
  'archive.cpp',
  'arcread.cpp',
  'unicode.cpp',
  'system.cpp',
  'crypt.cpp',
  'crc.cpp',
  'rawread.cpp',
  'encname.cpp',
  'resource.cpp',
  'match.cpp',
  'timefn.cpp',
  'rdwrfn.cpp',
  'consio.cpp',
  'options.cpp',
  'errhnd.cpp',
  'rarvm.cpp',
  'secpassword.cpp',
  'rijndael.cpp',
  'getbits.cpp',
  'sha1.cpp',
  'sha256.cpp',
  'blake2s.cpp',
  'hash.cpp',
  'extinfo.cpp',
  'extract.cpp',
  'volume.cpp',
  'list.cpp',
  'find.cpp',
  'unpack.cpp',
  'headers.cpp',
  'threadpool.cpp',
  'rs16.cpp',
  'cmddata.cpp',
  'ui.cpp',
  'largepage.cpp',
  'filestr.cpp',
  'scantree.cpp',
  'dll.cpp',
  'qopen.cpp',
];

/// Additional sources that UnRARDll.vcxproj compiles on Windows only.
const _windowsSources = ['isnt.cpp', 'motw.cpp'];

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    // Use the *target* OS, not the host: Flutter cross-compiles for Android
    // and iOS from macOS/Linux/Windows hosts.
    final targetOS = input.config.code.targetOS;
    final isWindows = targetOS == OS.windows;

    final cBuilder = CBuilder.library(
      name: input.packageName,
      // Must match the `@DefaultAsset` in lib/src/unrar_bindings.dart.
      assetName: 'unrar.dart',
      sources: [
        for (final source in [..._sources, if (isWindows) ..._windowsSources])
          'third_party/unrar/$source',
        // dll.hpp has no dllexport annotations; upstream exports via dll.def.
        if (isWindows) 'src/windows_exports.cpp',
      ],
      // Compile as C++ and link the right C++ runtime for each target.
      language: Language.cpp,
      // MSVC has no C++11 mode; its default standard is newer anyway.
      std: isWindows ? null : 'c++11',
      // Statically link libc++ so apps don't have to ship libc++_shared.so.
      cppLinkStdLib: targetOS == OS.android ? 'c++_static' : null,
      defines: {
        'RARDLL': null,
        'RAR_SMP': null,
        // Android API 24 has utimensat; lutimes requires API 26.
        if (targetOS == OS.android) 'UNIX_TIME_NS': null,
        if (!isWindows) ...{
          '_FILE_OFFSET_BITS': '64',
          '_LARGEFILE_SOURCE': null,
        },
      },
      flags: [
        if (!isWindows) ...[
          '-pthread',
          '-Wno-logical-op-parentheses',
          '-Wno-switch',
          '-Wno-dangling-else',
        ],
      ],
      libraries: [
        if (isWindows) ...[
          'advapi32',
          'ole32',
          'oleaut32',
          'shell32',
          'user32',
        ],
      ],
    );

    await cBuilder.run(
      input: input,
      output: output,
      logger: Logger('')
        ..level = Level.ALL
        ..onRecord.listen((record) => print(record.message)),
    );
  });
}
