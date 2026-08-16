import 'dart:async';

import 'package:flutter/material.dart';

/// Non-invasive global gesture detector used to open diagnostics.
///
/// It observes raw pointer events without participating in Flutter's gesture
/// arena, so ordinary taps, scrolling, zooming and dialogs keep working.
class FourFingerDebugTrigger extends StatefulWidget {
  const FourFingerDebugTrigger({
    super.key,
    required this.child,
    required this.onTriggered,
    this.holdDuration = const Duration(milliseconds: 350),
  });

  final Widget child;
  final VoidCallback onTriggered;
  final Duration holdDuration;

  @override
  State<FourFingerDebugTrigger> createState() =>
      _FourFingerDebugTriggerState();
}

class _FourFingerDebugTriggerState extends State<FourFingerDebugTrigger> {
  final Set<int> _activePointers = <int>{};
  Timer? _holdTimer;
  bool _triggeredForCurrentTouch = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _pointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length < 4 || _triggeredForCurrentTouch) return;

    _holdTimer?.cancel();
    _holdTimer = Timer(widget.holdDuration, () {
      if (!mounted || _activePointers.length < 4) return;
      _triggeredForCurrentTouch = true;
      widget.onTriggered();
    });
  }

  void _pointerFinished(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 4) {
      _holdTimer?.cancel();
      _holdTimer = null;
    }
    if (_activePointers.isEmpty) {
      _triggeredForCurrentTouch = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _pointerDown,
      onPointerUp: _pointerFinished,
      onPointerCancel: _pointerFinished,
      child: widget.child,
    );
  }
}
