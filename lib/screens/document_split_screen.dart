import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/document_item.dart';
import '../services/document_library_service.dart';
import '../utils/status_message.dart';
import '../widgets/universal_accessible_view.dart';

class DocumentSplitScreen extends StatefulWidget {
  const DocumentSplitScreen({
    super.key,
    required this.document,
    required this.text,
  });

  final DocumentItem document;
  final String text;

  @override
  State<DocumentSplitScreen> createState() => _DocumentSplitScreenState();
}

class _DocumentSplitScreenState extends State<DocumentSplitScreen> {
  static const _partCounts = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  static const _characterCounts = [100, 200, 500, 1000, 2000, 5000, 10000];
  bool _byParts = true;
  int _partIndex = 1;
  int _characterIndex = 0;
  String _customParts = '', _customCharacters = '';
  bool _saving = false;

  AccessibleListRow _slider(
    String id,
    String title,
    List<String> labels,
    int index,
    ValueChanged<int> change,
  ) {
    final last = labels.length - 1;
    return AccessibleListRow(
      id: id,
      title: title,
      kind: 'slider',
      enabled: !_saving,
      accessibilityButtonTrait: false,
      value: index.toString(),
      valueLabel: labels[index],
      sliderMin: 0,
      sliderMax: last.toDouble(),
      sliderStep: 1,
      sliderValue: index.toDouble(),
      sliderIncreasedValueLabel: labels[(index + 1).clamp(0, last)],
      sliderDecreasedValueLabel: labels[(index - 1).clamp(0, last)],
      options: [
        for (var i = 0; i <= last; i++)
          AccessibleOption(value: i, label: labels[i]),
      ],
      onValueChanged: (raw) {
        final number = double.tryParse('$raw');
        if (_saving || number == null || !number.isFinite) return;
        final next = number.round().clamp(0, last);
        if (next != index) setState(() => change(next));
      },
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = AppLocalizations.of(context);
    final choices = _byParts ? _partCounts : _characterCounts;
    final index = _byParts ? _partIndex : _characterIndex;
    final value = index < choices.length
        ? choices[index]
        : int.tryParse((_byParts ? _customParts : _customCharacters).trim());
    final length = widget.text.characters.length;
    if (value == null || value < 1 || (_byParts && value > length)) {
      showStatusMessage(context, l.splitRange(length));
      return;
    }
    setState(() => _saving = true);
    try {
      final count = await DocumentLibraryService().saveSplitDocument(
        widget.document,
        widget.text,
        byParts: _byParts,
        value: value,
      );
      if (mounted) Navigator.of(context).pop(count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showStatusMessage(context, l.saveError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final choices = _byParts ? _partCounts : _characterCounts;
    final index = _byParts ? _partIndex : _characterIndex;
    final label = _byParts ? l.splitPartCount : l.splitCharacterCount;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(l.splitDocument)),
        body: SafeArea(
          child: UniversalAccessibleList(
            transientRowIds: const [
              'split-parts',
              'split-characters',
              'custom-parts',
              'custom-characters',
            ],
            sections: [
              AccessibleListSection(
                rows: [
                  _slider(
                    'split-method',
                    l.splitMethod,
                    [l.splitByParts, l.splitByCharacters],
                    _byParts ? 0 : 1,
                    (i) => _byParts = i == 0,
                  ),
                  _slider(
                    _byParts ? 'split-parts' : 'split-characters',
                    label,
                    [...choices.map((n) => n.toString()), l.splitCustom],
                    index,
                    (i) {
                      if (_byParts) {
                        _partIndex = i;
                      } else {
                        _characterIndex = i;
                      }
                    },
                  ),
                  if (index == choices.length)
                    AccessibleListRow(
                      id: _byParts ? 'custom-parts' : 'custom-characters',
                      kind: 'textField',
                      title: '$label (${l.splitCustom})',
                      keyboardType: 'number',
                      enabled: !_saving,
                      textInputAction: 'done',
                      value: _byParts ? _customParts : _customCharacters,
                      onValueChanged: (raw) {
                        if (_byParts) {
                          _customParts = raw?.toString() ?? '';
                        } else {
                          _customCharacters = raw?.toString() ?? '';
                        }
                      },
                    ),
                  AccessibleListRow(
                    id: 'save-parts',
                    title: l.splitDocument,
                    enabled: !_saving,
                    finishEditingOnActivate: true,
                    onActivate: _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
