import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class VoiceOverListTestScreen extends StatefulWidget {
  const VoiceOverListTestScreen({super.key});

  @override
  State<VoiceOverListTestScreen> createState() =>
      _VoiceOverListTestScreenState();
}

class _VoiceOverListTestScreenState extends State<VoiceOverListTestScreen> {
  static const _rowCount = 300;
  static const _rowExtent = 72.0;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _semanticScroll(double delta) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.voiceOverListTestTitle),
      ),
      body: SafeArea(
        child: Platform.isIOS
            ? const UiKitView(
                viewType: 'sonarpad/native_voiceover_list',
              )
            : Semantics(
                container: true,
                explicitChildNodes: true,
                onScrollUp: () => _semanticScroll(8 * _rowExtent),
                onScrollDown: () => _semanticScroll(-8 * _rowExtent),
                child: ListView.builder(
                  controller: _scrollController,
                  primary: false,
                  addSemanticIndexes: false,
                  itemExtent: _rowExtent,
                  itemCount: _rowCount,
                  semanticChildCount: _rowCount,
                  itemBuilder: (context, index) {
                    final number = index + 1;
                    final rowLabel =
                        l10n.voiceOverListTestRow(number, _rowCount);
                    final rowContent = l10n.voiceOverListTestContent(number);

                    return IndexedSemantics(
                      index: index,
                      child: Semantics(
                        container: true,
                        label: '$rowLabel, $rowContent',
                        child: ExcludeSemantics(
                          child: ListTile(
                            title: Text(rowLabel),
                            subtitle: Text(rowContent),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
