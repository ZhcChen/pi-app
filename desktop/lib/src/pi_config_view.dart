part of 'settings_feature.dart';

class _PiModelsSettingsContent extends StatefulWidget {
  const _PiModelsSettingsContent({
    required this.copy,
    required this.preferences,
    required this.snapshot,
    required this.loadError,
    required this.onSaveModelPreferences,
    required this.onSaveModelsJson,
  });

  final SettingsCopy copy;
  final AppPreferences preferences;
  final PiConfigSnapshot? snapshot;
  final String? loadError;
  final Future<void> Function(PiModelPreferences preferences)
  onSaveModelPreferences;
  final Future<void> Function(String content) onSaveModelsJson;

  @override
  State<_PiModelsSettingsContent> createState() =>
      _PiModelsSettingsContentState();
}

class _PiModelsSettingsContentState extends State<_PiModelsSettingsContent> {
  late final TextEditingController _defaultProviderController;
  late final TextEditingController _defaultModelController;
  late final TextEditingController _enabledModelsController;
  late final TextEditingController _modelsJsonController;

  String _thinkingLevelValue = '';
  String _lastPreferencesSignature = '';
  String _lastModelsJsonContent = '';
  bool _savingModelPreferences = false;
  bool _savingModelsJson = false;

  @override
  void initState() {
    super.initState();
    _defaultProviderController = TextEditingController();
    _defaultModelController = TextEditingController();
    _enabledModelsController = TextEditingController();
    _modelsJsonController = TextEditingController();
    _applySnapshot(widget.snapshot, force: true);
  }

  @override
  void didUpdateWidget(covariant _PiModelsSettingsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applySnapshot(widget.snapshot);
  }

  @override
  void dispose() {
    _defaultProviderController.dispose();
    _defaultModelController.dispose();
    _enabledModelsController.dispose();
    _modelsJsonController.dispose();
    super.dispose();
  }

  void _applySnapshot(PiConfigSnapshot? snapshot, {bool force = false}) {
    if (snapshot == null) {
      return;
    }

    final preferencesSignature = [
      snapshot.modelPreferences.defaultProvider ?? '',
      snapshot.modelPreferences.defaultModel ?? '',
      snapshot.modelPreferences.defaultThinkingLevel ?? '',
      snapshot.modelPreferences.enabledModels.join('\n'),
    ].join('||');

    if (force || preferencesSignature != _lastPreferencesSignature) {
      _lastPreferencesSignature = preferencesSignature;
      _defaultProviderController.text =
          snapshot.modelPreferences.defaultProvider ?? '';
      _defaultModelController.text =
          snapshot.modelPreferences.defaultModel ?? '';
      _enabledModelsController.text = snapshot.modelPreferences.enabledModels
          .join('\n');
      _thinkingLevelValue =
          snapshot.modelPreferences.defaultThinkingLevel ?? '';
    }

    if (force || snapshot.modelsJsonContent != _lastModelsJsonContent) {
      _lastModelsJsonContent = snapshot.modelsJsonContent;
      _modelsJsonController.text = snapshot.modelsJsonContent;
    }
  }

