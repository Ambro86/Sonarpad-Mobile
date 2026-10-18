import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_dynamic_labels.dart';
import '../models/chromecast_media.dart';
import '../services/chromecast_session.dart';
import '../utils/app_logger.dart';
import '../widgets/universal_accessible_view.dart';

class ChromecastReturn {
  const ChromecastReturn(this.position, this.resume);
  final Duration position;
  final bool resume;
}

class ChromecastScreen extends StatefulWidget {
  const ChromecastScreen({
    super.key,
    required this.media,
    required this.title,
    required this.position,
    required this.onStarted,
    required this.onPosition,
    this.live = false,
    this.discoveryOverride,
    this.sessionFactory,
  });
  final Stream<List<ChromecastDevice>> Function()? discoveryOverride;
  final ChromecastSession Function()? sessionFactory;
  final ChromecastMedia media;
  final String title;
  final Duration Function() position;
  final Future<void> Function() onStarted;
  final Future<void> Function(Duration) onPosition;
  final bool live;

  @override
  State<ChromecastScreen> createState() => _ChromecastScreenState();
}

class _ChromecastScreenState extends State<ChromecastScreen> {
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySubscription;
  StreamSubscription<List<ChromecastDevice>>? _testDiscoverySubscription;
  StreamSubscription<ChromecastStatus>? _statusSubscription;
  final _devices = <String, ChromecastDevice>{};
  ChromecastSession? _session;
  ChromecastDevice? _device;
  Timer? _searchTimer;
  bool _searching = true, _busy = false, _failed = false, _started = false;
  bool _leaving = false;
  int _searchGeneration = 0;
  int _savedSecond = -1;
  Duration? _lastPosition;
  Timer? _volumeDebounce, _seekDebounce;
  double? _volumeTarget, _seekTarget;
  Future<void> _adjustments = Future<void>.value();

  @override
  void initState() {
    super.initState();
    unawaited(_search());
  }

  Future<void> _stopSearch() async {
    _searchTimer?.cancel();
    final discovery = _discovery;
    _discovery = null;
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    await _testDiscoverySubscription?.cancel();
    _testDiscoverySubscription = null;
    if (discovery != null) {
      try {
        await discovery.stop();
      } catch (_) {
        /* Already stopped. */
      }
    }
  }

