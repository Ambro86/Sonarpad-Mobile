import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/audiodescription_service.dart';

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
                                child: Text(
                                  day.label,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              ...day.programs.map((program) {
                                return Card(
                                  child: Semantics(
                                    label: program.voiceText,
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
