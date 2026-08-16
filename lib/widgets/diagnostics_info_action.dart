import 'dart:async';

import 'package:flutter/material.dart';

/// About action that does not depend on Flutter's long-press gesture arena.
///
/// A normal tap opens About. Holding the pointer in place invokes diagnostics
/// directly from raw pointer events, which is more reliable on Android tablets
/// that interfere with long-press/multi-touch gestures.
class DiagnosticsInfoAction extends StatefulWidget {
  const DiagnosticsInfoAction({
    super.key,
    required this.onTap,
    required this.onDiagnostics,
    this.holdDuration = const Duration(milliseconds: 650),
  });

  final VoidCallback onTap;
  final VoidCallback onDiagnostics;
  final Duration holdDuration;

  @override
  State<DiagnosticsInfoAction> createState() => _DiagnosticsInfoActionState();
}

class _DiagnosticsInfoActionState extends State<DiagnosticsInfoAction> {
  static const double _cancelDistance = 18;

  Timer? _holdTimer;
  int? _pointer;
  Offset? _downPosition;
  bool _diagnosticsOpened = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _downPosition = event.position;
    _diagnosticsOpened = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(widget.holdDuration, () {
      if (!mounted || _pointer != event.pointer) return;
      _diagnosticsOpened = true;
      widget.onDiagnostics();
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointer != event.pointer) return;
    final origin = _downPosition;
    if (origin == null) return;
    if ((event.position - origin).distance > _cancelDistance) {
      _holdTimer?.cancel();
    }
  }

  void _finishPointer(PointerEvent event, {required bool allowTap}) {
    if (_pointer != event.pointer) return;
    _holdTimer?.cancel();
    final shouldTap = allowTap && !_diagnosticsOpened;
    _pointer = null;
    _downPosition = null;
    _diagnosticsOpened = false;
    if (shouldTap) widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'About. Hold for diagnostics.',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: (event) => _finishPointer(event, allowTap: true),
        onPointerCancel: (event) => _finishPointer(event, allowTap: false),
        child: const SizedBox.square(
          dimension: 48,
          child: Center(child: Icon(Icons.info_outline)),
        ),
      ),
    );
  }
}
