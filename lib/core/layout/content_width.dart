import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Widths for large phones, foldables and landscape. iPhone Duo: the outer
/// screen leaves ≈ 380 pt beside its camera, the inner one is 669 × 951 pt
/// (951 wide in landscape).
abstract final class Breakpoints {
  /// One readable column; wider screens centre it.
  static const content = 640.0;

  /// From this width a page may put two panes side by side.
  static const twoPane = 840.0;

  /// Cap of a two-pane page.
  static const wideContent = 1080.0;

  /// Gap between two panes.
  static const paneGap = 20.0;

  static bool isTwoPane(double width) => width >= twoPane;
}

/// Side padding that keeps content at most [maxWidth] wide and centred,
/// never less than [gutter].
EdgeInsets contentGutters(
  double width, {
  double maxWidth = Breakpoints.content,
  double gutter = 16,
}) =>
    EdgeInsets.symmetric(horizontal: math.max(gutter, (width - maxWidth) / 2));

/// Hands [builder] the side padding for the width it actually gets, so a
/// scroll view can stay full width (scrolls from anywhere) while its
/// content is centred.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.builder,
    this.maxWidth = Breakpoints.content,
  });

  final Widget Function(BuildContext context, EdgeInsets gutters) builder;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => builder(
        context,
        contentGutters(constraints.maxWidth, maxWidth: maxWidth),
      ),
    );
  }
}

/// A scrolling page of cards: one column on phones; from
/// [Breakpoints.twoPane] [start] and [end] sit side by side under [header].
class AdaptiveColumns extends StatelessWidget {
  const AdaptiveColumns({
    super.key,
    this.header = const [],
    required this.start,
    required this.end,
    this.gap = 28,
    this.top = 4,
    this.bottom = 40,
    this.controller,
  });

  final List<Widget> header;
  final List<Widget> start;
  final List<Widget> end;

  /// Space between [start] and [end] when they stack in one column.
  final double gap;
  final double top;
  final double bottom;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = Breakpoints.isTwoPane(constraints.maxWidth);
        final gutters = contentGutters(
          constraints.maxWidth,
          maxWidth: wide ? Breakpoints.wideContent : Breakpoints.content,
        );
        return ListView(
          controller: controller,
          padding: gutters.copyWith(top: top, bottom: bottom),
          children: [
            ...header,
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _column(start)),
                  const SizedBox(width: Breakpoints.paneGap),
                  Expanded(child: _column(end)),
                ],
              )
            else ...[
              ...start,
              SizedBox(height: gap),
              ...end,
            ],
          ],
        );
      },
    );
  }

  static Widget _column(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );
}

/// Centres [child] at most [maxWidth] wide (for pages that don't scroll).
/// The child keeps the full height and gets a tight width.
class MaxWidth extends StatelessWidget {
  const MaxWidth({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.content,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: contentGutters(
          constraints.maxWidth,
          maxWidth: maxWidth,
          gutter: 0,
        ),
        child: child,
      ),
    );
  }
}
