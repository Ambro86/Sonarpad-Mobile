import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'universal_accessible_view.dart';

List<AccessibleCustomAction> favoriteReorderActions(
  AppLocalizations l,
  int index,
  int count,
) => [
  if (index > 0) AccessibleCustomAction(id: 'move_up', label: l.moveUp),
  if (index + 1 < count)
    AccessibleCustomAction(id: 'move_down', label: l.moveDown),
  if (count > 1)
    AccessibleCustomAction(id: 'move_position', label: l.moveToPosition),
  if (count > 1)
    AccessibleCustomAction(
      id: 'sort_favorites',
      label: l.favoritesSortAlphabetically,
    ),
];
List<AccessibleVisualAction> favoriteReorderVisuals(
  AppLocalizations l,
  int index,
  int count,
) => favoriteReorderActions(l, index, count)
    .map(
      (a) => AccessibleVisualAction(
        id: a.id,
        label: a.label,
        icon: a.id == 'move_up'
            ? 'move_up'
            : a.id == 'move_down'
            ? 'move_down'
            : 'list',
      ),
    )
    .toList();
Widget favoriteReorderButtons(
  AppLocalizations l,
  int index,
  int count,
  void Function(String) onAction,
) => ExcludeSemantics(
  child: Wrap(
    children: [
      for (final a in favoriteReorderActions(l, index, count))
        IconButton(
          tooltip: a.label,
          icon: Icon(
            a.id == 'move_up'
                ? Icons.arrow_upward
                : a.id == 'move_down'
                ? Icons.arrow_downward
                : a.id == 'move_position'
                ? Icons.format_list_numbered
                : Icons.sort_by_alpha,
          ),
          onPressed: () => onAction(a.id),
        ),
    ],
  ),
);

Future<List<T>?> reorderFavorites<T>(
  BuildContext context,
  List<T> items,
  int index,
  String action,
  String Function(T) title,
) async {
  if (index < 0 || index >= items.length) return null;
  final result = List<T>.of(items);
  if (action == 'sort_favorites') {
    // Original index breaks ties, so equal titles retain their relative order.
    final indexed = items.asMap().entries.toList()
      ..sort((a, b) {
        final order = title(
          a.value,
        ).trim().toLowerCase().compareTo(title(b.value).trim().toLowerCase());
        return order != 0 ? order : a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).toList();
  }
  int? target;
  if (action == 'move_up') target = index - 1;
  if (action == 'move_down') target = index + 1;
  if (action == 'move_position') {
    final names = items.map(title).toList()..removeAt(index);
    var position = index;
    target = await showDialog<int>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setState) {
          final l = AppLocalizations.of(dialog);
          String label(int i) => i >= names.length
              ? l.positionLabelLast
              : l.positionLabel(i + 1, names[i]);
          return AlertDialog(
            title: Text(l.moveToPosition),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(child: Text(label(position))),
                Semantics(
                  slider: true,
                  label: l.moveToPosition,
                  value: label(position),
                  increasedValue: label((position + 1).clamp(0, names.length)),
                  decreasedValue: label((position - 1).clamp(0, names.length)),
                  onIncrease: position < names.length
                      ? () => setState(() => position++)
                      : null,
                  onDecrease: position > 0
                      ? () => setState(() => position--)
                      : null,
                  child: ExcludeSemantics(
                    child: Slider(
                      value: position.toDouble(),
                      min: 0,
                      max: names.length.toDouble(),
                      divisions: names.isEmpty ? null : names.length,
                      onChanged: (v) => setState(() => position = v.round()),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, position),
                child: Text(l.ok),
              ),
            ],
          );
        },
      ),
    );
  }
  if (target == null || target < 0 || target >= items.length || target == index) {
    return null;
  }
  result.insert(target, result.removeAt(index));
  return result;
}
