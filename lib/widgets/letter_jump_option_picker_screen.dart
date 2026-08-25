import 'package:flutter/material.dart';

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
  bool get _showLetterPicker =>
      widget.options.length >= widget.minimumItemsForLetterPicker &&
      _availableLetters().length > 1;

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

  List<T> _optionsForLetter(String letter) {
    return widget.options
        .where(
          (option) => _initialLetter(widget.labelBuilder(option)) == letter,
        )
        .toList(growable: false);
  }

  Future<void> _openLetterPicker() async {
    final selected = await Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (_) => _LetterPickerScreen<T>(
          title: widget.selectLetterTitle,
          letters: _availableLetters(),
          filteredTitle: widget.title,
          optionsForLetter: _optionsForLetter,
          displayLabelBuilder: _displayLabel,
          selectedBuilder: widget.selectedBuilder,
          leadingBuilder: widget.leadingBuilder,
        ),
      ),
    );
    if (!mounted || selected == null) return;

    Navigator.pop(context, selected);
  }

  String _displayLabel(T option) {
    final selected = widget.selectedBuilder?.call(option) ?? false;
    final label = widget.labelBuilder(option);
    return selected && widget.selectedLabel != null
        ? '$label, ${widget.selectedLabel}'
        : label;
  }

  @override
  Widget build(BuildContext context) {
    final showLetterPicker = _showLetterPicker;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !canPop,
        leading: canPop ? const BackButton() : null,
        title: Text(widget.title),
      ),
      body: useSharedAccessibleViewModel
          ? UniversalAccessibleList(
              sections: [
                AccessibleListSection(
                  rows: [
                    if (showLetterPicker)
                      AccessibleListRow(
                        id: 'select_letter',
                        title: widget.selectLetterLabel,
                      ),
                    ...widget.options.asMap().entries.map((entry) {
                      final selected =
                          widget.selectedBuilder?.call(entry.value) ?? false;
                      return AccessibleListRow(
                        id: 'option_${entry.key}',
                        title: _displayLabel(entry.value),
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
                  if (index != null &&
                      index >= 0 &&
                      index < widget.options.length &&
                      mounted) {
                    Navigator.pop(context, widget.options[index]);
                  }
                }
              },
            )
          : ListView.separated(
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
                final selected =
                    widget.selectedBuilder?.call(option) ?? false;
                return ListTile(
                  leading: widget.leadingBuilder?.call(selected) ??
                      Icon(selected ? Icons.check : Icons.radio),
                  title: Text(_displayLabel(option)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, option),
                );
              },
            ),
    );
  }
}

class _LetterPickerScreen<T> extends StatelessWidget {
  final String title;
  final List<String> letters;
  final String filteredTitle;
  final List<T> Function(String letter) optionsForLetter;
  final String Function(T) displayLabelBuilder;
  final bool Function(T)? selectedBuilder;
  final Widget Function(bool selected)? leadingBuilder;

  const _LetterPickerScreen({
    required this.title,
    required this.letters,
    required this.filteredTitle,
    required this.optionsForLetter,
    required this.displayLabelBuilder,
    this.selectedBuilder,
    this.leadingBuilder,
  });

  Future<void> _openLetter(BuildContext context, String letter) async {
    final options = optionsForLetter(letter);
    if (options.isEmpty) return;

    final selected = await Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (_) => _LetterFilteredOptionsScreen<T>(
          title: filteredTitle,
          options: options,
          displayLabelBuilder: displayLabelBuilder,
          selectedBuilder: selectedBuilder,
          leadingBuilder: leadingBuilder,
        ),
      ),
    );
    if (!context.mounted || selected == null) return;

    Navigator.pop(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? UniversalAccessibleList(
                sections: [
                  AccessibleListSection(
                    rows: [
                      for (var index = 0; index < letters.length; index++)
                        AccessibleListRow(
                          id: 'letter_$index',
                          title: letters[index],
                        ),
                    ],
                  ),
                ],
                onEvent: (event) async {
                  if (event.type != 'activate' || event.id == null) return;
                  final index = int.tryParse(
                    event.id!.replaceFirst('letter_', ''),
                  );
                  if (index != null && index >= 0 && index < letters.length) {
                    await _openLetter(context, letters[index]);
                  }
                },
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: letters.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => ListTile(
                  leading: const Icon(Icons.sort_by_alpha),
                  title: Text(letters[index]),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openLetter(context, letters[index]),
                ),
              ),
      ),
    );
  }
}

class _LetterFilteredOptionsScreen<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final String Function(T) displayLabelBuilder;
  final bool Function(T)? selectedBuilder;
  final Widget Function(bool selected)? leadingBuilder;

  const _LetterFilteredOptionsScreen({
    required this.title,
    required this.options,
    required this.displayLabelBuilder,
    this.selectedBuilder,
    this.leadingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final backLabel = MaterialLocalizations.of(context).backButtonTooltip;
    final flutterRows = <Widget>[
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          label: Text(backLabel),
        ),
      ),
      Semantics(
        header: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
    ];
    final accessibleRows = <AccessibleListRow>[
      AccessibleListRow(
        id: 'back',
        title: backLabel,
        kind: 'button',
        flutterChild: flutterRows[0],
      ),
      AccessibleListRow(
        id: 'title',
        title: title,
        kind: 'text',
        accessibilityButtonTrait: false,
        flutterChild: flutterRows[1],
      ),
    ];

    for (var index = 0; index < options.length; index++) {
      final option = options[index];
      final selected = selectedBuilder?.call(option) ?? false;
      final label = displayLabelBuilder(option);
      final child = Card(
        child: ListTile(
          leading: leadingBuilder?.call(selected) ??
              Icon(selected ? Icons.check : Icons.radio),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(context, option),
        ),
      );
      flutterRows.add(child);
      accessibleRows.add(
        AccessibleListRow(
          id: 'option_$index',
          title: label,
          selected: selected,
          flutterChild: child,
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: useSharedAccessibleViewModel
            ? UniversalAccessibleList(
                sections: [AccessibleListSection(rows: accessibleRows)],
                onEvent: (event) {
                  if (event.type != 'activate' || event.id == null) return;
                  if (event.id == 'back') {
                    Navigator.pop(context);
                  } else if (event.id!.startsWith('option_')) {
                    final index = int.tryParse(event.id!.substring(7));
                    if (index != null && index >= 0 && index < options.length) {
                      Navigator.pop(context, options[index]);
                    }
                  }
                },
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: flutterRows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) => flutterRows[index],
              ),
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
