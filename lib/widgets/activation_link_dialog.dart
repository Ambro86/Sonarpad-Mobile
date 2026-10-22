import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/activation_link_service.dart';
import '../utils/app_logger.dart';

class ActivationLinkDialog extends StatefulWidget {
  const ActivationLinkDialog({super.key, required this.uri, this.service});
  final Uri uri;
  final ActivationLinkService? service;

  @override
  State<ActivationLinkDialog> createState() => _ActivationLinkDialogState();
}

class _ActivationLinkDialogState extends State<ActivationLinkDialog> {
  bool _busy = true;
  bool _success = false;
  bool _malformed = false;

  @override
  void initState() {
    super.initState();
    _activate();
  }

  Future<void> _activate() async {
    try {
      await (widget.service ?? ActivationLinkService()).activate(widget.uri);
      _success = true;
      unawaited(AppLogger.log('Activation link: code validated and saved'));
    } catch (error) {
      _malformed = error is FormatException;
      // Never log the URI, code or exception: they may contain the credential.
      unawaited(AppLogger.log('Activation link: activation unsuccessful'));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = _success
        ? l10n.sonarpadCodeValidMessage
        : _malformed
        ? l10n.sonarpadCodeInvalidMessage
        : l10n.technicalErrorGeneric;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(
          _busy
              ? l10n.loading
              : _success
              ? l10n.sonarpadCodeValidTitle
              : l10n.sonarpadCodeInvalidTitle,
        ),
        content: _busy
            ? CircularProgressIndicator(semanticsLabel: l10n.loading)
            : Semantics(liveRegion: true, child: Text(message)),
        actions: _busy
            ? []
            : [
                FilledButton(
                  autofocus: true,
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.ok),
                ),
              ],
      ),
    );
  }
}
