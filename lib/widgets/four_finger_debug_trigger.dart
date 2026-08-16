import 'dart:async';

import 'package:flutter/material.dart';

/// Global raw-pointer shortcut for diagnostics.
///
/// Opens when four pointers are simultaneously down. Some Android tablet
/// firmwares briefly cancel/coalesce a pointer during a four-finger touch, so
/// we also accept four pointer-down events within a short window while at least
/// three pointers are still down. Normal taps, scrolling and two-finger zoom do
/// not enter Flutter's gesture arena here.
class FourFingerDebugTrigger extends StatefulWidget {
  const FourFingerDebugTrigger({
    super.key,
    required this.child,
    required this.onTriggered,
  });

  final Widget child;
  final VoidCallback onTriggered;

  @override
  State<FourFingerDebugTrigger> createState() =>
      _FourFingerDebugTriggerState();
}

class _FourFingerDebugTriggerState extends State<FourFingerDebugTrigger> {
  static const Duration _gestureWindow = Duration(milliseconds: 900);

  final Set<int> _activePointers = <int>{};
  final List<DateTime> _recentDowns = <DateTime>[];
  bool _triggeredForCurrentTouch = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _pointerDown(PointerDownEvent event) {
    final now = DateTime.now();
    _activePointers.add(event.pointer);
    _recentDowns.removeWhere((time) => now.difference(time) > _gestureWindow);
    _recentDowns.add(now);

    final simultaneous = _activePointers.length >= 4;
    final nearSimultaneous =
        _activePointers.length >= 3 && _recentDowns.length >= 4;
    if (!_triggeredForCurrentTouch && (simultaneous || nearSimultaneous)) {
      _triggeredForCurrentTouch = true;
      widget.onTriggered();
    }

    _resetTimer?.cancel();
  }

  void _pointerFinished(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) {
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 250), () {
        if (!mounted || _activePointers.isNotEmpty) return;
        _recentDowns.clear();
        _triggeredForCurrentTouch = false;
      });
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
