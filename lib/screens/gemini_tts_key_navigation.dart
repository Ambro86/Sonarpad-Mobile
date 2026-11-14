import 'package:flutter/material.dart';
import '../tts/gemini_tts_bridge.dart';
import 'create_ai_audiodescription_screen.dart';

Future<bool> ensureGeminiTtsKey(BuildContext context) async {
  if (await GeminiTtsBridge.hasCredentials()) return true;
  if (!context.mounted) return false;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          const CreateAiAudiodescriptionScreen(focusGeminiApiKey: true),
    ),
  );
  return GeminiTtsBridge.hasCredentials();
}
