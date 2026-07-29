import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final packageName = input.packageName;
    final builder = CBuilder.library(
      name: packageName,
      assetName: '$packageName.dart',
      sources: ['src/sonarpad_audio_dsp.cpp'],
      includes: ['src'],
      language: Language.cpp,
      std: 'c++17',
      flags: ['-O3'],
    );
    await builder.run(input: input, output: output);
  });
}
