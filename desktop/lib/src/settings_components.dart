part of 'settings_feature.dart';

// Settings page primitives live here so page content can focus on data and layout.
class _SettingsComponentSpec {
  static const double navTileRadius = 12;
  static const double cardRadius = 16;
  static const double controlRadius = 12;
  static const double controlHeight = 34;
  static const double controlMinWidth = 208;
  static const double horizontalPadding = 18;
  static const double compactVerticalPadding = 12;
  static const double comfortableVerticalPadding = 14;
  static const double switchScale = 0.82;
}

/// Reusable category tile for the left settings navigation.
class SettingsCategoryTile extends StatelessWidget {
  const SettingsCategoryTile({
    super.key,
    required this.item,
    required this.interfaceDensity,
    required this.selected,
    required this.onTap,
  });

  final SettingsNavItem item;
  final AppInterfaceDensity interfaceDensity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return _DesktopSelectionTile(
      selected: selected,
      onTap: onTap,
      height: _densityValue(interfaceDensity, compact: 28, comfortable: 32),
      radius: _SettingsComponentSpec.navTileRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(item.icon, size: 16, color: palette.textSecondary),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                item.label,
                style: _AppTypography.settingsNavItem(palette),
              ),
            ),
            if (item.external)
              Icon(
                Icons.north_east_rounded,
                size: 13,
                color: palette.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroupLabel extends StatelessWidget {
  const _SettingsGroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 3),
      child: Text(label, style: _AppTypography.settingsGroupLabel(palette)),
    );
  }
}

/// Standard card shell for settings sections and placeholder panels.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return _DesktopSurface(
      color: palette.panelRaised,
      radius: _SettingsComponentSpec.cardRadius,
      child: child,
    );
  }
}

/// Vertical field block used by appearance settings and other form groups.
class _SettingsFieldBlock extends StatelessWidget {
  const _SettingsFieldBlock({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _AppTypography.settingsRowTitle(palette)),
          const SizedBox(height: 4),
          Text(
            description,
            style: _AppTypography.settingsRowDescription(palette),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Horizontal segmented control styled for compact desktop settings surfaces.
class _SettingsSegmentedControl<T> extends StatelessWidget {
  const _SettingsSegmentedControl({
    required this.values,
    required this.currentValue,
    required this.labelBuilder,
    required this.onChanged,
  });

  final List<T> values;
  final T currentValue;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<T>(
        showSelectedIcon: false,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return palette.selection;
            }
            return palette.settingsField;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? palette.textStrong
                : palette.textSecondary;
          }),
          textStyle: WidgetStateProperty.all(
            _AppTypography.controlLabel(palette),
          ),
          minimumSize: WidgetStateProperty.all(
            const Size(0, _SettingsComponentSpec.controlHeight),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          ),
          side: WidgetStateProperty.all(
            BorderSide(color: palette.dividerLight),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                _SettingsComponentSpec.controlRadius,
              ),
            ),
          ),
          visualDensity: VisualDensity.compact,
        ),
        segments: values
            .map(
              (value) => ButtonSegment<T>(
                value: value,
                label: Text(labelBuilder(value)),
              ),
            )
            .toList(),
        selected: {currentValue},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            onChanged(selection.first);
          }
        },
      ),
    );
  }
}

/// Standard row layout for label/description plus trailing desktop control.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.interfaceDensity,
    required this.title,
    required this.description,
    required this.trailing,
  });

  final AppInterfaceDensity interfaceDensity;
  final String title;
  final String description;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final verticalPadding = _densityValue(
          interfaceDensity,
          compact: _SettingsComponentSpec.compactVerticalPadding,
          comfortable: _SettingsComponentSpec.comfortableVerticalPadding,
        );

        if (compact) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              _SettingsComponentSpec.horizontalPadding,
              verticalPadding,
              _SettingsComponentSpec.horizontalPadding,
              verticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _AppTypography.settingsRowTitle(palette)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: _AppTypography.settingsRowDescription(palette),
                ),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: trailing),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            _SettingsComponentSpec.horizontalPadding,
            verticalPadding,
            16,
            verticalPadding,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _AppTypography.settingsRowTitle(palette),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: _AppTypography.settingsRowDescription(palette),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Align(alignment: Alignment.topRight, child: trailing),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Divider(height: 1, color: palette.dividerSoft);
  }
}

/// Small desktop action button for secondary settings actions.
class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    this.buttonKey,
    required this.label,
    required this.onPressed,
  });

  final Key? buttonKey;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return FilledButton.tonal(
      key: buttonKey,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        foregroundColor: palette.textStrong,
        backgroundColor: palette.settingsField,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        minimumSize: const Size(0, _SettingsComponentSpec.controlHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            _SettingsComponentSpec.controlRadius,
          ),
        ),
        textStyle: _AppTypography.controlLabel(palette),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label),
    );
  }
}

/// Compact switch wrapper used across the settings page.
class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    this.switchKey,
    required this.value,
    required this.onChanged,
  });

  final Key? switchKey;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Transform.scale(
      scale: _SettingsComponentSpec.switchScale,
      alignment: Alignment.centerRight,
      child: Switch(
        key: switchKey,
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        activeThumbColor: Colors.white,
        activeTrackColor: palette.switchActive,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: palette.switchInactive,
      ),
    );
  }
}

class _SettingsTextEditor extends StatelessWidget {
  const _SettingsTextEditor({
    this.fieldKey,
    required this.controller,
    this.hintText,
    this.minLines = 1,
    this.maxLines = 1,
    this.codeFont,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String? hintText;
  final int minLines;
  final int maxLines;
  final AppCodeFont? codeFont;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final baseStyle = TextStyle(
      color: palette.textPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
    );
    final textStyle = codeFont == null
        ? baseStyle
        : _withCodeFont(baseStyle, codeFont!);
    final minimumHeight = maxLines == 1 ? 38.0 : (minLines * 24.0) + 18.0;

    return _DesktopFieldSurface(
      radius: _SettingsComponentSpec.controlRadius,
      constraints: BoxConstraints(
        minHeight: minimumHeight,
        minWidth: _SettingsComponentSpec.controlMinWidth,
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: TextField(
        key: fieldKey,
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: TextInputType.multiline,
        style: textStyle,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: _AppTypography.settingsSearchHint(palette),
        ),
      ),
    );
  }
}

/// Compact dropdown shell for desktop settings forms.
class _SettingsDropdown<T> extends StatelessWidget {
  const _SettingsDropdown({
    this.dropdownKey,
    required this.value,
    required this.onChanged,
    required this.entries,
  });

  final Key? dropdownKey;
  final T value;
  final ValueChanged<T> onChanged;
  final List<_DropdownEntry<T>> entries;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return _DesktopFieldSurface(
      fieldKey: dropdownKey,
      radius: _SettingsComponentSpec.controlRadius,
      constraints: const BoxConstraints(
        minWidth: _SettingsComponentSpec.controlMinWidth,
        minHeight: _SettingsComponentSpec.controlHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          dropdownColor: palette.panelRaised,
          borderRadius: BorderRadius.circular(
            _SettingsComponentSpec.controlRadius,
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: palette.textMuted,
          ),
          style: _AppTypography.settingsDropdownValue(palette),
          onChanged: (next) {
            if (next != null) {
              onChanged(next);
            }
          },
          items: entries
              .map(
                (entry) => DropdownMenuItem<T>(
                  value: entry.value,
                  child: Text(entry.label),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
