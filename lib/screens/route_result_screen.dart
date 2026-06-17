import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';
import '../services/document_library_service.dart';
import '../services/route_service.dart';
import '../services/voice_dictionary_service.dart';
import '../tts/edge_tts_bridge.dart';

class RouteResultScreen extends StatelessWidget {
  final RouteResult result;

  const RouteResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeResultsTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: result.paths.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final path = result.paths[index];
          final distanceStr = l10n.formatDistance(path.distanceMeters);
          final durationStr = l10n.formatDuration(path.durationSeconds);

          return ListTile(
            title: Text('${l10n.routeDistance}: $distanceStr'),
            subtitle: Text('${l10n.routeDuration}: $durationStr'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/route/steps'),
                  builder: (_) => RouteStepsScreen(
                    path: path,
                    fromLabel: result.from.displayLabel,
                    toLabel: result.to.displayLabel,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class RouteStepsScreen extends StatefulWidget {
  final RoutePath path;
  final String fromLabel;
  final String toLabel;

  const RouteStepsScreen({
    super.key,
    required this.path,
    required this.fromLabel,
    required this.toLabel,
  });

  @override
  State<RouteStepsScreen> createState() => _RouteStepsScreenState();
}

class _RouteStepsScreenState extends State<RouteStepsScreen> {
  final AppSettingsService _settings = AppSettingsService();
  final EdgeTtsBridge _edgeTts = EdgeTtsBridge();
  final AudioPlayerService _audio = AudioPlayerService();
  final FlutterTts _flutterTts = FlutterTts();
  final VoiceDictionaryService _voiceDictionary = VoiceDictionaryService();
  bool _speaking = false;
  bool _ttsPaused = false;
  int _readingToken = 0;
  StreamController<File>? _edgeFileController;
  late final List<_RouteStepItem> _items;

  static const _ttsCommands = MethodChannel('sonarpad/tts_commands');
  static const _ttsEvents = EventChannel('sonarpad/tts_events');
  StreamSubscription? _ttsEventsSub;

  @override
  void initState() {
    super.initState();
    _ttsEventsSub = _ttsEvents.receiveBroadcastStream().listen((event) {
      if (event == 'toggle' && mounted) {
        _togglePlayPause();
      }
    });
    _flutterTts.setPauseHandler(() {
      if (mounted && _speaking) setState(() => _ttsPaused = true);
    });
    _flutterTts.setContinueHandler(() {
      if (mounted && _speaking) setState(() => _ttsPaused = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context);
    _items = _routeStepItems(widget.path, l10n);
  }

  @override
  void dispose() {
    _readingToken += 1;
    final edgeController = _edgeFileController;
    _edgeFileController = null;
    if (edgeController != null && !edgeController.isClosed) {
      unawaited(edgeController.close());
    }
    if (Platform.isIOS) {
      _ttsCommands.invokeMethod('clearMagicTap').catchError((_) {});
    }
    _ttsEventsSub?.cancel();
    _flutterTts.stop();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (!_speaking) return;
    if (_ttsPaused) {
      if (mounted) setState(() => _ttsPaused = false);
      unawaited(_flutterTts.speak('').catchError((_) => null));
      await _audio.play();
    } else {
      if (mounted) setState(() => _ttsPaused = true);
      await _flutterTts.pause();
      await _audio.pause();
    }
  }

  Future<void> _toggleSpeech() async {
    if (_speaking) {
      await _stopReading();
      return;
    }
    await _startReading();
  }

  Future<void> _stopReading() async {
    _readingToken += 1;
    final edgeController = _edgeFileController;
    _edgeFileController = null;
    if (mounted) {
      setState(() {
        _speaking = false;
        _ttsPaused = false;
      });
    }
    final stopAudio = _audio.stop();
    final stopTts = _flutterTts.stop();
    if (edgeController != null && !edgeController.isClosed) {
      await edgeController.close();
    }
    await stopAudio;
    await stopTts;
    if (Platform.isIOS) {
      try {
        await _ttsCommands.invokeMethod('clearMagicTap');
      } catch (_) {}
    }
  }

  Future<String> _voice() async {
    final configured = await _settings.loadTtsVoice();
    if (configured.trim().isNotEmpty) return configured;
    return 'it-IT-IsabellaNeural';
  }

  Future<void> _startReading() async {
    final l10n = AppLocalizations.of(context);
    final chunks = _speechChunks(l10n);
    if (chunks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noTextToRead)),
      );
      return;
    }

    final readingToken = ++_readingToken;
    await _audio.stop();
    await _flutterTts.stop();
    if (mounted) {
      setState(() {
        _speaking = true;
        _ttsPaused = false;
      });
    }

    try {
      final engine = await _settings.loadTtsEngine();
      final dictionaryEntries = await _voiceDictionary.loadEntries();

      if (engine == 'system') {
        if (Platform.isIOS) {
          try {
            await _ttsCommands.invokeMethod('setupMagicTap', l10n.routeNavigation);
          } catch (_) {}
        }
        await _flutterTts.awaitSpeakCompletion(true);
        if (Platform.isIOS) {
          await _flutterTts.setSharedInstance(true);
          await _flutterTts.autoStopSharedSession(false);
        }
        final speed = await _settings.loadTtsSpeed();
        final pitch = await _settings.loadTtsPitch();
        await _flutterTts.setSpeechRate(speed * 0.5);
        await _flutterTts.setPitch(pitch);

        final sysLang = await _settings.loadSystemTtsLanguage();
        final sysVoice = await _settings.loadSystemTtsVoice();

        if (sysVoice != null) {
          await _flutterTts.setVoice({'name': sysVoice, 'locale': sysLang});
        } else {
          await _flutterTts.setLanguage(sysLang);
        }

        for (var i = 0; i < chunks.length; i++) {
          if (!mounted || !_speaking || readingToken != _readingToken) break;
          while (_ttsPaused) {
            if (!mounted || !_speaking || readingToken != _readingToken) break;
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          if (!mounted || !_speaking || readingToken != _readingToken) break;
          final textToSpeak =
              _voiceDictionary.applyToText(chunks[i], dictionaryEntries);
          await _flutterTts.speak(textToSpeak);
        }
      } else {
        final voice = await _voice();
        final controller = StreamController<File>();
        _edgeFileController = controller;
        Object? generationError;
        // Manteniamo un piccolo buffer iniziale: serve a evitare micro-interruzioni
        // e aiuta la lettura a continuare meglio anche se lo schermo viene bloccato.
        // I blocchi restano comunque piccoli: una indicazione del percorso per volta.
        const initialBufferChunks = 2;

        final generation = Future<void>(() async {
          for (var i = 0; i < chunks.length; i++) {
            if (!mounted || !_speaking || readingToken != _readingToken) break;
            while (_ttsPaused) {
              if (!mounted || !_speaking || readingToken != _readingToken) break;
              await Future<void>.delayed(const Duration(milliseconds: 100));
            }
            if (!mounted || !_speaking || readingToken != _readingToken) break;
            final textToSpeak =
                _voiceDictionary.applyToText(chunks[i], dictionaryEntries);
            final file = await _edgeTts.speakToFile(
              text: textToSpeak,
              voice: voice,
            );
            if (!controller.isClosed &&
                mounted &&
                _speaking &&
                readingToken == _readingToken) {
              controller.add(file);
            }
          }
          if (!controller.isClosed) await controller.close();
        }).catchError((e) async {
          generationError = e;
          if (!controller.isClosed) await controller.close();
        });

        await _audio.playFileStreamSequentially(
          controller.stream,
          sessionType: AudioSessionType.playback,
          title: l10n.routeNavigation,
          initialBufferCount: initialBufferChunks,
          isPaused: () => _ttsPaused,
        );
        if (!controller.isClosed) await controller.close();
        await generation;
        if (_edgeFileController == controller) {
          _edgeFileController = null;
        }
        if (readingToken != _readingToken) return;
        if (generationError != null) throw Exception(generationError);
      }
    } catch (e) {
      if (!mounted || readingToken != _readingToken) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.edgeTtsError(e))),
      );
    } finally {
      if (mounted && readingToken == _readingToken) {
        setState(() {
          _speaking = false;
          _ttsPaused = false;
        });
      }
    }
  }

  Future<void> _saveAsDocument() async {
    final l10n = AppLocalizations.of(context);
    final text = _routeDocumentText(l10n);

    final lib = DocumentLibraryService();
    final doc = await lib.createTextDocument(
      name: _documentFileName(l10n),
      content: text,
      isTemporary: false,
    );
    await lib.load();
    await lib.add(doc);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.routeSaveSuccess)),
    );
  }

  String _routeDocumentText(AppLocalizations l10n) {
    final rawText = _items.map((item) {
      final distanceStr = l10n.formatDistance(item.distanceMeters);
      return item.showDistance
          ? '${item.instruction} ($distanceStr)'
          : item.instruction;
    }).join('\n');

    return _normalizeParagraphBreaks(rawText);
  }

  // Stesso criterio usato dalla creazione manuale dei Documenti:
  // ogni riga non vuota diventa un paragrafo separato da doppio invio.
  // Così i percorsi salvati nei Documenti si comportano come i testi
  // scritti dall'utente quando preme Invio tra un paragrafo e l'altro.
  String _normalizeParagraphBreaks(String text) {
    final normalized = text.trim().replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final paragraphs = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    return paragraphs.join('\n\n');
  }

  List<String> _speechChunks(AppLocalizations l10n) {
    final chunks = <String>[];
    final speechText = _normalizeParagraphBreaks(_items.map((item) {
      final distanceStr = l10n.formatDistance(item.distanceMeters);
      return item.showDistance
          ? '${item.instruction}. $distanceStr.'
          : item.instruction;
    }).join('\n'));

    for (final paragraph in speechText.split(RegExp(r'\n{2,}'))) {
      final cleaned = paragraph.trim();
      if (cleaned.isEmpty) continue;

      // La separazione base è la stessa dei Documenti: ogni riga/indicazione
      // diventa un paragrafo. Solo se un paragrafo è troppo lungo viene diviso
      // in sotto-blocchi tecnici per Edge TTS.
      final safeChunks = _edgeTts.splitTextForStreaming(
        cleaned,
        maxChunkChars: 420,
      );
      if (safeChunks.isEmpty) {
        chunks.add(cleaned);
      } else {
        chunks.addAll(safeChunks.map((chunk) => chunk.trim()).where(
              (chunk) => chunk.isNotEmpty,
            ));
      }
    }

    return chunks;
  }

  String _documentFileName(AppLocalizations l10n) {
    final date = DateTime.now().toIso8601String().split('T').first;
    return '${l10n.routeNavigationFromTo(_shortAddress(widget.fromLabel), _shortAddress(widget.toLabel), date)}.txt';
  }

  String _shortAddress(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.length <= 80) return trimmed;
    return '${trimmed.substring(0, 77)}...';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.routeNavigation),
        actions: [
          IconButton(
            icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
            tooltip: l10n.routeReadAction,
            onPressed: _toggleSpeech,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: l10n.routeSaveAction,
            onPressed: _saveAsDocument,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final distanceStr = l10n.formatDistance(item.distanceMeters);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              item.showDistance
                  ? '${item.instruction} ($distanceStr)'
                  : item.instruction,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        },
      ),
    );
  }

  List<_RouteStepItem> _routeStepItems(RoutePath path, AppLocalizations l10n) {
    final items = <_RouteStepItem>[];
    final changes = path.municipalityChanges
        .where((change) => change.name.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    if (changes.isEmpty) {
      return path.steps
          .map((step) => _RouteStepItem(
                instruction: step.instruction,
                distanceMeters: step.distanceMeters,
              ))
          .toList();
    }

    final seenMunicipalities = <String>{};
    final uniqueChanges = changes.where((change) {
      final key = change.name.trim().toLowerCase();
      return seenMunicipalities.add(key);
    }).toList();

    if (uniqueChanges.isNotEmpty && uniqueChanges.first.distanceMeters <= 1.0) {
      items.add(_RouteStepItem(
        instruction:
            '${l10n.routeStartMunicipality}: ${uniqueChanges.first.name.trim()}',
        distanceMeters: uniqueChanges.first.distanceMeters,
        showDistance: false,
      ));
    }

    var nextChangeIndex =
        uniqueChanges.indexWhere((change) => change.distanceMeters > 1.0);
    if (nextChangeIndex < 0) {
      nextChangeIndex = uniqueChanges.length;
    }

    var travelledMeters = 0.0;
    for (final step in path.steps) {
      while (nextChangeIndex < uniqueChanges.length &&
          uniqueChanges[nextChangeIndex].distanceMeters <= travelledMeters) {
        final change = uniqueChanges[nextChangeIndex];
        items.add(_RouteStepItem(
          instruction: '${l10n.routeEnterMunicipality} ${change.name.trim()}',
          distanceMeters: change.distanceMeters,
          showDistance: false,
        ));
        nextChangeIndex += 1;
      }

      items.add(_RouteStepItem(
        instruction: step.instruction,
        distanceMeters: step.distanceMeters,
      ));
      travelledMeters += step.distanceMeters;
    }

    while (nextChangeIndex < uniqueChanges.length) {
      final change = uniqueChanges[nextChangeIndex];
      items.add(_RouteStepItem(
        instruction: '${l10n.routeEnterMunicipality} ${change.name.trim()}',
        distanceMeters: change.distanceMeters,
        showDistance: false,
      ));
      nextChangeIndex += 1;
    }

    return items;
  }
}

class _RouteStepItem {
  final String instruction;
  final double distanceMeters;
  final bool showDistance;

  const _RouteStepItem({
    required this.instruction,
    required this.distanceMeters,
    this.showDistance = true,
  });
}
