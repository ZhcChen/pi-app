part of 'workspace_feature.dart';

// Workspace primitives live here so the page file can focus on shell composition.
class _WorkspaceComponentSpec {
  static const double sidebarTileRadius = 8;
  static const double promptCardRadius = 8;
  static const double promptCardWidth = 194;
  static const double promptCardHeight = 128;
  static const double composerShellRadius = 24;
  static const double composerInputRadius = 20;
  static const double bottomPanelRadius = 18;
  static const double projectTileRadius = 12;
  static const double conversationBubbleRadius = 8;
  static const double conversationEventRadius = 6;
}

class _HeroMark extends StatelessWidget {
  const _HeroMark();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.4,
      child: SvgPicture.asset(piDarkMarkAsset, width: 58, height: 58),
    );
  }
}

class _PromptCardTile extends StatelessWidget {
  const _PromptCardTile({required this.card});

  final WorkspacePromptCard card;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return DesktopSurface(
      color: palette.panel,
      radius: _WorkspaceComponentSpec.promptCardRadius,
      width: _WorkspaceComponentSpec.promptCardWidth,
      height: _WorkspaceComponentSpec.promptCardHeight,
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(card.icon, size: 17, color: card.color),
          Text(card.title, style: DesktopTypography.promptTitle(palette)),
        ],
      ),
    );
  }
}

class _WorkspaceEmptyState extends StatelessWidget {
  const _WorkspaceEmptyState({required this.copy, required this.promptCards});

  final WorkspaceCopy copy;
  final List<WorkspacePromptCard> promptCards;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _HeroMark(),
          const SizedBox(height: 28),
          Text(
            copy.noProjectsTitle,
            textAlign: TextAlign.center,
            style: DesktopTypography.heroTitle(palette),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              copy.noProjectsDescription,
              textAlign: TextAlign.center,
              style: DesktopTypography.projectItem(palette),
            ),
          ),
          if (promptCards.isNotEmpty) ...[
            const SizedBox(height: 28),
            Wrap(
              key: const Key('workspace-suggested-prompts'),
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: promptCards
                  .map((card) => _PromptCardTile(card: card))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectSessionCanvas extends StatelessWidget {
  const _ProjectSessionCanvas({required this.copy, required this.session});

  final WorkspaceCopy copy;
  final WorkspaceSessionState? session;

  @override
  Widget build(BuildContext context) {
    final activeSession = session;
    if (activeSession == null || !activeSession.hasActivity) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      key: const Key('workspace-session-transcript'),
      child: _ProjectSessionTranscript(copy: copy, session: activeSession),
    );
  }
}

class _ProjectSessionTranscript extends StatelessWidget {
  const _ProjectSessionTranscript({required this.copy, required this.session});

  final WorkspaceCopy copy;
  final WorkspaceSessionState session;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;
    final errorMessage = session.errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SessionTranscriptHeader(copy: copy, session: session),
        if (session.activeToolName != null) ...[
          const SizedBox(height: 14),
          _SessionEventStrip(
            eventKey: const Key('workspace-session-active-tool'),
            icon: Icons.construction_outlined,
            label: copy.sessionToolStatusLabel(session.activeToolName!),
            accentColor: palette.accent,
            backgroundColor: palette.settingsField,
            foregroundColor: palette.textPrimary,
          ),
        ],
        if (errorMessage != null) ...[
          const SizedBox(height: 14),
          _SessionEventStrip(
            eventKey: const Key('workspace-session-error'),
            icon: Icons.error_outline_rounded,
            label: copy.sessionStatusLabel(WorkspaceRunStatus.failed),
            detail: errorMessage,
            accentColor: Theme.of(context).colorScheme.error,
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ],
        if (session.messages.isNotEmpty) ...[
          const SizedBox(height: 18),
          for (var index = 0; index < session.messages.length; index++) ...[
            _ConversationMessageBlock(
              copy: copy,
              message: session.messages[index],
              index: index,
            ),
            if (index < session.messages.length - 1) const SizedBox(height: 18),
          ],
        ],
      ],
    );
  }
}

