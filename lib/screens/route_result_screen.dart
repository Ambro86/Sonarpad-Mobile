import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
import '../services/app_settings_service.dart';
import '../services/audio_player_service.dart';
import '../services/document_library_service.dart';
import '../services/route_service.dart';
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
                  builder: (_) => RouteStepsScreen(path: path),
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

  const RouteStepsScreen({super.key, required this.path});

  @override
  State<RouteStepsScreen> createState() => _RouteStepsScreenState();
}

class _RouteStepsScreenState extends State<RouteStepsScreen> {
  final AppSettingsService _settings = AppSettingsService();
  final EdgeTtsBridge _edgeTts = EdgeTtsBridge();
  final AudioPlayerService _audio = AudioPlayerService();
  final FlutterTts _flutterTts = FlutterTts();
  bool _speaking = false;
  late final List<_RouteStepItem> _items;

  @override
  void initState() {
    super.initState();
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
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
    _flutterTts.stop();
    _audio.stop();
    super.dispose();
  }

  Future<void> _toggleSpeech() async {
    if (_speaking) {
      await _flutterTts.stop();
      await _audio.stop();
      if (mounted) setState(() => _speaking = false);
    } else {
      final l10n = AppLocalizations.of(context);
      final platform = Theme.of(context).platform;
      final text = _items.map((item) {
        final distanceStr = l10n.formatDistance(item.distanceMeters);
        return item.showDistance ? '${item.instruction}. $distanceStr.' : item.instruction;
      }).join('\n');
      
      if (mounted) setState(() => _speaking = true);
      
      try {
        final engine = await _settings.loadTtsEngine();
        if (engine == 'system') {
          final speed = await _settings.loadTtsSpeed();
          final pitch = await _settings.loadTtsPitch();
          final sysLang = await _settings.loadSystemTtsLanguage();
          final sysVoice = await _settings.loadSystemTtsVoice();
          
          await _flutterTts.setSpeechRate(speed * 0.5);
          await _flutterTts.setPitch(pitch);
          
          if (platform == TargetPlatform.iOS) {
            await _flutterTts.setIosAudioCategory(
                IosTextToSpeechAudioCategory.playback,
                [
                  IosTextToSpeechAudioCategoryOptions.allowBluetooth,
                  IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
                  IosTextToSpeechAudioCategoryOptions.mixWithOthers,
                ]);
          }
          
          if (sysVoice != null) {
            await _flutterTts.setVoice({
              "name": sysVoice,
              "locale": sysLang,
            });
          } else {
            await _flutterTts.setLanguage(sysLang);
          }
          
          await _flutterTts.speak(text);
        } else {
          final voice = await _settings.loadTtsVoice();
          final file = await _edgeTts.speakToFile(text: text, voice: voice);
          await _audio.playFile(file);
          if (mounted) setState(() => _speaking = false);
        }
      } catch (e) {
        if (mounted) setState(() => _speaking = false);
      }
    }
  }

  Future<void> _saveAsDocument() async {
    final l10n = AppLocalizations.of(context);
    final text = _items.map((item) {
      final distanceStr = l10n.formatDistance(item.distanceMeters);
      return item.showDistance ? '${item.instruction} ($distanceStr)' : item.instruction;
    }).join('\n\n');

    final lib = DocumentLibraryService();
    final doc = await lib.createTextDocument(
      name: '${l10n.routeNavigation} - ${DateTime.now().toIso8601String().split('T').first}.txt',
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
