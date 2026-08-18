import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';
import '../services/italiaonline_service.dart';
import '../services/document_library_service.dart';
import '../services/voice_dictionary_service.dart';
import '../tts/edge_tts_bridge.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class ItaliaOnlineDetailScreen extends StatefulWidget {
  final DetailResponse detail;

  const ItaliaOnlineDetailScreen({super.key, required this.detail});

  @override
  State<ItaliaOnlineDetailScreen> createState() => _ItaliaOnlineDetailScreenState();
}

class _ItaliaOnlineDetailScreenState extends State<ItaliaOnlineDetailScreen> {
  final FlutterTts _tts = FlutterTts();
  final EdgeTtsBridge _edgeTts = EdgeTtsBridge();
  final AudioPlayerService _audio = AudioPlayerService();
  final AppSettingsService _settings = AppSettingsService();
  final VoiceDictionaryService _voiceDictionary = VoiceDictionaryService();
  bool _isPlaying = false;

  @override
  void dispose() {
    unawaited(_tts.stop());
    unawaited(_audio.stopAndDispose());
    super.dispose();
  }

  Future<String> _edgeVoice() async {
    final configured = await _settings.loadTtsVoice();
    if (configured.trim().isNotEmpty) return configured;
    return 'it-IT-IsabellaNeural';
  }

  Future<void> _speak() async {
    await _audio.stop();
    await _tts.stop();
    if (mounted) setState(() => _isPlaying = true);
    try {
      final engine = await _settings.loadTtsEngine();
      final dictionaryEntries = await _voiceDictionary.loadEntries();
      final text = _detailTextForSpeech(widget.detail);
      final chunks = _edgeTts.splitTextForStreaming(text, maxChunkChars: 650);
      if (engine == 'system') {
        await _tts.awaitSpeakCompletion(true);
        final speed = await _settings.loadTtsSpeed();
        final pitch = await _settings.loadTtsPitch();
        await _tts.setSpeechRate(speed * 0.5);
        await _tts.setPitch(pitch);

        final sysLang = await _settings.loadSystemTtsLanguage();
        final sysVoice = await _settings.loadSystemTtsVoice();
        if (sysVoice != null) {
          await _tts.setVoice({"name": sysVoice, "locale": sysLang});
        } else {
          await _tts.setLanguage(sysLang);
        }

        for (final chunk in chunks) {
          if (!mounted || !_isPlaying) break;
          final textToSpeak =
              _voiceDictionary.applyToText(chunk, dictionaryEntries);
          await _tts.speak(textToSpeak);
        }
      } else {
        final voice = await _edgeVoice();
        final files = <File>[];
        for (final chunk in chunks) {
          if (!mounted || !_isPlaying) break;
          final textToSpeak =
              _voiceDictionary.applyToText(chunk, dictionaryEntries);
          files.add(await _edgeTts.speakToFile(
            text: textToSpeak,
            voice: voice,
          ));
        }
        if (mounted && _isPlaying && files.isNotEmpty) {
          await _audio.playFilesSequentially(files);
        }
      }
    } catch (e) {
      debugPrint('ItaliaOnline TTS error: $e');
      if (mounted) {
                showStatusMessage(context, 'Errore durante la lettura: $e');
      }
    } finally {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _stop() async {
    await _audio.stop();
    await _tts.stop();
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _launchUrl(String urlStr) async {
    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch $urlStr');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    return Scaffold(
      appBar: AppBar(
        title: Text(detail.title),
        actions: [
          if (!_isPlaying)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Avvia lettura',
              onPressed: _speak,
            )
          else
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: 'Ferma lettura',
              onPressed: _stop,
            ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Salva nei documenti',
            onPressed: () async {
              try {
                final doc = await DocumentLibraryService().createTextDocument(
                  name: '${detail.title}.txt',
                  content: detail.body,
                  isTemporary: false,
                );
                final lib = DocumentLibraryService();
                await lib.load();
                await lib.add(doc);
                if (context.mounted) {
                                    showStatusMessage(context, 'Salvato nei documenti!');
                }
              } catch (e) {
                if (context.mounted) {
                                    showStatusMessage(context, 'Errore durante il salvataggio: $e');
                }
              }
            },
          ),
        ],
      ),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [
                AccessibleListSection(rows: [
                  if (detail.description != null && detail.description!.isNotEmpty)
                    AccessibleListRow(id: 'description', kind: 'text', title: detail.description!),
                  if (detail.category != null && detail.category!.isNotEmpty)
                    AccessibleListRow(id: 'category', kind: 'text', title: 'Categoria: ${detail.category}'),
                  if (detail.address != null && detail.address!.isNotEmpty)
                    AccessibleListRow(id: 'address', kind: 'text', title: detail.address!),
                  if (detail.locality != null && detail.locality!.isNotEmpty)
                    AccessibleListRow(id: 'locality', kind: 'text', title: detail.locality!),
                  for (var i = 0; i < detail.phones.length; i++)
                    AccessibleListRow(id: 'phone_$i', title: detail.phones[i], subtitle: 'Telefono'),
                  for (var i = 0; i < detail.websites.length; i++)
                    AccessibleListRow(id: 'website_$i', title: detail.websites[i], subtitle: 'Sito web'),
                  for (var i = 0; i < detail.emails.length; i++)
                    AccessibleListRow(id: 'email_$i', title: detail.emails[i], subtitle: 'Email'),
                  if (detail.publicUrl != null && detail.publicUrl!.isNotEmpty)
                    const AccessibleListRow(id: 'public', title: 'Apri scheda originale'),
                ]),
              ],
              onEvent: (event) {
                if (event.type != 'activate' || event.id == null) return;
                if (event.id!.startsWith('phone_')) {
                  final i = int.tryParse(event.id!.substring(6));
                  if (i != null && i < detail.phones.length) _launchUrl('tel:${detail.phones[i]}');
                } else if (event.id!.startsWith('website_')) {
                  final i = int.tryParse(event.id!.substring(8));
                  if (i != null && i < detail.websites.length) {
                    var url = detail.websites[i];
                    if (!url.startsWith('http')) url = 'https://$url';
                    _launchUrl(url);
                  }
                } else if (event.id!.startsWith('email_')) {
                  final i = int.tryParse(event.id!.substring(6));
                  if (i != null && i < detail.emails.length) _launchUrl('mailto:${detail.emails[i]}');
                } else if (event.id == 'public' && detail.publicUrl != null) {
                  _launchUrl(detail.publicUrl!);
                }
              },
            )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (detail.description != null && detail.description!.isNotEmpty) ...[
            Text(
              detail.description!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
          ],
          if (detail.category != null && detail.category!.isNotEmpty) ...[
            Text(
              'Categoria: ${detail.category}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
          ],
          if (detail.address != null || (detail.locality != null && detail.locality!.isNotEmpty)) ...[
            const Text(
              'Indirizzo:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (detail.address != null && detail.address!.isNotEmpty) Text(detail.address!),
            if (detail.locality != null && detail.locality!.isNotEmpty) Text(detail.locality!),
            const SizedBox(height: 16),
          ],
          if (detail.phones.isNotEmpty) ...[
            const Text(
              'Telefoni (tocca per chiamare):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...detail.phones.map((p) => ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(p),
                  onTap: () => _launchUrl('tel:$p'),
                )),
            const SizedBox(height: 16),
          ],
          if (detail.websites.isNotEmpty) ...[
            const Text(
              'Siti web (tocca per aprire):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...detail.websites.map((w) => ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(w),
                  onTap: () {
                    var url = w;
                    if (!url.startsWith('http')) {
                      url = 'https://$url';
                    }
                    _launchUrl(url);
                  },
                )),
            const SizedBox(height: 16),
          ],
          if (detail.emails.isNotEmpty) ...[
            const Text(
              'Email:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...detail.emails.map((e) => ListTile(
                  leading: const Icon(Icons.email),
                  title: Text(e),
                  onTap: () => _launchUrl('mailto:$e'),
                )),
            const SizedBox(height: 16),
          ],
          if (detail.publicUrl != null && detail.publicUrl!.isNotEmpty) ...[
            const Text(
              'Scheda web:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Apri scheda originale'),
              onTap: () => _launchUrl(detail.publicUrl!),
            ),
          ],
        ],
      ),
    );
  }
}

