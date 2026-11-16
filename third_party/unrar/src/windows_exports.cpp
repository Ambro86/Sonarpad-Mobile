// third_party/unrar/dll.hpp declares the API without __declspec(dllexport);
// upstream exports it through dll.def, which native_toolchain_c has no way to
// pass to the MSVC linker. Export the same symbols from here instead.
//
// Only compiled for Windows targets (see hook/build.dart). PASCAL (__stdcall)
// does not decorate names on x64/arm64, so the plain names are correct.
#pragma comment(linker, "/EXPORT:RAROpenArchive")
#pragma comment(linker, "/EXPORT:RAROpenArchiveEx")
#pragma comment(linker, "/EXPORT:RARCloseArchive")
#pragma comment(linker, "/EXPORT:RARReadHeader")
#pragma comment(linker, "/EXPORT:RARReadHeaderEx")
#pragma comment(linker, "/EXPORT:RARProcessFile")
#pragma comment(linker, "/EXPORT:RARProcessFileW")
#pragma comment(linker, "/EXPORT:RARSetCallback")
#pragma comment(linker, "/EXPORT:RARSetChangeVolProc")
#pragma comment(linker, "/EXPORT:RARSetProcessDataProc")
#pragma comment(linker, "/EXPORT:RARSetPassword")
#pragma comment(linker, "/EXPORT:RARGetDllVersion")
