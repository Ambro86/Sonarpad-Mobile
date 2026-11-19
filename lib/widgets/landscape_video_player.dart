import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../l10n/app_localizations.dart';

class LandscapeVideoPlayer extends StatefulWidget {
  const LandscapeVideoPlayer({
    super.key,
    required this.surface,
    required this.navigation,
    required this.controls,
    required this.playing,
    this.controller,
  });

  final Widget surface;
  final List<Widget> navigation;
  final Widget controls;
  final bool playing;
  final VideoPlayerController? controller;

  @override
  State<LandscapeVideoPlayer> createState() => _LandscapeVideoPlayerState();
}

class _LandscapeVideoPlayerState extends State<LandscapeVideoPlayer> {
  Timer? _timer;
  bool _visible = true;
  bool _accessible = false;
  bool _currentRoute = true;
  int _pointers = 0;
  late bool _playing;

  bool get _isPlaying => widget.controller?.value.isPlaying ?? widget.playing;

  @override
  void initState() {
    super.initState();
    _playing = _isPlaying;
    widget.controller?.addListener(_playbackChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final accessible = MediaQuery.accessibleNavigationOf(context);
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (accessible && !_accessible) _visible = true;
    _accessible = accessible;
    _currentRoute = current;
    _scheduleHide();
  }

  @override
  void didUpdateWidget(LandscapeVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_playbackChanged);
      widget.controller?.addListener(_playbackChanged);
    }
    _playbackChanged();
  }

  void _playbackChanged() {
    if (_playing == _isPlaying) return;
    _playing = _isPlaying;
    if (!_playing && !_visible) setState(() => _visible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _timer?.cancel();
    if (_playing &&
        !_accessible &&
        _visible &&
        _pointers == 0 &&
        _currentRoute) {
      _timer = Timer(const Duration(seconds: 3), () => _setVisible(false));
    }
  }

  void _setVisible(bool visible) {
    setState(() => _visible = visible);
    _scheduleHide();
  }

  void _releasePointer(PointerEvent event) {
    _pointers--;
    _scheduleHide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller?.removeListener(_playbackChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        onPointerDown: (_) {
          _pointers++;
          _timer?.cancel();
        },
        onPointerUp: _releasePointer,
        onPointerCancel: _releasePointer,
        child: Stack(
          children: [
            Positioned.fill(child: widget.surface),
            if (!_visible)
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: l10n.showVideoControls,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _setVisible(true),
                  ),
                ),
              ),
            if (_visible)
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...widget.navigation,
                          const SizedBox(width: 4),
                          Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: IconButton(
                              color: Colors.white,
                              tooltip: l10n.hideVideoControls,
                              onPressed: () => _setVisible(false),
                              icon: const Icon(Icons.visibility_off),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: SingleChildScrollView(child: widget.controls),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
