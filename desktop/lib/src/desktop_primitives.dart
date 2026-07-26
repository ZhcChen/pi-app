import 'package:flutter/material.dart';

import 'desktop_design.dart';

// Shared desktop UI primitives used by both settings and workspace surfaces.
class _DesktopPrimitiveSpec {
  static const double surfaceBorderWidth = 1;
}

/// Generic bordered desktop surface with configurable radius and padding.
class DesktopSurface extends StatelessWidget {
  const DesktopSurface({
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
    final palette = context.desktopPalette;

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

class DesktopFieldSurface extends StatelessWidget {
  const DesktopFieldSurface({
    this.fieldKey,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
    this.radius = 12,
    this.constraints,
    super.key,
  });

  final Key? fieldKey;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return DesktopSurface(
      key: fieldKey,
      color: palette.settingsField,
      radius: radius,
      constraints: constraints,
      padding: padding,
      child: child,
    );
  }
}

/// Shared compact text action button used in sidebars and composer controls.
class DesktopTextActionButton extends StatelessWidget {
  const DesktopTextActionButton({
    this.buttonKey,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconAlignment = IconAlignment.start,
    this.alignment = Alignment.center,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    this.radius = 8,
    this.textStyle,
    super.key,
  });

  final Key? buttonKey;
  final String label;
  final VoidCallback onPressed;
  final Widget? icon;
  final IconAlignment iconAlignment;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;
  final double radius;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;
    final style = TextButton.styleFrom(
      alignment: alignment,
      foregroundColor: palette.textSecondary,
      textStyle: textStyle ?? DesktopTypography.controlLabel(palette),
      padding: padding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      visualDensity: VisualDensity.compact,
    );

    if (icon != null) {
      return TextButton.icon(
        key: buttonKey,
        onPressed: onPressed,
        icon: icon!,
        iconAlignment: iconAlignment,
        label: Text(label),
        style: style,
      );
    }

    return TextButton(
      key: buttonKey,
      onPressed: onPressed,
      style: style,
      child: Text(label),
    );
  }
}

/// Shared compact icon action button for desktop tool surfaces.
class DesktopIconActionButton extends StatelessWidget {
  const DesktopIconActionButton({
    required this.onPressed,
    required this.icon,
    this.tooltip,
    required this.backgroundColor,
    this.foregroundColor,
    this.buttonSize = const Size(28, 28),
    super.key,
  });

  final VoidCallback onPressed;
  final Widget icon;
  final String? tooltip;
  final Color backgroundColor;
  final Color? foregroundColor;
  final Size buttonSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: icon,
      color: foregroundColor ?? palette.textPrimary,
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor,
        minimumSize: buttonSize,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Shared selected/unselected row tile used by desktop sidebars.
class DesktopSelectionTile extends StatelessWidget {
  const DesktopSelectionTile({
    required this.selected,
    this.onTap,
    this.height,
    required this.radius,
    required this.child,
    this.animated = true,
    super.key,
  });

  final bool selected;
  final VoidCallback? onTap;
  final double? height;
  final double radius;
  final Widget child;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;
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

    if (onTap == null) {
      return body;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: body,
    );
  }
}

/// Shared icon + label pill for compact desktop status summaries.
class DesktopStatusPill extends StatelessWidget {
  const DesktopStatusPill({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return DesktopSurface(
      color: palette.settingsField,
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: DesktopTypography.controlLabel(palette)),
        ],
      ),
    );
  }
}
