import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class DocumentPasswordDialog extends StatefulWidget {
  const DocumentPasswordDialog({
    super.key,
    required this.title,
    required this.prompt,
    required this.passwordLabel,
    required this.confirmPasswordLabel,
    required this.requiredMessage,
    required this.mismatchMessage,
    required this.invalidMessage,
    this.requireConfirmation = false,
    this.validator,
    this.initialError,
  });

  final String? initialError;
  final String title;
  final String prompt;
  final String passwordLabel;
  final String confirmPasswordLabel;
  final String requiredMessage;
  final String mismatchMessage;
  final String invalidMessage;
  final bool requireConfirmation;
  final bool Function(String password)? validator;

  @override
  State<DocumentPasswordDialog> createState() => _DocumentPasswordDialogState();
}

class _DocumentPasswordDialogState extends State<DocumentPasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text;
    if (password.trim().isEmpty) {
      setState(() => _error = widget.requiredMessage);
      return;
    }
    if (widget.requireConfirmation &&
        password != _confirmationController.text) {
      setState(() => _error = widget.mismatchMessage);
      return;
    }
    final validator = widget.validator;
    if (validator != null && !validator(password)) {
      setState(() => _error = widget.invalidMessage);
      return;
    }
    Navigator.pop(context, password);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.prompt),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              autofocus: true,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: widget.requireConfirmation
                  ? TextInputAction.next
                  : TextInputAction.done,
              decoration: InputDecoration(labelText: widget.passwordLabel),
              onSubmitted: widget.requireConfirmation ? null : (_) => _submit(),
            ),
            if (widget.requireConfirmation) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _confirmationController,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: widget.confirmPasswordLabel,
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.ok)),
      ],
    );
  }
}
