import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import 'universal_accessible_view.dart';

class LetterJumpOptionPickerScreen<T> extends StatefulWidget {
  final String title;
  final List<T> options;
  final String Function(T) labelBuilder;
  final bool Function(T)? selectedBuilder;
  final String? selectedLabel;
  final Widget Function(bool selected)? leadingBuilder;
  final String selectLetterLabel;
  final String selectLetterTitle;
  final int minimumItemsForLetterPicker;

  const LetterJumpOptionPickerScreen({
    super.key,
    required this.title,
    required this.options,
    required this.labelBuilder,
    this.selectedBuilder,
    this.selectedLabel,
    this.leadingBuilder,
    required this.selectLetterLabel,
    required this.selectLetterTitle,
    this.minimumItemsForLetterPicker = 12,
  });

  @override
  State<LetterJumpOptionPickerScreen<T>> createState() =>
      _LetterJumpOptionPickerScreenState<T>();
}

class _LetterJumpOptionPickerScreenState<T>
    extends State<LetterJumpOptionPickerScreen<T>> {
  final _scrollController = AutoScrollController();
  final _accessibleController = AccessibleListController(debugName: 'letter_jump');

  bool get _showLetterPicker =>
      widget.options.length >= widget.minimumItemsForLetterPicker &&
      _availableLetters().length > 1;


  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _availableLetters() {
    final letters = <String>{};
    for (final option in widget.options) {
      final letter = _initialLetter(widget.labelBuilder(option));
      if (letter != null && letter.isNotEmpty) {
        letters.add(letter);
      }
    }
    final sorted = letters.toList()..sort((a, b) => a.compareTo(b));
    return sorted;
  }

  int? _firstIndexForLetter(String letter) {
    int? selectedFallback;
    for (var index = 0; index < widget.options.length; index++) {
      final option = widget.options[index];
      final optionLetter = _initialLetter(widget.labelBuilder(option));
      if (optionLetter != letter) continue;

      // Several pickers pin the most recently selected option at the top
      // of the list. That row must not become the alphabetical anchor for
      // its letter (for example recent Italia before India/Indonesia).
      // Prefer the first ordinary option and use the selected one only when
      // it is the sole option available for that letter.
      final selected = widget.selectedBuilder?.call(option) ?? false;
      if (!selected) return index;
      selectedFallback ??= index;
    }
    return selectedFallback;
  }

  Future<void> _openLetterPicker() async {
    final letter = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _LetterPickerScreen(
          title: widget.selectLetterTitle,
          letters: _availableLetters(),
        ),
      ),
    );
    if (!mounted || letter == null) return;
    await _jumpToLetter(letter);
  }

  Future<void> _jumpToLetter(String letter) async {
    final index = _firstIndexForLetter(letter);
    if (index == null || index < 0 || index >= widget.options.length) return;

    if (useSharedAccessibleViewModel) {
      await _accessibleController.focusAccessibleRow(
        'option_$index',
        mode: AccessibleFocusMode.routeReturnJump,
      );
      return;
    }

    final listIndex = index + (_showLetterPicker ? 1 : 0);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _tryScrollToOptionIndex(listIndex);
  }

  Future<void> _tryScrollToOptionIndex(int listIndex, {int attempt = 0}) async {
    if (!mounted) return;

    if (!_scrollController.hasClients) {
      if (attempt < 3) {
        Future<void>.delayed(
          Duration(milliseconds: 250 + (attempt * 150)),
          () => _tryScrollToOptionIndex(listIndex, attempt: attempt + 1),
        );
      }
      return;
    }

    try {
      await _scrollController.scrollToIndex(
        listIndex,
        preferPosition: AutoScrollPosition.begin,
        duration: const Duration(milliseconds: 300),
      );

      // Dopo il ritorno dal selettore lettera, VoiceOver può restare
      // temporaneamente sulla AppBar. Ripetiamo solo lo scroll, senza
      // SemanticsService.announce e senza focus forzato.
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.scrollToIndex(
        listIndex,
        preferPosition: AutoScrollPosition.begin,
        duration: const Duration(milliseconds: 120),
      );
    } catch (_) {
      if (!mounted) return;
      if (attempt < 3) {
        Future<void>.delayed(
          Duration(milliseconds: 300 + (attempt * 200)),
          () => _tryScrollToOptionIndex(listIndex, attempt: attempt + 1),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showLetterPicker = _showLetterPicker;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              controller: _accessibleController,
              routeReturnSemanticsSettleDelay: Duration.zero,
              routeReturnUseFocusProxy: true,
              sections: [
                AccessibleListSection(
                  rows: [
                    if (showLetterPicker)
                      AccessibleListRow(
                        id: 'select_letter',
                        title: widget.selectLetterLabel,
                      ),
                    ...widget.options.asMap().entries.map((entry) {
                      final selected = widget.selectedBuilder?.call(entry.value) ?? false;
                      final label = widget.labelBuilder(entry.value);
                      final displayLabel = selected && widget.selectedLabel != null
                          ? '$label, ${widget.selectedLabel}'
                          : label;
                      return AccessibleListRow(
                        id: 'option_${entry.key}',
                        title: displayLabel,
                        selected: selected,
                      );
                    }),
                  ],
                ),
              ],
              onEvent: (event) async {
                if (event.type != 'activate' || event.id == null) return;
                if (event.id == 'select_letter') {
                  await _openLetterPicker();
                  return;
                }
                if (event.id!.startsWith('option_')) {
                  final index = int.tryParse(event.id!.substring(7));
                  if (index != null && index >= 0 && index < widget.options.length) {
                    if (mounted) Navigator.pop(context, widget.options[index]);
                  }
                }
              },
            )
          : ListView.separated(
        controller: _scrollController,
        itemCount: widget.options.length + (showLetterPicker ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (showLetterPicker && index == 0) {
            return ListTile(
              leading: const Icon(Icons.sort_by_alpha),
              title: Text(widget.selectLetterLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openLetterPicker,
            );
          }

          final optionIndex = index - (showLetterPicker ? 1 : 0);
          final option = widget.options[optionIndex];
          final selected = widget.selectedBuilder?.call(option) ?? false;
          final label = widget.labelBuilder(option);
          final displayLabel = selected && widget.selectedLabel != null
              ? '$label, ${widget.selectedLabel}'
              : label;
          return AutoScrollTag(
            key: ValueKey('letter_option_$index'),
            controller: _scrollController,
            index: index,
            child: ListTile(
              leading: widget.leadingBuilder?.call(selected) ??
                  Icon(selected ? Icons.check : Icons.radio),
              title: Text(displayLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, option),
            ),
          );
        },
      ),
    );
  }
}

class _LetterPickerScreen extends StatelessWidget {
  final String title;
  final List<String> letters;

  const _LetterPickerScreen({
    required this.title,
    required this.letters,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [
                AccessibleListSection(
                  rows: letters
                      .asMap()
                      .entries
                      .map((entry) => AccessibleListRow(
                            id: 'letter_${entry.key}',
                            title: entry.value,
                          ))
                      .toList(growable: false),
                ),
              ],
              onEvent: (event) {
                if (event.type != 'activate' || event.id == null) return;
                final index = int.tryParse(event.id!.replaceFirst('letter_', ''));
                if (index != null && index >= 0 && index < letters.length) {
                  Navigator.pop(context, letters[index]);
                }
              },
            )
          : ListView.separated(
        itemCount: letters.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final letter = letters[index];
          return ListTile(
            leading: const Icon(Icons.sort_by_alpha),
            title: Text(letter),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(context, letter),
          );
        },
      ),
    );
  }
}

String? _initialLetter(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  for (final rune in trimmed.runes) {
    if (!_isLetterCandidate(rune)) continue;
    final upper = String.fromCharCode(rune).toUpperCase();
    if (upper.isEmpty) continue;
    return String.fromCharCodes(upper.runes.take(1));
  }
  return null;
}

bool _isLetterCandidate(int rune) {
  final isDigit = rune >= 0x30 && rune <= 0x39;
  final isAsciiUpper = rune >= 0x41 && rune <= 0x5A;
  final isAsciiLower = rune >= 0x61 && rune <= 0x7A;
  final isLikelyNonAsciiLetter = rune > 0x7F;
  return isDigit || isAsciiUpper || isAsciiLower || isLikelyNonAsciiLetter;
}
