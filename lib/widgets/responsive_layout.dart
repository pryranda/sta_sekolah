import 'package:flutter/material.dart';

/// Centers [child] horizontally and caps its width to [maxWidth] on wide
/// viewports (tablet / desktop web), while filling the available width on
/// mobile screens.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 1080,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return Center(child: content);
  }
}

/// Responsive grid that adapts column count and aspect ratio to viewport width
/// so menu tiles look balanced on both phones and wide desktop web browsers.
class ResponsiveMenuGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double? mobileAspectRatio;
  final double? tabletAspectRatio;
  final double? desktopAspectRatio;

  const ResponsiveMenuGrid({
    super.key,
    required this.children,
    this.mobileColumns = 2,
    this.tabletColumns = 3,
    this.desktopColumns = 4,
    this.spacing = 12,
    this.mobileAspectRatio = 1.15,
    this.tabletAspectRatio = 1.25,
    this.desktopAspectRatio = 1.35,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount;
        final double aspectRatio;

        if (width >= 900) {
          crossAxisCount = desktopColumns;
          aspectRatio = desktopAspectRatio ?? 1.35;
        } else if (width >= 580) {
          crossAxisCount = tabletColumns;
          aspectRatio = tabletAspectRatio ?? 1.25;
        } else {
          crossAxisCount = mobileColumns;
          aspectRatio = mobileAspectRatio ?? 1.15;
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: aspectRatio,
          children: children,
        );
      },
    );
  }
}
