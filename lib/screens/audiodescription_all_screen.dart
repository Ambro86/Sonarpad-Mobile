import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import '../services/audiodescription_service.dart';
import 'audiodescription_film_screen.dart';
import 'audiodescription_series_screen.dart';
import '../utils/status_message.dart';

class AudiodescriptionAllScreen extends StatefulWidget {
  const AudiodescriptionAllScreen({super.key});

  @override
  State<AudiodescriptionAllScreen> createState() =>
      _AudiodescriptionAllScreenState();
}

class _AudiodescriptionAllScreenState extends State<AudiodescriptionAllScreen> {
  final _service = AudiodescriptionService();

  List<AudiodescriptionGroup> _groups = [];
  List<AudiodescriptionGroup> _filteredGroups = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final code = await AppSettingsService().getTvSecretCode();
      final groups = await _service.fetchGroupedCatalog(code);
      if (mounted) {
        setState(() {
          _groups = groups;
          _filteredGroups = groups
              .where((g) => g.title != 'Film')
              .toList(); // Nascondiamo Film dalla lista principale
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _onSearch(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredGroups = _groups.where((g) => g.title != 'Film').toList();
      } else {
        final q = query.trim().toLowerCase();
        _filteredGroups = _groups
            .where(
                (g) => g.title != 'Film' && g.title.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.audiodescriptionAll),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.audiodescriptionSearch,
                filled: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _onSearch,
            ),
          ),
        ),
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredGroups.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          leading: const Icon(Icons.movie),
                          title: Text(l10n.audiodescriptionFilm,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // Passa il gruppo film se presente
                            final filmGroup = _groups
                                .where((g) => g.title == 'Film')
                                .firstOrNull;
                            if (filmGroup != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  settings: const RouteSettings(
                                      name: '/audiodescriptions/film'),
                                  builder: (_) => AudiodescriptionFilmScreen(
                                      filmGroup: filmGroup),
                                ),
                              );
                            } else {
                                                            showStatusMessage(context, l10n.audiodescriptionEmpty);
                            }
                          },
                        ),
                      );
                    }

                    final group = _filteredGroups[index - 1];
                    return ListTile(
                      title: Text(group.title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(
                                name: '/audiodescriptions/series'),
                            builder: (_) =>
                                AudiodescriptionSeriesScreen(group: group),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
