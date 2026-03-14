import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.settings, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.aiConfiguration, style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: settings.baseUrl,
                  decoration: InputDecoration(
                    labelText: l10n.apiBaseUrl,
                    border: const OutlineInputBorder(),
                    helperText: 'e.g. https://api.openai.com',
                  ),
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setBaseUrl(value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: settings.modelName,
                  decoration: InputDecoration(
                    labelText: l10n.modelName,
                    border: const OutlineInputBorder(),
                    helperText: 'e.g. gpt-4-vision-preview, gemini-1.5-pro',
                  ),
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setModelName(value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: settings.apiKey,
                  decoration: InputDecoration(
                    labelText: l10n.apiKey,
                    border: const OutlineInputBorder(),
                    helperText: 'sk-...',
                  ),
                  obscureText: true,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setApiKey(value);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(l10n.reader, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                title: Text(l10n.summaryProfiles),
                subtitle: Text(settings.selectedSummaryProfile.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showSummaryProfilesSheet(context),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(l10n.autoGenerate),
                subtitle: Text(l10n.autoGenerateSubtitle),
                value: settings.autoGenerate,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setAutoGenerate(value);
                },
              ),
              SwitchListTile(
                title: Text(l10n.pseudoKBMode),
                subtitle: Text(l10n.pseudoKBModeSubtitle),
                value: settings.enablePseudoKBMode,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setEnablePseudoKBMode(value);
                },
              ),
              SwitchListTile(
                title: Text(l10n.smoothSummary),
                subtitle: Text(l10n.smoothSummarySubtitle),
                value: settings.smoothSummary,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setSmoothSummary(value);
                },
              ),
              SwitchListTile(
                title: Text(l10n.powerSavingMode),
                subtitle: Text(l10n.powerSavingModeSubtitle),
                value: settings.powerSavingMode,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setPowerSavingMode(value);
                },
              ),
              if (settings.autoGenerate)
                ListTile(
                  title: Text(l10n.debounceDelay),
                  subtitle: Text(l10n.debounceDelaySubtitle(settings.debounceSeconds)),
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      value: settings.debounceSeconds.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '${settings.debounceSeconds}s',
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).setDebounceSeconds(value.round());
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.appearance, style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                Text(l10n.themeMode, style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                SegmentedButton<AppThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: AppThemeMode.system,
                      label: Text(l10n.followSystem),
                      icon: const Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.light,
                      label: Text(l10n.lightMode),
                      icon: const Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.dark,
                      label: Text(l10n.darkMode),
                      icon: const Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (Set<AppThemeMode> newSelection) {
                    ref.read(settingsProvider.notifier).setThemeMode(newSelection.first);
                  },
                ),
                const SizedBox(height: 20),
                Text(l10n.readingDirection, style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                SegmentedButton<ReadingDirection>(
                  segments: [
                    ButtonSegment(
                      value: ReadingDirection.vertical,
                      label: Text(l10n.vertical),
                      icon: const Icon(Icons.swap_vert),
                    ),
                    ButtonSegment(
                      value: ReadingDirection.horizontal,
                      label: Text(l10n.horizontal),
                      icon: const Icon(Icons.swap_horiz),
                    ),
                  ],
                  selected: {settings.readingDirection},
                  onSelectionChanged: (Set<ReadingDirection> newSelection) {
                    ref.read(settingsProvider.notifier).setReadingDirection(newSelection.first);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showSummaryProfilesSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Consumer(
              builder: (context, ref, _) {
                final settings = ref.watch(settingsProvider);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.summaryProfiles,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _showProfileEditor(context),
                          icon: const Icon(Icons.add),
                          label: Text(l10n.createProfile),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: settings.summaryProfiles.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final profile = settings.summaryProfiles[index];
                          final isSelected = profile.id == settings.selectedSummaryProfileId;

                          return ListTile(
                            title: Text(profile.name),
                            subtitle: Text(
                              profile.isBuiltIn
                                  ? l10n.defaultSummaryProfileSubtitle
                                  : profile.prompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            leading: isSelected ? const Icon(Icons.check_circle) : const Icon(Icons.radio_button_unchecked),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined),
                                  onPressed: () => _showProfileViewer(context, profile),
                                  tooltip: l10n.viewProfile,
                                ),
                                if (!profile.isBuiltIn)
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _showProfileEditor(context, profile: profile),
                                    tooltip: l10n.editProfile,
                                  ),
                                if (!profile.isBuiltIn)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      ref.read(settingsProvider.notifier).deleteSummaryProfile(profile.id);
                                    },
                                    tooltip: l10n.deleteProfile,
                                  ),
                              ],
                            ),
                            onTap: () {
                              ref.read(settingsProvider.notifier).setSelectedSummaryProfile(profile.id);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showProfileEditor(BuildContext context, {SummaryProfile? profile}) async {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = profile != null;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return _SummaryProfileEditorDialog(
          profile: profile,
          isEditing: isEditing,
          onSave: (name, prompt) {
            final notifier = ref.read(settingsProvider.notifier);
            if (isEditing) {
              notifier.updateSummaryProfile(
                profile!.copyWith(
                  name: name,
                  prompt: prompt,
                ),
              );
            } else {
              notifier.addSummaryProfile(name: name, prompt: prompt);
            }
          },
        );
      },
    );
  }

  Future<void> _showProfileViewer(BuildContext context, SummaryProfile profile) async {
    final l10n = AppLocalizations.of(context)!;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(profile.name),
          content: SizedBox(
            width: 520,
            child: SelectableText(profile.prompt),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: profile.prompt));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(l10n.promptCopied)),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: Text(l10n.copyPrompt),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.closePanel),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryProfileEditorDialog extends StatefulWidget {
  final SummaryProfile? profile;
  final bool isEditing;
  final void Function(String name, String prompt) onSave;

  const _SummaryProfileEditorDialog({
    required this.profile,
    required this.isEditing,
    required this.onSave,
  });

  @override
  State<_SummaryProfileEditorDialog> createState() => _SummaryProfileEditorDialogState();
}

class _SummaryProfileEditorDialogState extends State<_SummaryProfileEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    _promptController = TextEditingController(text: widget.profile?.prompt ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(widget.isEditing ? l10n.editProfile : l10n.createProfile),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.profileName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _promptController,
              minLines: 6,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: l10n.promptTemplate,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final prompt = _promptController.text.trim();
            if (name.isEmpty || prompt.isEmpty) return;

            widget.onSave(name, prompt);
            Navigator.of(context).pop();
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