  Future<void> _handleSaveModelPreferences() async {
    setState(() {
      _savingModelPreferences = true;
    });

    try {
      await widget.onSaveModelPreferences(
        PiModelPreferences(
          defaultProvider: _defaultProviderController.text,
          defaultModel: _defaultModelController.text,
          defaultThinkingLevel: _thinkingLevelValue,
          enabledModels: _parseEnabledModels(_enabledModelsController.text),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingModelPreferences = false;
        });
      }
    }
  }

  Future<void> _handleSaveModelsJson() async {
    setState(() {
      _savingModelsJson = true;
    });

    try {
      await widget.onSaveModelsJson(_modelsJsonController.text);
    } finally {
      if (mounted) {
        setState(() {
          _savingModelsJson = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loadError != null) {
      return _SettingsPlaceholderContent(
        title: widget.copy.piModelsTitle,
        body: widget.copy.piConfigLoadFailedBody(widget.loadError!),
      );
    }

    final snapshot = widget.snapshot;
    if (snapshot == null) {
      return _SettingsPlaceholderContent(
        title: widget.copy.piModelsTitle,
        body: widget.copy.piConfigLoadingLabel,
      );
    }

    final palette = context.appPalette;

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(64, 54, 64, 54),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 890),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.copy.piModelsTitle,
                  key: const Key('pi-models-page-title'),
                  style: _AppTypography.settingsPageTitle(palette),
                ),
                const SizedBox(height: 46),
                Text(
                  widget.copy.piConfigRootSectionTitle,
                  style: _AppTypography.settingsSectionTitle(palette),
                ),
                const SizedBox(height: 14),
                _PiConfigLocationCard(copy: widget.copy, snapshot: snapshot),
                const SizedBox(height: 42),
                Text(
                  widget.copy.piModelPreferencesSectionTitle,
                  style: _AppTypography.settingsSectionTitle(palette),
                ),
                const SizedBox(height: 14),
                _SettingsCard(
                  child: Column(
                    children: [
                      _SettingsFieldBlock(
                        title: widget.copy.piDefaultProviderTitle,
                        description: widget.copy.piDefaultProviderDescription,
                        child: _SettingsTextEditor(
                          fieldKey: const Key('pi-default-provider-field'),
                          controller: _defaultProviderController,
                          hintText: 'anthropic',
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsFieldBlock(
                        title: widget.copy.piDefaultModelTitle,
                        description: widget.copy.piDefaultModelDescription,
                        child: _SettingsTextEditor(
                          fieldKey: const Key('pi-default-model-field'),
                          controller: _defaultModelController,
                          hintText: 'claude-sonnet-4-20250514',
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsFieldBlock(
                        title: widget.copy.piDefaultThinkingLevelTitle,
                        description:
                            widget.copy.piDefaultThinkingLevelDescription,
                        child: _SettingsDropdown<String>(
                          dropdownKey: const Key('pi-thinking-level-dropdown'),
                          value: _thinkingLevelValue,
                          onChanged: (value) {
                            setState(() {
                              _thinkingLevelValue = value;
                            });
                          },
                          entries: [
                            _DropdownEntry(
                              value: '',
                              label: widget.copy.piUnsetOptionLabel,
                            ),
                            for (final level in piThinkingLevels)
                              _DropdownEntry(
                                value: level,
                                label: widget.copy.thinkingLevelLabel(level),
                              ),
                          ],
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsFieldBlock(
                        title: widget.copy.piEnabledModelsTitle,
                        description: widget.copy.piEnabledModelsDescription,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SettingsTextEditor(
                              fieldKey: const Key('pi-enabled-models-field'),
                              controller: _enabledModelsController,
                              hintText: widget.copy.piEnabledModelsHint,
                              minLines: 3,
                              maxLines: 6,
                            ),
                            const SizedBox(height: 12),
                            if (snapshot.settingsJsonParseError != null) ...[
                              _PiConfigErrorText(
                                widget.copy.piJsonParseErrorLabel(
                                  'settings.json',
                                  snapshot.settingsJsonParseError!,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Align(
                              alignment: Alignment.centerRight,
                              child: _SettingsActionButton(
                                buttonKey: const Key(
                                  'save-pi-model-settings-button',
                                ),
                                label: widget.copy.piSaveActionLabel,
                                onPressed: _savingModelPreferences
                                    ? null
                                    : _handleSaveModelPreferences,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 42),
                Text(
                  widget.copy.piModelsJsonSectionTitle,
                  style: _AppTypography.settingsSectionTitle(palette),
                ),
                const SizedBox(height: 14),
                _SettingsCard(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.copy.piModelsJsonDescription,
                          style: _AppTypography.settingsRowDescription(palette),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.copy.piCustomProvidersSummary(
                            snapshot.modelsSummary.providerCount,
                          ),
                          style: _AppTypography.controlLabel(palette),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.copy.piCustomModelsSummary(
                            snapshot.modelsSummary.customModelCount,
                          ),
                          style: _AppTypography.controlLabel(palette),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.copy.piAuthProvidersSummary(
                            snapshot.authProviderCount,
                            fileExists: snapshot.authFileExists,
                          ),
                          style: _AppTypography.controlLabel(palette),
                        ),
                        if (snapshot.modelsJsonParseError != null) ...[
                          const SizedBox(height: 12),
                          _PiConfigErrorText(
                            widget.copy.piJsonParseErrorLabel(
                              'models.json',
                              snapshot.modelsJsonParseError!,
                            ),
                          ),
                        ],
                        if (snapshot.authJsonParseError != null) ...[
                          const SizedBox(height: 12),
                          _PiConfigErrorText(
                            widget.copy.piJsonParseErrorLabel(
                              'auth.json',
                              snapshot.authJsonParseError!,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _SettingsTextEditor(
                          fieldKey: const Key('pi-models-json-editor'),
                          controller: _modelsJsonController,
                          hintText: '{\n  "providers": {}\n}',
                          minLines: 10,
                          maxLines: 18,
                          codeFont: widget.preferences.codeFont,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _SettingsActionButton(
                            buttonKey: const Key('save-pi-models-json-button'),
                            label: widget.copy.piSaveActionLabel,
                            onPressed: _savingModelsJson
                                ? null
                                : _handleSaveModelsJson,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PiPromptsSettingsContent extends StatefulWidget {
  const _PiPromptsSettingsContent({
    required this.copy,
    required this.preferences,
    required this.snapshot,
    required this.loadError,
    required this.onSavePromptFile,
  });

  final SettingsCopy copy;
  final AppPreferences preferences;
  final PiConfigSnapshot? snapshot;
  final String? loadError;
  final Future<void> Function(PiPromptFileKind kind, String content)
  onSavePromptFile;

  @override
  State<_PiPromptsSettingsContent> createState() =>
      _PiPromptsSettingsContentState();
}

class _PiPromptsSettingsContentState extends State<_PiPromptsSettingsContent> {
  late final TextEditingController _systemController;
  late final TextEditingController _appendSystemController;
  late final TextEditingController _agentsController;

  String _lastPromptSignature = '';
  final Set<PiPromptFileKind> _savingKinds = <PiPromptFileKind>{};

  @override
  void initState() {
    super.initState();
    _systemController = TextEditingController();
    _appendSystemController = TextEditingController();
    _agentsController = TextEditingController();
    _applySnapshot(widget.snapshot, force: true);
  }

  @override
  void didUpdateWidget(covariant _PiPromptsSettingsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applySnapshot(widget.snapshot);
  }

  @override
  void dispose() {
    _systemController.dispose();
    _appendSystemController.dispose();
    _agentsController.dispose();
    super.dispose();
  }

  void _applySnapshot(PiConfigSnapshot? snapshot, {bool force = false}) {
    if (snapshot == null) {
      return;
    }

    final signature = [
      snapshot.systemPrompt.content,
      snapshot.appendSystemPrompt.content,
      snapshot.globalAgents.content,
    ].join('||');

    if (!force && signature == _lastPromptSignature) {
      return;
    }

    _lastPromptSignature = signature;
    _systemController.text = snapshot.systemPrompt.content;
    _appendSystemController.text = snapshot.appendSystemPrompt.content;
    _agentsController.text = snapshot.globalAgents.content;
  }

  Future<void> _handleSavePrompt(
    PiPromptFileKind kind,
    TextEditingController controller,
  ) async {
    setState(() {
      _savingKinds.add(kind);
    });

    try {
      await widget.onSavePromptFile(kind, controller.text);
    } finally {
      if (mounted) {
        setState(() {
          _savingKinds.remove(kind);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loadError != null) {
      return _SettingsPlaceholderContent(
        title: widget.copy.piPromptsTitle,
        body: widget.copy.piConfigLoadFailedBody(widget.loadError!),
      );
    }

    final snapshot = widget.snapshot;
    if (snapshot == null) {
      return _SettingsPlaceholderContent(
        title: widget.copy.piPromptsTitle,
        body: widget.copy.piConfigLoadingLabel,
      );
    }

    final palette = context.appPalette;

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(64, 54, 64, 54),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 890),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.copy.piPromptsTitle,
                  key: const Key('pi-prompts-page-title'),
                  style: _AppTypography.settingsPageTitle(palette),
                ),
                const SizedBox(height: 46),
                Text(
                  widget.copy.piConfigRootSectionTitle,
                  style: _AppTypography.settingsSectionTitle(palette),
                ),
                const SizedBox(height: 14),
                _PiConfigLocationCard(copy: widget.copy, snapshot: snapshot),
                const SizedBox(height: 42),
                _PiPromptEditorCard(
                  title: widget.copy.piSystemPromptTitle,
                  description: widget.copy.piSystemPromptDescription,
                  path: snapshot.systemPrompt.path,
                  fieldKey: const Key('pi-system-prompt-editor'),
                  buttonKey: const Key('save-pi-system-prompt-button'),
                  controller: _systemController,
                  hintText: widget.copy.piPromptEditorHint,
                  saving: _savingKinds.contains(PiPromptFileKind.system),
                  saveLabel: widget.copy.piSaveActionLabel,
                  onSave: () => _handleSavePrompt(
                    PiPromptFileKind.system,
                    _systemController,
                  ),
                ),
                const SizedBox(height: 18),
                _PiPromptEditorCard(
                  title: widget.copy.piAppendSystemPromptTitle,
                  description: widget.copy.piAppendSystemPromptDescription,
                  path: snapshot.appendSystemPrompt.path,
                  fieldKey: const Key('pi-append-system-prompt-editor'),
                  buttonKey: const Key('save-pi-append-system-prompt-button'),
                  controller: _appendSystemController,
                  hintText: widget.copy.piPromptEditorHint,
                  saving: _savingKinds.contains(PiPromptFileKind.appendSystem),
                  saveLabel: widget.copy.piSaveActionLabel,
                  onSave: () => _handleSavePrompt(
                    PiPromptFileKind.appendSystem,
                    _appendSystemController,
                  ),
                ),
                const SizedBox(height: 18),
                _PiPromptEditorCard(
                  title: widget.copy.piGlobalAgentsTitle,
                  description: widget.copy.piGlobalAgentsDescription,
                  path: snapshot.globalAgents.path,
                  fieldKey: const Key('pi-agents-prompt-editor'),
                  buttonKey: const Key('save-pi-agents-prompt-button'),
                  controller: _agentsController,
                  hintText: widget.copy.piPromptEditorHint,
                  saving: _savingKinds.contains(PiPromptFileKind.agents),
                  saveLabel: widget.copy.piSaveActionLabel,
                  onSave: () => _handleSavePrompt(
                    PiPromptFileKind.agents,
                    _agentsController,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PiPromptEditorCard extends StatelessWidget {
  const _PiPromptEditorCard({
    required this.title,
    required this.description,
    required this.path,
    required this.fieldKey,
    required this.buttonKey,
    required this.controller,
    required this.hintText,
    required this.saving,
    required this.saveLabel,
    required this.onSave,
  });

  final String title;
  final String description;
  final String path;
  final Key fieldKey;
  final Key buttonKey;
  final TextEditingController controller;
  final String hintText;
  final bool saving;
  final String saveLabel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return _SettingsCard(
      child: Padding(
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
            const SizedBox(height: 8),
            _PiConfigPathLine(label: 'Path', value: path),
            const SizedBox(height: 12),
            _SettingsTextEditor(
              fieldKey: fieldKey,
              controller: controller,
              hintText: hintText,
              minLines: 8,
              maxLines: 16,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: _SettingsActionButton(
                buttonKey: buttonKey,
                label: saveLabel,
                onPressed: saving ? null : onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PiConfigLocationCard extends StatelessWidget {
  const _PiConfigLocationCard({required this.copy, required this.snapshot});

  final SettingsCopy copy;
  final PiConfigSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return _SettingsCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy.piConfigRootDescription,
              style: _AppTypography.settingsRowDescription(palette),
            ),
            const SizedBox(height: 12),
            _PiConfigPathLine(
              label: copy.piConfigDirectoryTitle,
              value: snapshot.rootPath,
            ),
            const SizedBox(height: 6),
            _PiConfigPathLine(
              label: 'Source',
              value: copy.piConfigRootSourceLabel(snapshot.rootSource),
            ),
            const SizedBox(height: 6),
            Text(
              copy.piConfigDirectoryDescription(
                snapshot.usesEnvironmentOverride,
              ),
              style: _AppTypography.placeholderBody(palette),
            ),
            const SizedBox(height: 12),
            _PiConfigPathLine(
              label: copy.piConfigSettingsFileLabel,
              value: snapshot.settingsFilePath,
            ),
            const SizedBox(height: 6),
            _PiConfigPathLine(
              label: copy.piConfigModelsFileLabel,
              value: snapshot.modelsFilePath,
            ),
            const SizedBox(height: 6),
            _PiConfigPathLine(
              label: copy.piConfigAuthFileLabel,
              value: snapshot.authFilePath,
            ),
            const SizedBox(height: 6),
            _PiConfigPathLine(
              label: copy.piConfigSystemPromptFileLabel,
              value: snapshot.systemPrompt.path,
            ),
            const SizedBox(height: 6),
            _PiConfigPathLine(
              label: copy.piConfigAppendSystemFileLabel,
              value: snapshot.appendSystemPrompt.path,
            ),
            const SizedBox(height: 6),
            _PiConfigPathLine(
              label: copy.piConfigAgentsFileLabel,
              value: snapshot.globalAgents.path,
            ),
          ],
        ),
      ),
    );
  }
}

class _PiConfigPathLine extends StatelessWidget {
  const _PiConfigPathLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _AppTypography.settingsGroupLabel(palette)),
        const SizedBox(height: 2),
        SelectableText(value, style: _AppTypography.controlLabel(palette)),
      ],
    );
  }
}

class _PiConfigErrorText extends StatelessWidget {
  const _PiConfigErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(
        color: Theme.of(context).colorScheme.error,
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        height: 1.3,
      ),
    );
  }
}

List<String> _parseEnabledModels(String rawText) {
  final items = rawText
      .split(RegExp(r'[\n,]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  return items;
}
