import 'package:flutter/material.dart';

/// Like [IndexedStack] (every child keeps its state and scroll position) but
/// cross-fades with a slight horizontal slide when [index] changes.
class FadeIndexedStack extends StatelessWidget {
  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  static const _duration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          _Page(
            active: i == index,
            // Pages to the left slide in from the left, and vice versa.
            slide: Offset((i - index).sign * 0.04, 0),
            child: children[i],
          ),
      ],
    );
  }
}

class _Page extends StatefulWidget {
  const _Page({required this.active, required this.slide, required this.child});

  final bool active;
  final Offset slide;
  final Widget child;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  /// True once an inactive page has finished fading out; it then goes
  /// offstage (kept alive, not painted, invisible to finders/semantics).
  late bool _offstage = !widget.active;

  @override
  void didUpdateWidget(_Page old) {
    super.didUpdateWidget(old);
    if (widget.active) _offstage = false;
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return Offstage(
      offstage: _offstage,
      child: IgnorePointer(
        ignoring: !active,
        child: AnimatedSlide(
          offset: active ? Offset.zero : widget.slide,
          duration: FadeIndexedStack._duration,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: FadeIndexedStack._duration,
            curve: Curves.easeOutCubic,
            onEnd: () {
              if (!widget.active && mounted) {
                setState(() => _offstage = true);
              }
            },
            // Mute the hidden page's own animations, not the fade above.
            child: TickerMode(enabled: active, child: widget.child),
          ),
        ),
      ),
    );
  }
}
