import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/audiodescription_service.dart';
import '../widgets/universal_accessible_view.dart';

const _scheduledAudiodescriptionsTitle = 'Audiodescrizioni in programma';
const _scheduledAudiodescriptionsEmpty =
    'Nessuna audiodescrizione in programma al momento.';

class AudiodescriptionScheduledScreen extends StatefulWidget {
  const AudiodescriptionScheduledScreen({super.key});

  @override
  State<AudiodescriptionScheduledScreen> createState() =>
      _AudiodescriptionScheduledScreenState();
}

class _AudiodescriptionScheduledScreenState
    extends State<AudiodescriptionScheduledScreen> {
  final _service = AudiodescriptionService();

  List<AudiodescriptionScheduledDay> _days = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final days = await _service.fetchScheduledCatalog();
      if (!mounted) return;
      setState(() {
        _days = days;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _programVoiceLabel(AudiodescriptionScheduledProgram program) {
    final parts = <String>[];
    if (program.time.isNotEmpty) {
      parts.add('Alle ${program.time}');
    }
    if (program.channel.isNotEmpty) {
      parts.add(program.channel);
    }
    if (program.title.isNotEmpty) {
      parts.add(program.title);
    }
    if (parts.isEmpty) {
      return program.voiceText;
    }
    final text = parts.join(', ');
    return text.endsWith('.') ? text : '$text.';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(_scheduledAudiodescriptionsTitle),
        actions: [
          IconButton(
            tooltip: l10n.update,
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.audiodescriptionLoading),
                ],
              ),
            )
          : _error.isNotEmpty
              ? Center(child: Text('${l10n.audiodescriptionError}: $_error'))
              : _days.isEmpty
                  ? const Center(child: Text(_scheduledAudiodescriptionsEmpty))
                  : useSharedAccessibleViewModel
                      ? UniversalAccessibleList(
                          refreshEnabled: true,
                          sections: _days
                              .map((day) => AccessibleListSection(
                                    header: day.label,
                                    rows: day.programs
                                        .asMap()
                                        .entries
                                        .map((entry) => AccessibleListRow(
                                              id: 'program_${day.label}_${entry.key}',
                                              title: '${entry.value.time} - ${entry.value.channel}'.trim(),
                                              subtitle: entry.value.title,
                                              accessibilityLabel: _programVoiceLabel(entry.value),
                                              kind: 'text',
                                            ))
                                        .toList(growable: false),
                                  ))
                              .toList(growable: false),
                          onEvent: (event) async {
                            if (event.type == 'refresh') await _load();
                          },
                        )
                      : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _days.length,
                        itemBuilder: (context, dayIndex) {
                          final day = _days[dayIndex];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 8, bottom: 8),
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    day.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                              ),
                              ...day.programs.map((program) {
                                return Card(
                                  child: Semantics(
                                    label: _programVoiceLabel(program),
                                    child: ExcludeSemantics(
                                      child: ListTile(
                                        leading:
                                            const Icon(Icons.accessibility_new),
                                        title: Text(
                                          '${program.time} - ${program.channel}'
                                              .trim(),
                                        ),
                                        subtitle: Text(program.title),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ),
    );
  }
}
