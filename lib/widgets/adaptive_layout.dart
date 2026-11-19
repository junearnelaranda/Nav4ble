import 'package:flutter/material.dart';

/// How much room the window gives NavAble.
enum ScreenSize {
  /// Below 640 px: the phone layout and bottom tab bar.
  phone,

  /// 640 to 999 px: an icon-only side menu.
  compact,

  /// 1000 px and up: the side menu with labels.
  wide,
}

ScreenSize screenSizeFor(double width) => width < 640
    ? ScreenSize.phone
    : width < 1000
    ? ScreenSize.compact
    : ScreenSize.wide;

extension ScreenSizeOf on BuildContext {
  ScreenSize get screenSize => screenSizeFor(MediaQuery.sizeOf(this).width);
}

/// Centers [child] and keeps it from growing wider than [maxWidth].
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// [start] and [end] side by side when there is room ([breakAt] or wider),
/// otherwise [start] stacked above [end].
class TwoColumns extends StatelessWidget {
  const TwoColumns({
    super.key,
    required this.start,
    required this.end,
    this.startWidth,
    this.startFlex = 1,
    this.endFlex = 1,
    this.gap = 16,
    this.breakAt = 900,
  });

  final Widget start;
  final Widget end;

  /// A fixed width for [start]; otherwise the columns share by flex.
  final double? startWidth;
  final int startFlex;
  final int endFlex;
  final double gap;
  final double breakAt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakAt) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              start,
              SizedBox(height: gap),
              end,
            ],
          );
        }
        final width = startWidth;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (width != null)
              SizedBox(width: width, child: start)
            else
              Expanded(flex: startFlex, child: start),
            SizedBox(width: gap),
            Expanded(flex: endFlex, child: end),
          ],
        );
      },
    );
  }
}

/// Equal-width cards in rows: 3 per row from 900 px of room, 2 from 600 px,
/// otherwise 1.
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children, this.gap = 12});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? 3
            : width >= 600
            ? 2
            : 1;
        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) SizedBox(width: gap),
                  Expanded(
                    child: start + column < children.length
                        ? children[start + column]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
      },
    );
  }
}
