import 'package:flutter/material.dart';

/// Global raw-pointer trigger used to open diagnostics.
///
/// It does not join Flutter's gesture arena, so normal taps, scrolling and
/// two-finger zoom keep working. Diagnostics opens as soon as four pointers are
/// down at the same time.
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
  final Set<int> _activePointers = <int>{};
  bool _triggeredForCurrentTouch = false;

  void _pointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length >= 4 && !_triggeredForCurrentTouch) {
      _triggeredForCurrentTouch = true;
      widget.onTriggered();
    }
  }

  void _pointerFinished(PointerEvent event) {
    _activePointers.remove(event.pointer);
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