class _SessionTranscriptHeader extends StatelessWidget {
  const _SessionTranscriptHeader({required this.copy, required this.session});

  final WorkspaceCopy copy;
  final WorkspaceSessionState session;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;
    final modelLabel = session.modelLabel;
    final statusColor = _sessionStatusColor(context, session.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          key: const Key('workspace-session-header'),
          spacing: 14,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SessionHeaderItem(
              icon: Icons.auto_awesome_rounded,
              label: copy.sessionConversationTitle,
              iconColor: palette.accent,
              textStyle: DesktopTypography.settingsSectionTitle(palette),
            ),
            _SessionHeaderItem(
              icon: _statusIcon(session.status),
              label: copy.sessionStatusLabel(session.status),
              iconColor: statusColor,
              textStyle: DesktopTypography.conversationRole(palette),
            ),
            if (modelLabel != null)
              _SessionHeaderItem(
                icon: Icons.memory_rounded,
                label: '$modelLabel · ${session.thinkingLevel}',
                tooltip: '$modelLabel · ${session.thinkingLevel}',
                iconColor: palette.textMuted,
                textStyle: DesktopTypography.conversationRole(palette),
                maxWidth: 300,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(height: 1, thickness: 1, color: palette.divider),
      ],
    );
  }
}

class _SessionHeaderItem extends StatelessWidget {
  const _SessionHeaderItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textStyle,
    this.maxWidth,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final TextStyle textStyle;
  final double? maxWidth;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final content = maxWidth == null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Text(label, style: textStyle),
            ],
          )
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth!),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: iconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
              ],
            ),
          );

    return tooltip == null
        ? content
        : Tooltip(message: tooltip!, child: content);
  }
}