  Future<void> _search() async {
    final generation = ++_searchGeneration;
    await _stopSearch();
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _searching = true;
      _failed = false;
      _devices.clear();
    });
    if (widget.discoveryOverride != null) {
      _testDiscoverySubscription = widget.discoveryOverride!().listen(
        (devices) {
          if (!mounted) return;
          setState(() {
            _devices.clear();
            for (final device in devices) {
              _devices[device.id] = device;
            }
            _searching = false;
          });
        },
        onError: (Object _) {
          if (mounted) {
            setState(() {
              _failed = true;
              _searching = false;
            });
          }
        },
      );
      return;
    }
    final discovery = BonsoirDiscovery(type: '_googlecast._tcp');
    _discovery = discovery;
    try {
      await discovery.initialize();
      if (!mounted || generation != _searchGeneration) {
        await discovery.stop();
        return;
      }
      _discoverySubscription = discovery.eventStream!.listen(
        (event) {
          if (!mounted || generation != _searchGeneration) return;
          if (event is BonsoirDiscoveryServiceFoundEvent) {
            unawaited(
              event.service.resolve(discovery.serviceResolver).catchError((
                Object e,
              ) {
                AppLogger.log(
                  'Cast: service resolution failed: ${e.runtimeType}',
                );
              }),
            );
          } else if (event is BonsoirDiscoveryServiceResolvedEvent ||
              event is BonsoirDiscoveryServiceUpdatedEvent) {
            final service = event.service;
            if (service == null ||
                service.hostAddresses.isEmpty ||
                service.port <= 0) {
              return;
            }
            final hosts = service.hostAddresses;
            final host = hosts.firstWhere(
              (h) => !h.contains(':'),
              orElse: () => hosts.first,
            );
            setState(
              () => _devices[service.name] = ChromecastDevice(
                service.attributes['id'] ?? service.name,
                service.attributes['fn'] ?? service.name,
                host,
                service.port,
              ),
            );
          } else if (event is BonsoirDiscoveryServiceLostEvent) {
            setState(() => _devices.remove(event.service.name));
          }
        },
        onError: (Object e) {
          if (mounted) {
            setState(() {
              _failed = true;
              _searching = false;
            });
          }
        },
      );
      await discovery.start();
      _searchTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) setState(() => _searching = false);
        unawaited(_stopSearch());
      });
    } catch (e) {
      AppLogger.log('Cast: discovery failed: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _failed = true;
          _searching = false;
        });
      }
    }
  }

  Future<void> _connect(ChromecastDevice device) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    ++_searchGeneration;
    await _stopSearch();
    final session = widget.sessionFactory?.call() ?? ChromecastSession();
    _session = session;
    try {
      await session.connect(device);
      if (!mounted) return;
      await session.load(
        url: widget.media.url,
        mime: widget.media.mime,
        title: widget.title,
        position: widget.position(),
        live: widget.live,
      );
      if (!mounted) return;
      // Local playback remains untouched until the receiver confirms playback.
      await widget.onStarted();
      _started = true;
      _lastPosition = session.status.position;
      if (!mounted) return;
      _statusSubscription = session.updates.listen((status) {
        if (!mounted || _leaving) return;
        if (status.state != 'IDLE' && !status.disconnected) {
          _lastPosition = status.position;
          if (!widget.live &&
              (status.position.inSeconds - _savedSecond).abs() >= 5) {
            _savedSecond = status.position.inSeconds;
            unawaited(_savePosition(status.position));
          }
        }
        setState(() {
          if (status.disconnected) _failed = true;
        });
      });
      setState(() => _device = device);
      AppLogger.log('Cast: remote playback started mime=${widget.media.mime}');
    } catch (e) {
      AppLogger.log('Cast: connect/load failed: ${e.runtimeType}');
      await session.close();
      if (mounted) {
        setState(() {
          _session = null;
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _command(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      AppLogger.log('Cast: control failed: ${e.runtimeType}');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Keep the adjustable nodes enabled and stable during network round trips.
  // Coalesce rapid gestures and serialize them without changing focus.
  void _adjust(double value, {required bool volume}) {
    setState(() {
      if (volume) {
        _volumeTarget = value;
      } else {
        _seekTarget = value;
      }
    });
    if (volume) {
      _volumeDebounce?.cancel();
    } else {
      _seekDebounce?.cancel();
    }
    final timer = Timer(const Duration(milliseconds: 250), () {
      _adjustments = _adjustments.then((_) async {
        if (!mounted || _leaving || _session == null) return;
        try {
          if (volume) {
            await _session!.setVolume(value);
          } else {
            await _session!.seek(Duration(milliseconds: value.round()));
          }
        } catch (_) {
          if (mounted) setState(() => _failed = true);
        } finally {
          if (mounted) {
            setState(() {
              if (volume && _volumeTarget == value) _volumeTarget = null;
              if (!volume && _seekTarget == value) _seekTarget = null;
            });
          }
        }
      });
    });
    if (volume) {
      _volumeDebounce = timer;
    } else {
      _seekDebounce = timer;
    }
  }

  Future<void> _leave(bool resume) async {
    if (_leaving || _busy) return;
    _leaving = true;
    setState(() => _busy = true);
    _volumeDebounce?.cancel();
    _seekDebounce?.cancel();
    await _adjustments;
    final position = _lastPosition ?? widget.position();
    await _statusSubscription?.cancel();
    await _session?.close();
    if (_started && !widget.live) await _savePosition(position);
    if (mounted) {
      Navigator.pop(
        context,
        _started ? ChromecastReturn(position, resume) : null,
      );
    }
  }

  Future<void> _savePosition(Duration position) async {
    try {
      await widget.onPosition(position);
    } catch (e) {
      AppLogger.log('Cast: bookmark save failed: ${e.runtimeType}');
    }
  }

  @override
  void dispose() {
    ++_searchGeneration;
    _volumeDebounce?.cancel();
    _seekDebounce?.cancel();
    unawaited(_stopSearch());
    unawaited(_statusSubscription?.cancel());
    unawaited(_session?.close());
    super.dispose();
  }

  Widget _accessibleBody(
    AppLocalizations l10n,
    ChromecastStatus? status,
    bool remote,
    bool canControl,
  ) {
    final volume = (_volumeTarget ?? status?.volume ?? 1).clamp(0.0, 1.0);
    final duration = status?.duration.inMilliseconds.toDouble() ?? 0;
    final position =
        (_seekTarget ?? status?.position.inMilliseconds.toDouble() ?? 0).clamp(
          0.0,
          duration,
        );
    String spoken(double value) => l10n.formatPlaybackSpokenDuration(
      Duration(milliseconds: value.round()),
    );
    return UniversalAccessibleList(
      debugTag: 'chromecast',
      sections: [
        AccessibleListSection(
          rows: [
            AccessibleListRow(
              id: 'title',
              title: widget.title,
              kind: 'header',
              accessibilityButtonTrait: false,
            ),
            if (_failed)
              AccessibleListRow(
                id: 'error',
                title: l10n.castFailure,
                kind: 'text',
              ),
            if (_busy || (_searching && !remote))
              AccessibleListRow(
                id: 'loading',
                title: l10n.loading,
                kind: 'text',
              ),
            if (!remote && !_busy) ...[
              if (!_searching && _devices.isEmpty)
                AccessibleListRow(
                  id: 'empty',
                  title: l10n.castNoDevices,
                  kind: 'text',
                ),
              for (final entry in _devices.entries)
                AccessibleListRow(
                  id: 'device_${entry.key}',
                  title: entry.value.name,
                ),
              AccessibleListRow(id: 'retry', title: l10n.retry),
            ],
            if (remote) ...[
              AccessibleListRow(
                id: 'device_name',
                title: _device!.name,
                kind: 'text',
              ),
              AccessibleListRow(
                id: 'play_pause',
                title: status?.playing == true ? l10n.pause : l10n.play,
                enabled: canControl,
              ),
              if (!widget.live && duration > 0)
                AccessibleListRow(
                  id: 'cast_position',
                  title: l10n.playbackPosition,
                  kind: 'slider',
                  enabled: canControl,
                  accessibilityButtonTrait: false,
                  nativeSliderAccessibilityElement: true,
                  sliderValue: position,
                  sliderMin: 0,
                  sliderMax: duration,
                  sliderStep: 15000,
                  valueLabel: spoken(position),
                  sliderIncreasedValueLabel: spoken(
                    (position + 15000).clamp(0, duration),
                  ),
                  sliderDecreasedValueLabel: spoken(
                    (position - 15000).clamp(0, duration),
                  ),
                  flutterChild: Semantics(
                    label: l10n.playbackPosition,
                    child: Slider(
                      key: const ValueKey('cast_position'),
                      value: position,
                      max: duration,
                      divisions: (duration / 15000).ceil().clamp(1, 10000),
                      semanticFormatterCallback: spoken,
                      onChanged: canControl
                          ? (v) => _adjust(v, volume: false)
                          : null,
                    ),
                  ),
                ),
              AccessibleListRow(
                id: 'cast_volume',
                title: l10n.adjustVolume,
                kind: 'slider',
                enabled: canControl,
                accessibilityButtonTrait: false,
                nativeSliderAccessibilityElement: true,
                sliderValue: volume,
                sliderMin: 0,
                sliderMax: 1,
                sliderStep: 0.05,
                valueLabel: '${(volume * 100).round()}%',
                sliderIncreasedValueLabel:
                    '${((volume + 0.05).clamp(0, 1) * 100).round()}%',
                sliderDecreasedValueLabel:
                    '${((volume - 0.05).clamp(0, 1) * 100).round()}%',
                flutterChild: Semantics(
                  label: l10n.adjustVolume,
                  child: Slider(
                    key: const ValueKey('cast_volume'),
                    value: volume,
                    divisions: 20,
                    semanticFormatterCallback: (v) => '${(v * 100).round()}%',
                    onChanged: canControl
                        ? (v) => _adjust(v, volume: true)
                        : null,
                  ),
                ),
              ),
              AccessibleListRow(
                id: 'resume_here',
                title: l10n.castResumeHere,
                enabled: !_busy,
              ),
              AccessibleListRow(
                id: 'stop_cast',
                title: l10n.castStop,
                enabled: !_busy,
              ),
            ],
          ],
        ),
      ],
      onEvent: (event) async {
        if (event.type == 'slider' && canControl && event.value is num) {
          if (event.id == 'cast_volume' || event.id == 'cast_position') {
            _adjust(
              (event.value as num).toDouble(),
              volume: event.id == 'cast_volume',
            );
          }
          return;
        }
        if (event.type != 'activate') return;
        if (event.id == 'retry' && !_busy) {
          await _search();
        } else if (event.id == 'resume_here') {
          await _leave(true);
        } else if (event.id == 'stop_cast') {
          await _leave(false);
        } else if (event.id == 'play_pause' && canControl) {
          await _command(
            () => _session!.command(status!.playing ? 'PAUSE' : 'PLAY'),
          );
        } else if (event.id?.startsWith('device_') == true && !_busy) {
          final device = _devices[event.id!.substring(7)];
          if (device != null) await _connect(device);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = _session?.status;
    final remote = _device != null;
    final canControl = !_busy && status != null && !status.disconnected;
    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave(false));
      },
      child: Scaffold(
        appBar: SonarpadAppBar(
          title: Text(l10n.castToDevice),
          leading: SonarpadBackButton(onPressed: () => _leave(false)),
        ),
        body: useSharedAccessibleViewModel
            ? _accessibleBody(l10n, status, remote, canControl)
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Semantics(header: true, child: Text(widget.title)),
                  if (_failed)
                    Semantics(liveRegion: true, child: Text(l10n.castFailure)),
                  if (_busy || (_searching && !remote)) Text(l10n.loading),
                  if (!remote && !_busy) ...[
                    if (!_searching && _devices.isEmpty)
                      Text(l10n.castNoDevices),
                    for (final device in _devices.values)
                      ListTile(
                        key: ValueKey(device.id),
                        title: Text(device.name),
                        onTap: () => _connect(device),
                      ),
                    OutlinedButton(onPressed: _search, child: Text(l10n.retry)),
                  ],
                  if (remote) ...[
                    Text(_device!.name),
                    FilledButton(
                      onPressed: canControl
                          ? () => _command(
                              () => _session!.command(
                                status.playing ? 'PAUSE' : 'PLAY',
                              ),
                            )
                          : null,
                      child: Text(
                        status?.playing == true ? l10n.pause : l10n.play,
                      ),
                    ),
                    if (!widget.live &&
                        status != null &&
                        status.duration > Duration.zero) ...[
                      Text(l10n.playbackPosition),
                      Semantics(
                        label: l10n.playbackPosition,
                        child: Slider(
                          key: const ValueKey('cast_position'),
                          value:
                              (_seekTarget ??
                                      status.position.inMilliseconds.toDouble())
                                  .clamp(
                                    0,
                                    status.duration.inMilliseconds.toDouble(),
                                  ),
                          max: status.duration.inMilliseconds.toDouble(),
                          divisions: (status.duration.inSeconds / 15)
                              .ceil()
                              .clamp(1, 10000),
                          semanticFormatterCallback: (v) =>
                              l10n.formatPlaybackSpokenDuration(
                                Duration(milliseconds: v.round()),
                              ),
                          onChanged: canControl
                              ? (v) => _adjust(v, volume: false)
                              : null,
                        ),
                      ),
                    ],
                    Text(l10n.adjustVolume),
                    Semantics(
                      label: l10n.adjustVolume,
                      child: Slider(
                        key: const ValueKey('cast_volume'),
                        value: (_volumeTarget ?? status?.volume ?? 1).clamp(
                          0,
                          1,
                        ),
                        divisions: 20,
                        semanticFormatterCallback: (v) =>
                            '${(v * 100).round()}%',
                        onChanged: canControl
                            ? (v) => _adjust(v, volume: true)
                            : null,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _leave(true),
                      child: Text(l10n.castResumeHere),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _leave(false),
                      child: Text(l10n.castStop),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
