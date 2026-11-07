import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/cloud_sync_api.dart';
import '../services/cloud_sync_service.dart';
import '../widgets/universal_accessible_view.dart';

class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key, this.service});
  final CloudSyncService? service;
  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

enum _SyncPage { main, join, options }

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  late final _service = widget.service ?? CloudSyncService();
  _SyncPage _page = _SyncPage.main;
  final _code = TextEditingController();
  bool _busy = true;
  bool _connected = false;
  bool _preferences = true;
  bool _collections = true;
  String? _invitation;
  String? _status;
  Map<String, dynamic> _meta = {};

  @override
  void initState() {
    super.initState();
    CloudSyncService.changes.addListener(_refreshStatus);
    _load();
  }

  Future<void> _refreshStatus() async {
    try {
      final meta = await _service.metadata();
      if (mounted) setState(() => _meta = meta);
    } catch (_) {
      // The background service logs failures and retries without alerts.
    }
  }

  String _syncStatus(AppLocalizations l10n) {
    // Legacy removal reviews remain diagnostic data. The service repairs
    // unproven removals automatically; they are not a user-facing status.
    final message = CloudSyncService.busy
        ? l10n.cloudSyncWorking
        : !_preferences && !_collections
        ? l10n.cloudSyncPaused
        : CloudSyncService.automaticFailed
        ? l10n.cloudSyncRetrying
        : CloudSyncService.automaticPending || _meta['pending'] != null
        ? l10n.cloudSyncPending
        : _meta['last_sync'] != null
        ? l10n.cloudSyncUpToDate
        : l10n.cloudSyncPending;
    final last = DateTime.tryParse(
      _meta['last_sync'] as String? ?? '',
    )?.toLocal();
    if (last == null) return message;
    final date = MaterialLocalizations.of(context).formatShortDate(last);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(last));
    return '$message ${l10n.cloudSyncLastUpdate('$date $time')}';
  }

  Future<void> _load() async {
    try {
      final meta = await _service.metadata();
      if (mounted) {
        setState(() {
          _meta = meta;
          _connected = meta['group_id'] != null;
          _preferences = meta['sync_preferences'] != false;
          _collections = meta['sync_collections'] != false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || CloudSyncService.busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      try {
        await action();
      } on CloudSyncApiException catch (error) {
        if (error.code != 'deletion_confirmation_required') rethrow;
        if (mounted) setState(() => _status = l10n.cloudSyncRetrying);
        return;
      }
      if (mounted) setState(() => _status = l10n.cloudSyncDone);
    } catch (e) {
      if (mounted) {
        setState(
          () => _status =
              e is CloudSyncApiException &&
                  {'invalid_or_expired_code', 'invalid_code'}.contains(e.code)
              ? l10n.cloudSyncBadCode
              : l10n.cloudSyncFailed,
        );
      }
    } finally {
      await _load();
    }
  }

  Future<void> _disconnect() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cloudSyncDisconnect),
        content: Text(l10n.cloudSyncDisconnectConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.cloudSyncDisconnect),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() async {
        await _service.disconnect();
        _invitation = null;
        _page = _SyncPage.main;
      });
    }
  }

  @override
  void dispose() {
    CloudSyncService.changes.removeListener(_refreshStatus);
    _code.dispose();
    _service.api.close();
    super.dispose();
  }

  Future<void> _join() async {
    if (!RegExp(r'^\d{8}$').hasMatch(_code.text)) {
      setState(() => _status = AppLocalizations.of(context).cloudSyncBadCode);
      return;
    }
    await _run(() async {
      await _service.connect(code: _code.text);
      _page = _SyncPage.main;
      _code.clear();
    });
  }

  void _showPage(_SyncPage page) => setState(() {
    _page = page;
    _status = null;
  });

  Widget _accessibleBody(AppLocalizations l10n, bool busy) {
    AccessibleListRow text(String id, String title) => AccessibleListRow(
      id: id,
      title: title,
      kind: 'text',
      accessibilityButtonTrait: false,
    );
    AccessibleListRow button(String id, String title, VoidCallback action) =>
        AccessibleListRow(
          id: id,
          title: title,
          kind: 'button',
          enabled: !busy,
          onActivate: action,
        );
    return UniversalAccessibleList(
      sections: [
        AccessibleListSection(
          rows: [
            if (_busy) text('working', l10n.loading),
            if (_status != null) text('status', _status!),
            if (_page == _SyncPage.options) ...[
              text('options_help', l10n.cloudSyncOptionsHelp),
              AccessibleListRow(
                id: 'collections',
                title: l10n.cloudSyncCollections,
                kind: 'toggle',
                toggleValue: _collections,
                enabled: !busy,
                onValueChanged: (v) => _run(
                  () =>
                      _service.setScope(preferences: false, enabled: v == true),
                ),
              ),
              AccessibleListRow(
                id: 'preferences',
                title: l10n.cloudSyncPreferences,
                kind: 'toggle',
                toggleValue: _preferences,
                enabled: !busy,
                onValueChanged: (v) => _run(
                  () =>
                      _service.setScope(preferences: true, enabled: v == true),
                ),
              ),
              button('disconnect', l10n.cloudSyncDisconnect, _disconnect),
            ] else if (_page == _SyncPage.join) ...[
              text('join_help', l10n.cloudSyncJoinHelp),
              AccessibleListRow(
                id: 'code',
                title: l10n.cloudSyncCode,
                kind: 'textField',
                value: _code.text,
                enabled: !busy,
                keyboardType: 'number',
                textInputAction: 'done',
                onSubmitted: (_) {
                  if (!busy) _join();
                },
              ),
              button('join', l10n.cloudSyncJoin, _join),
            ] else if (_connected) ...[
              text('sync_status', _syncStatus(l10n)),
              text('automatic_help', l10n.cloudSyncAutomaticHelp),
              button(
                'sync',
                l10n.cloudSyncNow,
                () => _run(_service.synchronize),
              ),
              button(
                'invite',
                l10n.cloudSyncInvite,
                () => _run(() async {
                  _invitation = await _service.invitation();
                }),
              ),
              if (_invitation != null) ...[
                AccessibleListRow(
                  id: 'invitation',
                  title: _invitation!,
                  kind: 'text',
                  accessibilityButtonTrait: false,
                  accessibilityLabel:
                      '${l10n.cloudSyncCode}: ${_invitation!.split('').join(' ')}',
                ),
                text('code_help', l10n.cloudSyncCodeHelp),
              ],
              button(
                'options',
                l10n.cloudSyncOptions,
                () => _showPage(_SyncPage.options),
              ),
            ] else ...[
              text('first_help', l10n.cloudSyncFirstHelp),
              button(
                'create',
                l10n.cloudSyncCreate,
                () => _run(() async {
                  await _service.connect();
                  _invitation = await _service.invitation();
                }),
              ),
              button(
                'have_code',
                l10n.cloudSyncHaveCode,
                () => _showPage(_SyncPage.join),
              ),
            ],
          ],
        ),
      ],
      onEvent: (event) {
        if (event.id == 'code' && event.type == 'textChanged') {
          _code.text = event.value?.toString() ?? '';
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = _busy || CloudSyncService.busy;
    return PopScope(
      canPop: !_busy && _page == _SyncPage.main,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy && _page != _SyncPage.main) {
          _showPage(_SyncPage.main);
        }
      },
      child: Scaffold(
        appBar: SonarpadAppBar(
          title: Text(
            _page == _SyncPage.options
                ? l10n.cloudSyncOptions
                : l10n.cloudSyncTitle,
          ),
          leading: _page == _SyncPage.main
              ? null
              : SonarpadBackButton(
                  onPressed: _busy ? null : () => _showPage(_SyncPage.main),
                ),
        ),
        body: useSharedAccessibleViewModel
            ? _accessibleBody(l10n, busy)
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_busy)
                    LinearProgressIndicator(semanticsLabel: l10n.loading),
                  if (_status != null)
                    Semantics(liveRegion: true, child: Text(_status!)),
                  if (_page == _SyncPage.options) ...[
                    Text(l10n.cloudSyncOptionsHelp),
                    SwitchListTile(
                      title: Text(l10n.cloudSyncCollections),
                      value: _collections,
                      onChanged: busy
                          ? null
                          : (v) => _run(
                              () => _service.setScope(
                                preferences: false,
                                enabled: v,
                              ),
                            ),
                    ),
                    SwitchListTile(
                      title: Text(l10n.cloudSyncPreferences),
                      value: _preferences,
                      onChanged: busy
                          ? null
                          : (v) => _run(
                              () => _service.setScope(
                                preferences: true,
                                enabled: v,
                              ),
                            ),
                    ),
                    TextButton(
                      onPressed: busy ? null : _disconnect,
                      child: Text(l10n.cloudSyncDisconnect),
                    ),
                  ] else if (_page == _SyncPage.join) ...[
                    Text(l10n.cloudSyncJoinHelp),
                    TextField(
                      controller: _code,
                      autofocus: true,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: _busy ? null : (_) => _join(),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.cloudSyncCode,
                      ),
                    ),
                    FilledButton(
                      onPressed: busy ? null : _join,
                      child: Text(l10n.cloudSyncJoin),
                    ),
                  ] else if (_connected) ...[
                    Text(_syncStatus(l10n)),
                    Text(l10n.cloudSyncAutomaticHelp),
                    FilledButton(
                      onPressed: busy ? null : () => _run(_service.synchronize),
                      child: Text(l10n.cloudSyncNow),
                    ),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => _run(() async {
                              _invitation = await _service.invitation();
                            }),
                      child: Text(l10n.cloudSyncInvite),
                    ),
                    if (_invitation != null) ...[
                      SelectableText(
                        _invitation!,
                        semanticsLabel:
                            '${l10n.cloudSyncCode}: ${_invitation!.split('').join(' ')}',
                      ),
                      Text(l10n.cloudSyncCodeHelp),
                    ],
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _showPage(_SyncPage.options),
                      child: Text(l10n.cloudSyncOptions),
                    ),
                  ] else ...[
                    Text(l10n.cloudSyncFirstHelp),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () => _run(() async {
                              await _service.connect();
                              _invitation = await _service.invitation();
                            }),
                      child: Text(l10n.cloudSyncCreate),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _showPage(_SyncPage.join),
                      child: Text(l10n.cloudSyncHaveCode),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
