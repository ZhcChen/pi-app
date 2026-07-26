part of '../main.dart';

// Shared desktop UI primitives used by both settings and workspace surfaces.
class _DesktopPrimitiveSpec {
  static const double surfaceBorderWidth = 1;
}

/// Generic bordered desktop surface with configurable radius and padding.
class _DesktopSurface extends StatelessWidget {
  const _DesktopSurface({
    required this.child,
    required this.color,
    required this.radius,
    this.padding,
    this.width,
    this.height,
    this.constraints,
    this.borderColor,
    this.boxShadow,
    super.key,
  });

  final Widget child;
  final Color color;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    final body = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    return Container(
      width: width,
      height: height,
      constraints: constraints,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? palette.dividerLight,
          width: _DesktopPrimitiveSpec.surfaceBorderWidth,
        ),
        boxShadow: boxShadow,
      ),
      child: body,
    );
  }
}

/// Shared selected/unselected row tile used by desktop sidebars.
class _DesktopSelectionTile extends StatelessWidget {
  const _DesktopSelectionTile({
    required this.selected,
    required this.onTap,
    required this.height,
    required this.radius,
    required this.child,
    this.animated = true,
  });

  final bool selected;
  final VoidCallback onTap;
  final double height;
  final double radius;
  final Widget child;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final decoration = BoxDecoration(
      color: selected ? palette.selection : Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
    );

    final body = animated
        ? AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: height,
            decoration: decoration,
            child: child,
          )
        : Container(height: height, decoration: decoration, child: child);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: body,
    );
  }
}

/// Shared icon + label pill for compact desktop status summaries.
class _DesktopStatusPill extends StatelessWidget {
  const _DesktopStatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return _DesktopSurface(
      color: palette.settingsField,
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: _AppTypography.controlLabel(palette)),
        ],
      ),
    );
  }
}