class _SessionEventStrip extends StatelessWidget {
  const _SessionEventStrip({
    required this.eventKey,
    required this.icon,
    required this.label,
    this.detail,
    required this.accentColor,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final Key eventKey;
  final IconData icon;
  final String label;
  final String? detail;
  final Color accentColor;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return Container(
      key: eventKey,
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(
          _WorkspaceComponentSpec.conversationEventRadius,
        ),
        border: Border(left: BorderSide(color: accentColor, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: accentColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: DesktopTypography.conversationRole(
                    palette,
                  ).copyWith(color: foregroundColor),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  SelectableText(
                    detail!,
                    style: DesktopTypography.conversationBody(
                      palette,
                    ).copyWith(color: foregroundColor),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationMessageBlock extends StatelessWidget {
  const _ConversationMessageBlock({
    required this.copy,
    required this.message,
    required this.index,
  });

  final WorkspaceCopy copy;
  final WorkspaceConversationMessage message;
  final int index;

  @override
  Widget build(BuildContext context) {
    return message.role == WorkspaceConversationRole.user
        ? _UserConversationMessage(copy: copy, message: message, index: index)
        : _AssistantConversationMessage(
            copy: copy,
            message: message,
            index: index,
          );
  }
}

class _UserConversationMessage extends StatelessWidget {
  const _UserConversationMessage({
    required this.copy,
    required this.message,
    required this.index,
  });

  final WorkspaceCopy copy;
  final WorkspaceConversationMessage message;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final proportionalMaxWidth = constraints.maxWidth * 0.82;
        final maxBubbleWidth = proportionalMaxWidth > 680
            ? 680.0
            : proportionalMaxWidth;

        return Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Container(
              key: Key('workspace-message-$index'),
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
              decoration: BoxDecoration(
                color: palette.selection,
                borderRadius: BorderRadius.circular(
                  _WorkspaceComponentSpec.conversationBubbleRadius,
                ),
                border: Border.all(color: palette.dividerLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ConversationRoleLabel(
                    icon: Icons.person_outline_rounded,
                    label: copy.sessionUserLabel,
                    iconColor: palette.textSecondary,
                  ),
                  const SizedBox(height: 7),
                  SelectableText(
                    message.text,
                    key: const Key('workspace-user-message'),
                    style: DesktopTypography.conversationBody(palette),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AssistantConversationMessage extends StatelessWidget {
  const _AssistantConversationMessage({
    required this.copy,
    required this.message,
    required this.index,
  });

  final WorkspaceCopy copy;
  final WorkspaceConversationMessage message;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return Container(
      key: Key('workspace-message-$index'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            color: palette.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _ConversationRoleLabel(
                      icon: Icons.auto_awesome_rounded,
                      label: copy.sessionAssistantLabel,
                      iconColor: palette.accent,
                      textColor: palette.textPrimary,
                    ),
                    if (message.isStreaming)
                      Semantics(
                        liveRegion: true,
                        label: copy.sessionStreamingLabel,
                        child: Row(
                          key: const Key('workspace-streaming-indicator'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.more_horiz_rounded,
                              size: 16,
                              color: palette.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              copy.sessionStreamingLabel,
                              style: DesktopTypography.conversationStreaming(
                                palette,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  message.text,
                  key: const Key('workspace-assistant-message'),
                  style: DesktopTypography.conversationBody(palette),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationRoleLabel extends StatelessWidget {
  const _ConversationRoleLabel({
    required this.icon,
    required this.label,
    required this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: DesktopTypography.conversationRole(
            palette,
          ).copyWith(color: textColor ?? iconColor),
        ),
      ],
    );
  }
}

IconData _statusIcon(WorkspaceRunStatus status) {
  return switch (status) {
    WorkspaceRunStatus.idle => Icons.pause_circle_outline_rounded,
    WorkspaceRunStatus.starting => Icons.hourglass_top_rounded,
    WorkspaceRunStatus.waiting => Icons.schedule_send_rounded,
    WorkspaceRunStatus.running => Icons.auto_awesome_rounded,
    WorkspaceRunStatus.settled => Icons.check_circle_outline_rounded,
    WorkspaceRunStatus.aborted => Icons.cancel_outlined,
    WorkspaceRunStatus.failed => Icons.error_outline_rounded,
  };
}

Color _sessionStatusColor(BuildContext context, WorkspaceRunStatus status) {
  final palette = context.desktopPalette;

  return switch (status) {
    WorkspaceRunStatus.starting ||
    WorkspaceRunStatus.waiting ||
    WorkspaceRunStatus.running => palette.accent,
    WorkspaceRunStatus.failed => Theme.of(context).colorScheme.error,
    WorkspaceRunStatus.settled => palette.textSecondary,
    WorkspaceRunStatus.idle || WorkspaceRunStatus.aborted => palette.textMuted,
  };
}

/// Primary task composer shown at the bottom of the workspace.
class _Composer extends StatefulWidget {
  const _Composer({
    required this.copy,
    required this.preferences,
    required this.project,
    required this.session,
    required this.controller,
    required this.onSubmit,
    required this.onAbort,
  });

  final WorkspaceCopy copy;
  final AppPreferences preferences;
  final WorkspaceProjectGroup? project;
  final WorkspaceSessionState? session;
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback? onAbort;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      debugLabel: 'workspace-composer-input',
      onKeyEvent: _handleKeyEvent,
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.session?.isRunning == true || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final logicalKey = event.logicalKey;
    if (logicalKey != LogicalKeyboardKey.enter &&
        logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isAltPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    final value = widget.controller.value;
    if (value.composing.isValid && !value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }

    if (keyboard.isShiftPressed) {
      final selection = value.selection.isValid
          ? value.selection
          : TextSelection.collapsed(offset: value.text.length);
      final nextText = value.text.replaceRange(
        selection.start,
        selection.end,
        '\n',
      );
      final nextOffset = selection.start + 1;
      widget.controller.value = value.copyWith(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextOffset),
        composing: TextRange.empty,
      );
      return KeyEventResult.handled;
    }

    widget.onSubmit();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;
    final density = widget.preferences.interfaceDensity;
    final isRunning = widget.session?.isRunning == true;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 836),
      child: DesktopSurface(
        color: palette.composerShell,
        radius: _WorkspaceComponentSpec.composerShellRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                desktopDensityValue(density, compact: 10, comfortable: 12),
                18,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: desktopDensityValue(
                    density,
                    compact: 12,
                    comfortable: 16,
                  ),
                  runSpacing: 8,
                  children: [
                    _ComposerTag(
                      icon: Icons.folder_outlined,
                      label:
                          widget.project?.name ?? widget.copy.noProjectsTitle,
                    ),
                    _ComposerTag(
                      icon: Icons.computer_outlined,
                      label: widget.copy.localLabel,
                    ),
                    if (widget.project?.branch != null &&
                        widget.project!.branch!.isNotEmpty)
                      _ComposerTag(
                        icon: Icons.merge_type_outlined,
                        label: widget.project!.branch!,
                      ),
                    if (widget.session?.modelLabel != null)
                      _ComposerTag(
                        icon: Icons.memory_rounded,
                        label:
                            '${widget.session!.modelLabel} · ${widget.session!.thinkingLevel}',
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                desktopDensityValue(density, compact: 8, comfortable: 10),
                14,
                0,
              ),
              child: DesktopSurface(
                color: palette.composerInput,
                radius: _WorkspaceComponentSpec.composerInputRadius,
                borderColor: Colors.transparent,
                padding: EdgeInsets.fromLTRB(
                  16,
                  desktopDensityValue(density, compact: 14, comfortable: 16),
                  16,
                  desktopDensityValue(density, compact: 10, comfortable: 12),
                ),
                child: Column(
                  children: [
                    TextField(
                      key: const Key('workspace-composer-input'),
                      controller: widget.controller,
                      focusNode: _focusNode,
                      enabled: !isRunning,
                      minLines: 3,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => widget.onSubmit(),
                      style: desktopWithCodeFont(
                        DesktopTypography.composerInput(palette),
                        widget.preferences.codeFont,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: widget.copy.composerHint,
                        hintStyle: desktopWithCodeFont(
                          DesktopTypography.composerHint(palette),
                          widget.preferences.codeFont,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 14,
                          color: palette.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.project?.sessionCwd ??
                                widget.copy.composerNoProjectNotice,
                            key: const Key('composer-session-cwd'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DesktopTypography.sectionLabel(palette),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.session?.activeToolName != null
                                ? widget.copy.sessionToolStatusLabel(
                                    widget.session!.activeToolName!,
                                  )
                                : widget.session == null
                                ? widget.copy.composerExecutionSummary(
                                    widget.preferences,
                                  )
                                : widget.copy.sessionStatusLabel(
                                    widget.session!.status,
                                  ),
                            key: const Key('composer-execution-summary'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: DesktopTypography.sectionLabel(palette),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isRunning && widget.onAbort != null)
                          DesktopIconActionButton(
                            key: const Key('abort-composer-task-button'),
                            onPressed: widget.onAbort!,
                            tooltip: widget.copy.abortTaskTooltip,
                            icon: const Icon(Icons.stop_rounded),
                            backgroundColor: const Color(0xFF8D3B3B),
                            buttonSize: const Size(40, 40),
                          )
                        else
                          DesktopIconActionButton(
                            key: const Key('submit-composer-task-button'),
                            onPressed: widget.onSubmit,
                            tooltip: widget.copy.submitTaskTooltip,
                            icon: const Icon(Icons.arrow_upward_rounded),
                            backgroundColor: const Color(0xFF767676),
                            buttonSize: const Size(40, 40),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: desktopDensityValue(
                density,
                compact: 12,
                comfortable: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerTag extends StatelessWidget {
  const _ComposerTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: palette.textPrimary),
        const SizedBox(width: 6),
        Text(label, style: DesktopTypography.composerTag(palette)),
      ],
    );
  }
}

/// Secondary bottom panel that summarizes current execution defaults.
class _WorkspaceBottomPanel extends StatelessWidget {
  const _WorkspaceBottomPanel({required this.copy, required this.preferences});

  final WorkspaceCopy copy;
  final AppPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 836),
      child: DesktopSurface(
        key: const Key('workspace-bottom-panel'),
        color: palette.panel,
        radius: _WorkspaceComponentSpec.bottomPanelRadius,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy.executionDefaultsTitle,
              style: DesktopTypography.settingsGroupLabel(palette),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _WorkspaceStatusPill(
                  icon: Icons.open_in_new_rounded,
                  label: copy.openDestinationSummaryLabel(
                    preferences.openDestination,
                  ),
                ),
                _WorkspaceStatusPill(
                  icon: Icons.shield_outlined,
                  label: copy.accessModeLabel(preferences),
                ),
                _WorkspaceStatusPill(
                  icon: Icons.fact_check_outlined,
                  label: copy.reviewModeLabel(preferences.autoReview),
                ),
                _WorkspaceStatusPill(
                  icon: Icons.bedtime_outlined,
                  label: copy.sleepModeLabel(preferences.preventSleep),
                ),
                _WorkspaceStatusPill(
                  icon: Icons.auto_awesome_outlined,
                  label: copy.suggestedPromptsModeLabel(
                    preferences.suggestedPrompts,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceStatusPill extends StatelessWidget {
  const _WorkspaceStatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DesktopStatusPill(icon: icon, label: label);
  }
}

/// Primary action tile for the left workspace sidebar.
class _SidebarActionTile extends StatelessWidget {
  const _SidebarActionTile({
    required this.action,
    required this.interfaceDensity,
    required this.selected,
    required this.onTap,
  });

  final WorkspaceAction action;
  final AppInterfaceDensity interfaceDensity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: DesktopSelectionTile(
        selected: selected,
        onTap: onTap,
        height: desktopDensityValue(
          interfaceDensity,
          compact: 34,
          comfortable: 38,
        ),
        radius: _WorkspaceComponentSpec.sidebarTileRadius,
        animated: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(action.icon, size: 17, color: palette.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.label,
                  style: DesktopTypography.sidebarItem(palette),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expandable project tile in the workspace sidebar.
enum _ProjectMenuAction { rename, togglePin, remove }

class _ProjectTile extends StatefulWidget {
  const _ProjectTile({
    required this.copy,
    required this.project,
    required this.interfaceDensity,
    required this.openDestination,
    required this.selected,
    required this.isManaged,
    required this.isPinned,
    required this.onTap,
    required this.onOpenProject,
    required this.onRename,
    required this.onTogglePinned,
    required this.onRemove,
    super.key,
  });

  final WorkspaceCopy copy;
  final WorkspaceProjectGroup project;
  final AppInterfaceDensity interfaceDensity;
  final AppOpenDestination openDestination;
  final bool selected;
  final bool isManaged;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onOpenProject;
  final Future<void> Function(String alias) onRename;
  final Future<void> Function() onTogglePinned;
  final Future<void> Function() onRemove;

  @override
  State<_ProjectTile> createState() => _ProjectTileState();
}

class _ProjectTileState extends State<_ProjectTile> {
  bool _isHovered = false;

  Future<void> _showRenameProjectDialog() async {
    final alias = await showDialog<String>(
      context: context,
      builder: (context) {
        return _ProjectRenameDialog(
          copy: widget.copy,
          initialName: widget.project.name,
        );
      },
    );

    if (alias != null) {
      await widget.onRename(alias);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: DesktopSelectionTile(
        selected: widget.selected,
        onTap: widget.onTap,
        height: desktopDensityValue(
          widget.interfaceDensity,
          compact: 36,
          comfortable: 40,
        ),
        radius: _WorkspaceComponentSpec.projectTileRadius,
        animated: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 16,
                color: palette.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DesktopTypography.sidebarItem(palette),
                ),
              ),
              if (widget.isPinned) ...[
                const SizedBox(width: 6),
                Icon(Icons.push_pin_outlined, size: 13, color: palette.accent),
              ],
              if ((_isHovered || widget.selected) &&
                  widget.project.workspacePath != null) ...[
                const SizedBox(width: 8),
                DesktopIconActionButton(
                  key: Key('open-project-button-${widget.project.name}'),
                  onPressed: widget.onOpenProject,
                  tooltip: widget.copy.openTargetTooltip(
                    widget.openDestination,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  backgroundColor: palette.settingsField,
                  foregroundColor: palette.textSecondary,
                  buttonSize: const Size(24, 24),
                ),
              ],
              if (widget.isManaged && (_isHovered || widget.selected)) ...[
                const SizedBox(width: 6),
                PopupMenuButton<_ProjectMenuAction>(
                  key: Key('manage-project-button-${widget.project.name}'),
                  tooltip: widget.copy.manageProjectTooltip,
                  icon: const Icon(Icons.more_horiz_rounded, size: 16),
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  color: palette.panelRaised,
                  position: PopupMenuPosition.under,
                  style: IconButton.styleFrom(
                    backgroundColor: palette.settingsField,
                    foregroundColor: palette.textSecondary,
                    minimumSize: const Size(24, 24),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onSelected: (action) async {
                    switch (action) {
                      case _ProjectMenuAction.rename:
                        await _showRenameProjectDialog();
                        break;
                      case _ProjectMenuAction.togglePin:
                        await widget.onTogglePinned();
                        break;
                      case _ProjectMenuAction.remove:
                        await widget.onRemove();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<_ProjectMenuAction>(
                      key: const Key('rename-project-menu-item'),
                      value: _ProjectMenuAction.rename,
                      child: Row(
                        children: [
                          Icon(
                            Icons.drive_file_rename_outline_rounded,
                            size: 16,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.copy.renameProjectLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DesktopTypography.sidebarItem(palette),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<_ProjectMenuAction>(
                      value: _ProjectMenuAction.togglePin,
                      child: Row(
                        children: [
                          Icon(
                            widget.isPinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin_rounded,
                            size: 16,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.isPinned
                                  ? widget.copy.unpinProjectLabel
                                  : widget.copy.pinProjectLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DesktopTypography.sidebarItem(palette),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<_ProjectMenuAction>(
                      value: _ProjectMenuAction.remove,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 16,
                            color: Color(0xFFE97878),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.copy.removeProjectLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DesktopTypography.sidebarItem(
                                palette,
                              ).copyWith(color: const Color(0xFFE97878)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectRenameDialog extends StatefulWidget {
  const _ProjectRenameDialog({required this.copy, required this.initialName});

  final WorkspaceCopy copy;
  final String initialName;

  @override
  State<_ProjectRenameDialog> createState() => _ProjectRenameDialogState();
}

class _ProjectRenameDialogState extends State<_ProjectRenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return AlertDialog(
      backgroundColor: palette.panelRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        widget.copy.renameProjectDialogTitle,
        style: DesktopTypography.settingsGroupLabel(palette),
      ),
      content: SizedBox(
        width: 320,
        child: TextField(
          key: const Key('project-rename-input'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
          decoration: InputDecoration(
            labelText: widget.copy.projectNameFieldLabel,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.copy.cancelActionLabel),
        ),
        FilledButton(
          key: const Key('save-project-rename-button'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.copy.saveActionLabel),
        ),
      ],
    );
  }
}

class _ProjectSectionHeader extends StatefulWidget {
  const _ProjectSectionHeader({
    required this.label,
    required this.expandTooltip,
    required this.collapseTooltip,
    required this.isExpanded,
    required this.onToggle,
    required this.addTooltip,
    required this.onAddProject,
  });

  final String label;
  final String expandTooltip;
  final String collapseTooltip;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String addTooltip;
  final Future<void> Function() onAddProject;

  @override
  State<_ProjectSectionHeader> createState() => _ProjectSectionHeaderState();
}

class _ProjectSectionHeaderState extends State<_ProjectSectionHeader> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return MouseRegion(
      key: const Key('projects-section-header'),
      onEnter: (_) {
        if (!_isHovered) {
          setState(() {
            _isHovered = true;
          });
        }
      },
      onExit: (_) {
        if (_isHovered) {
          setState(() {
            _isHovered = false;
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: SizedBox(
          height: 24,
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: widget.isExpanded
                      ? widget.collapseTooltip
                      : widget.expandTooltip,
                  child: Semantics(
                    button: true,
                    expanded: widget.isExpanded,
                    label: widget.label,
                    child: InkWell(
                      key: const Key('toggle-projects-section-button'),
                      onTap: widget.onToggle,
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: double.infinity,
                        height: 24,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _SidebarSectionLabel(
                            label: widget.label,
                            icon: widget.isExpanded
                                ? Icons.expand_more_rounded
                                : Icons.chevron_right_rounded,
                            labelKey: const Key('projects-section-label'),
                            iconKey: const Key('projects-section-toggle-icon'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 24,
                height: 24,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IgnorePointer(
                    ignoring: !_isHovered,
                    child: AnimatedOpacity(
                      key: const Key('add-project-button-visibility'),
                      duration: const Duration(milliseconds: 120),
                      opacity: _isHovered ? 1 : 0,
                      child: DesktopIconActionButton(
                        key: const Key('add-project-button'),
                        onPressed: () {
                          widget.onAddProject();
                        },
                        tooltip: widget.addTooltip,
                        icon: const Icon(Icons.add_rounded, size: 14),
                        backgroundColor: Colors.transparent,
                        foregroundColor: palette.textMuted,
                        buttonSize: const Size(20, 20),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel({
    required this.label,
    required this.icon,
    required this.labelKey,
    this.iconKey,
  });

  final String label;
  final IconData icon;
  final Key labelKey;
  final Key? iconKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return SizedBox(
      key: labelKey,
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: DesktopTypography.sectionLabel(palette),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 16,
            height: 16,
            child: Center(
              child: Icon(
                icon,
                key: iconKey,
                size: 16,
                color: palette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedProjectSessionList extends StatelessWidget {
  const _SelectedProjectSessionList({
    required this.copy,
    required this.interfaceDensity,
    required this.session,
  });

  final WorkspaceCopy copy;
  final AppInterfaceDensity interfaceDensity;
  final WorkspaceSessionState? session;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;
    final activeSession = session;
    if (activeSession == null || !activeSession.hasActivity) {
      return const SizedBox.shrink();
    }

    final status = activeSession.status;
    final detailParts = <String>[
      copy.sessionStatusLabel(status),
      ?activeSession.modelLabel,
    ];

    return DesktopSelectionTile(
      selected: true,
      radius: _WorkspaceComponentSpec.projectTileRadius,
      animated: false,
      child: Container(
        key: const Key('sidebar-project-session-tile'),
        constraints: BoxConstraints(
          minHeight: desktopDensityValue(
            interfaceDensity,
            compact: 34,
            comfortable: 38,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                _statusIcon(status),
                size: 15,
                color: _sessionStatusColor(context, status),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activeSession.displayTitle ?? copy.currentSessionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DesktopTypography.sidebarItem(palette),
                  ),
                  if (detailParts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detailParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DesktopTypography.controlLabel(
                        palette,
                      ).copyWith(color: palette.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
