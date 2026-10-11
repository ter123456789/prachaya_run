import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'debug_panel.dart';

/// Draggable bug button over every screen (debug builds only).
/// Tap opens [DebugPanel].
class DebugOverlay extends StatefulWidget {
  const DebugOverlay({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  static const _size = 44.0;
  Offset? _position;

  void _open() {
    final context = widget.navigatorKey.currentContext;
    if (context != null) DebugPanel.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final max = Offset(
          constraints.maxWidth - _size,
          constraints.maxHeight - _size,
        );
        final position =
            _position ?? Offset(max.dx - 12, constraints.maxHeight * 0.62);
        return Stack(
          children: [
            widget.child,
            Positioned(
              left: position.dx,
              top: position.dy,
              child: GestureDetector(
                onPanUpdate: (d) => setState(() {
                  final p = position + d.delta;
                  _position = Offset(
                    p.dx.clamp(0, max.dx),
                    p.dy.clamp(0, max.dy),
                  );
                }),
                onTap: _open,
                child: Semantics(
                  button: true,
                  label: 'เครื่องมือทดสอบ',
                  child: Container(
                    width: _size,
                    height: _size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xCC1E2A10),
                      border: Border.all(color: AppColors.lime, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66000000), blurRadius: 10),
                      ],
                    ),
                    child: const Icon(
                      Icons.bug_report_rounded,
                      color: AppColors.lime,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