String _detailTextForSpeech(DetailResponse detail) {
  final lines = <String>[];
  final seen = <String>{};

  void addLine(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    final key = _normalizeSpeechLine(trimmed);
    if (!seen.add(key)) return;
    lines.add(trimmed);
  }

  addLine(detail.title);

  if (_shouldReadDescription(detail)) {
    addLine(detail.description);
  }

  if (detail.category != null && detail.category!.isNotEmpty) {
    addLine('Categoria: ${detail.category}');
  }

  if ((detail.address != null && detail.address!.isNotEmpty) ||
      (detail.locality != null && detail.locality!.isNotEmpty)) {
    addLine('Indirizzo:');
    addLine(detail.address);
    addLine(detail.locality);
  }

  if (detail.phones.isNotEmpty) {
    addLine('Telefoni:');
    for (final phone in detail.phones) {
      addLine(phone);
    }
  }

  if (detail.emails.isNotEmpty) {
    addLine('Email:');
    for (final email in detail.emails) {
      addLine(email);
    }
  }

  if (detail.websites.isNotEmpty) {
    addLine('Siti web:');
    for (final website in detail.websites) {
      addLine(website);
    }
  }

  return lines.join('\n');
}

bool _shouldReadDescription(DetailResponse detail) {
  final description = detail.description?.trim();
  if (description == null || description.isEmpty) return false;

  final normalizedDescription = _normalizeSpeechLine(description);
  final repeatedValues = [
    detail.title,
    detail.address,
    detail.locality,
    ...detail.phones,
  ];

  for (final value in repeatedValues) {
    final normalizedValue = _normalizeSpeechLine(value ?? '');
    if (normalizedValue.isNotEmpty &&
        normalizedDescription.contains(normalizedValue)) {
      return false;
    }
  }

  return true;
}

String _normalizeSpeechLine(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .trim();
}
