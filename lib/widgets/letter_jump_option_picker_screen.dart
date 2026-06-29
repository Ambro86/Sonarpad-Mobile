import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

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
    for (var index = 0; index < widget.options.length; index++) {
      final optionLetter = _initialLetter(widget.labelBuilder(widget.options[index]));
      if (optionLetter == letter) return index;
    }
    return null;
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

    final listIndex = index + (_showLetterPicker ? 1 : 0);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || !_scrollController.hasClients) return;

    await _scrollController.scrollToIndex(
      listIndex,
      preferPosition: AutoScrollPosition.begin,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showLetterPicker = _showLetterPicker;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView.separated(
        controller: _scrollController,
        itemCount: widget.options.length + (showLetterPicker ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
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
      body: ListView.separated(
        itemCount: letters.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
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
