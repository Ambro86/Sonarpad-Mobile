import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/status_message.dart';

/// One accessible command for the current collection, with confirmation.
class ClearFavoritesButton extends StatefulWidget {
  const ClearFavoritesButton({
    super.key,
    required this.onClear,
    this.label,
    this.confirmation,
  });

  final Future<void> Function() onClear;
  final String? label;
  final String? confirmation;

  @override
  State<ClearFavoritesButton> createState() => _ClearFavoritesButtonState();
}

class _ClearFavoritesButtonState extends State<ClearFavoritesButton> {
  bool _busy = false;

  Future<void> _clear() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.label ?? l10n.clearFavorites),
          content: Text(widget.confirmation ?? l10n.confirmClearFavorites),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(widget.label ?? l10n.clearFavorites),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) await widget.onClear();
    } catch (_) {
      if (mounted) showStatusMessage(context, l10n.technicalErrorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: widget.label ?? AppLocalizations.of(context).clearFavorites,
    icon: const Icon(Icons.delete_sweep),
    onPressed: _busy ? null : _clear,
  );
}
