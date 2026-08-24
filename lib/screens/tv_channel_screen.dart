import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../models/radio_station.dart';
import '../services/app_settings_service.dart';
import '../services/tv_service.dart';
import 'radio_player_screen.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

String formatTvGuideDateLabel(DateTime date, DateTime today) {
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final normalizedDate = DateTime(date.year, date.month, date.day);
  final diff = normalizedDate.difference(normalizedToday).inDays;
  if (diff == -1) return 'Ieri';
  if (diff == 0) return 'Oggi';
  if (diff == 1) return 'Domani';
  if (diff == 2) return 'Dopodomani';

  const weekdays = [
    'Lunedì',
    'Martedì',
    'Mercoledì',
    'Giovedì',
    'Venerdì',
    'Sabato',
    'Domenica',
  ];
  const months = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];
  return '${weekdays[normalizedDate.weekday - 1]} '
      '${normalizedDate.day} ${months[normalizedDate.month - 1]}';
}

Future<DateTime?> showTvDaySelectionDialog(
  BuildContext context, {
  required DateTime selectedDate,
  required DateTime today,
  required String Function(DateTime date) labelForDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Scegli giorno'),
      content: RadioGroup<DateTime>(
        groupValue: selectedDate,
        onChanged: (value) {
          if (value != null) Navigator.pop(dialogContext, value);
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(7, (index) => index - 1).map((offset) {
              final date = today.add(Duration(days: offset));
              return RadioListTile<DateTime>(
                title: Text(labelForDate(date)),
                value: date,
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

Future<void> showTvProgramDetailsDialog(
  BuildContext context,
  TvProgram program,
) {
  final l10n = AppLocalizations.of(context);
  final description = program.description.trim();
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                key: const ValueKey('tv_program_details_back_semantics'),
                container: true,
                button: true,
                label: l10n.back,
                sortKey: const OrdinalSortKey(1),
                onTap: () => Navigator.pop(dialogContext),
                child: ExcludeSemantics(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      autofocus: true,
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(l10n.back),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Semantics(
                key: const ValueKey('tv_program_details_title_semantics'),
                container: true,
                sortKey: const OrdinalSortKey(2),
                header: true,
                label: program.title,
                child: ExcludeSemantics(
                  child: Text(
                    program.title,
                    style: Theme.of(dialogContext).textTheme.headlineSmall,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: useSharedAccessibleViewModel
                    ? UniversalAccessibleList(
                        sections: [AccessibleListSection(rows: [
                          AccessibleListRow(
                            id: 'description',
                            kind: 'text',
                            title: description.isEmpty
                                ? l10n.noPodcastDescription
                                : description,
                            flutterChild: Semantics(
                              key: const ValueKey(
                                'tv_program_details_description_semantics',
                              ),
                              container: true,
                              sortKey: const OrdinalSortKey(3),
                              label: description.isEmpty
                                  ? l10n.noPodcastDescription
                                  : description,
                              child: ExcludeSemantics(
                                child: SingleChildScrollView(
                                  child: Text(
                                    description.isEmpty
                                        ? l10n.noPodcastDescription
                                        : description,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ])],
                        onEvent: (_) {},
                      )
                    : Semantics(
                        key: const ValueKey(
                          'tv_program_details_description_semantics',
                        ),
                        container: true,
                        sortKey: const OrdinalSortKey(3),
                        label: description.isEmpty
                            ? l10n.noPodcastDescription
                            : description,
                        child: ExcludeSemantics(
                          child: SingleChildScrollView(
                            child: Text(
                              description.isEmpty
                                  ? l10n.noPodcastDescription
                                  : description,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class TvChannelScreen extends StatefulWidget {
  final TvChannel channel;
  final bool autoPlay;

  const TvChannelScreen({
    super.key,
    required this.channel,
    this.autoPlay = false,
  });

  @override
  State<TvChannelScreen> createState() => _TvChannelScreenState();
}

class _TvChannelScreenState extends State<TvChannelScreen> {
  final _settings = AppSettingsService();
  final _service = TvService();

  List<TvProgram> _guide = [];
  bool _loading = true;
  String? _error;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadGuide();
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play();
      });
    }
  }

  Future<void> _loadGuide() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code = await _settings.getTvSecretCode();
      final guide = await _service.loadChannelGuide(
        _service.guideChannelName(widget.channel),
        code,
        targetDate: _selectedDate,
      );
      if (!mounted) return;
      setState(() {
        _guide = guide;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossibile caricare la guida TV per ${widget.channel.name}.';
        _loading = false;
      });
    }
  }

  String _getLabelForDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return formatTvGuideDateLabel(d, today);
  }

  Future<void> _selectDay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final selected = await showTvDaySelectionDialog(
      context,
      selectedDate: _selectedDate,
      today: today,
      labelForDate: _getLabelForDate,
    );

    if (selected != null && selected != _selectedDate) {
      setState(() => _selectedDate = selected);
      _loadGuide();
    }
  }

  Future<void> _showProgramDetails(TvProgram program) {
    return showTvProgramDetailsDialog(context, program);
  }

  Future<void> _play() async {
    try {
      final isRaiAd = _service.isRaiAudioDescriptionChannel(widget.channel);

      // Il player mobile riceve sempre il master RAI. Quando il canale può
      // avere l'audiodescrizione, RadioPlayerScreen apre il master con MediaKit
      // e seleziona la traccia "des" se presente, anche con il video disattivato.
      // Evitiamo così di aprire direttamente la playlist audio figlia, che su
      // alcuni stream (in particolare Rai 1) può richiedere il contesto della
      // richiesta al master e rispondere con accesso negato.
      final resolvedUrl = await _service.resolveStreamUrl(widget.channel);

      if (!mounted) return;

      if (Platform.isWindows) {
        await _playWithExternalWindowsPlayer(
          resolvedUrl,
          preferAudioDescription: isRaiAd,
        );
        return;
      }

      final station = RadioStation(
        name: widget.channel.name,
        streamUrl: resolvedUrl,
        languageCode: 'it',
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/tv/channel/player'),
          builder: (_) => RadioPlayerScreen(
            station: station,
            isVideoSupported: true,
            tvChannel: widget.channel,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showStatusMessage(context, 'Impossibile avviare la diretta: $e');
    }
  }

  Future<void> _playWithExternalWindowsPlayer(
    String url, {
    required bool preferAudioDescription,
  }) async {
    final ffplayArgs = [
      '-user_agent',
      widget.channel.playbackUserAgent,
      if (preferAudioDescription) ...['-ast', 'a:2'],
      '-nodisp',
      '-loglevel',
      'warning',
      url,
    ];
    try {
      await Process.start(
        'ffplay.exe',
        ffplayArgs,
        mode: ProcessStartMode.detached,
      );
      return;
    } on ProcessException {
      // Continue with VLC fallback below.
    }

    const vlcPaths = [
      r'C:\Program Files\VideoLAN\VLC\vlc.exe',
      r'C:\Program Files (x86)\VideoLAN\VLC\vlc.exe',
    ];
    for (final path in vlcPaths) {
      if (await File(path).exists()) {
        await Process.start(path, [
          '--http-user-agent=${widget.channel.playbackUserAgent}',
          if (preferAudioDescription) '--audio-track=2',
          url,
        ], mode: ProcessStartMode.detached);
        return;
      }
    }

    throw Exception('ffplay o VLC non trovato per riprodurre la diretta.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.channel.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              hint: 'Guarda ${widget.channel.name} in diretta',
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                ),
                onPressed: _play,
                icon: const Icon(Icons.play_circle_fill, size: 32),
                label: const Text(
                  'Riproduci Diretta',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: _selectDay,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                'Giorno: ${_getLabelForDate(_selectedDate)}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Caricamento guida in corso',
                    ),
                  )
                : _error != null
                ? Center(child: Text(_error!))
                : _guide.isEmpty
                ? const Center(
                    child: Text('Nessun programma trovato per oggi.'),
                  )
                : useSharedAccessibleViewModel
                    ? UniversalAccessibleList(
                        key: ValueKey('shared-tv-guide-${widget.channel.name}-${_selectedDate.toIso8601String()}-${_guide.length}'),
                        sections: [
                          AccessibleListSection(
                            rows: _guide.map((program) {
                              final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                              final isCurrent = program.startTime <= now && program.endTime > now;
                              return AccessibleListRow(
                                id: '${program.startTime}',
                                title: '${program.hour} ${program.title}',
                                subtitle: isCurrent ? 'In onda adesso' : null,
                                selected: isCurrent,
                                kind: 'action',
                              );
                            }).toList(),
                          ),
                        ],
                        onEvent: (event) {
                          if (event.type != 'activate' || event.id == null) return;
                          final start = int.tryParse(event.id!);
                          final index = _guide.indexWhere((e) => e.startTime == start);
                          if (index >= 0) _showProgramDetails(_guide[index]);
                        },
                      )
                    : ListView.builder(
                    itemCount: _guide.length,
                    itemBuilder: (context, index) {
                      final program = _guide[index];
                      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                      final isCurrent =
                          program.startTime <= now && program.endTime > now;

                      return ListTile(
                        tileColor: isCurrent
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        leading: Text(
                          program.hour,
                          style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 16,
                          ),
                        ),
                        title: Text(
                          program.title,
                          style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isCurrent
                            ? const Icon(Icons.live_tv, color: Colors.red)
                            : null,
                        onTap: () => _showProgramDetails(program),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
