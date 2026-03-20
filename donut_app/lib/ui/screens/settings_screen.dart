import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../legal/legal_documents.dart';
import '../../l10n/app_localizations.dart';
import '../../services/debug_log_service.dart';
import '../../services/settings_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.settings, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.smart_toy_outlined),
                title: Text(l10n.aiConfiguration),
                subtitle: Text(l10n.aiCategorySubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openSubPage(
                  l10n.aiConfiguration,
                  _buildAiConfigurationPage(),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.chrome_reader_mode_outlined),
                title: Text(l10n.reader),
                subtitle: Text(l10n.readerCategorySubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openSubPage(l10n.reader, _buildReaderPage()),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(l10n.appearance),
                subtitle: Text(l10n.appearanceCategorySubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _openSubPage(l10n.appearance, _buildAppearancePage()),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: Text(l10n.dataAndLegal),
                subtitle: Text(l10n.dataLegalCategorySubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _openSubPage(l10n.dataAndLegal, _buildDataAndLegalPage()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openSubPage(String title, Widget body) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: body,
          );
        },
      ),
    );
  }

  Widget _buildAiConfigurationPage() {
    return Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(settingsProvider);
        final l10n = AppLocalizations.of(context)!;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: settings.baseUrl,
                      decoration: InputDecoration(
                        labelText: l10n.apiBaseUrl,
                        border: const OutlineInputBorder(),
                        helperText: 'Donut gateway base URL',
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
                        helperText: 'Managed Donut client key',
                      ),
                      obscureText: true,
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).setApiKey(value);
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.modelReplyLength),
                      subtitle: Text(l10n.modelReplyLengthSubtitle),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _replyLengthLabel(l10n, settings.modelReplyLength),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => _showModelReplyLengthSheet(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReaderPage() {
    return Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(settingsProvider);
        final l10n = AppLocalizations.of(context)!;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
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
                      ref
                          .read(settingsProvider.notifier)
                          .setAutoGenerate(value);
                    },
                  ),
                  SwitchListTile(
                    title: Text(l10n.pseudoKBMode),
                    subtitle: Text(l10n.pseudoKBModeSubtitle),
                    value: settings.enablePseudoKBMode,
                    onChanged: (value) {
                      ref
                          .read(settingsProvider.notifier)
                          .setEnablePseudoKBMode(value);
                    },
                  ),
                  SwitchListTile(
                    title: Text(l10n.smoothSummary),
                    subtitle: Text(l10n.smoothSummarySubtitle),
                    value: settings.smoothSummary,
                    onChanged: (value) {
                      ref
                          .read(settingsProvider.notifier)
                          .setSmoothSummary(value);
                    },
                  ),
                  SwitchListTile(
                    title: Text(l10n.powerSavingMode),
                    subtitle: Text(l10n.powerSavingModeSubtitle),
                    value: settings.powerSavingMode,
                    onChanged: (value) {
                      ref
                          .read(settingsProvider.notifier)
                          .setPowerSavingMode(value);
                    },
                  ),
                  if (settings.autoGenerate)
                    ListTile(
                      title: Text(l10n.debounceDelay),
                      subtitle: Text(
                        l10n.debounceDelaySubtitle(settings.debounceSeconds),
                      ),
                      trailing: SizedBox(
                        width: 150,
                        child: Slider(
                          value: settings.debounceSeconds.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: '${settings.debounceSeconds}s',
                          onChanged: (value) {
                            ref
                                .read(settingsProvider.notifier)
                                .setDebounceSeconds(value.round());
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppearancePage() {
    return Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(settingsProvider);
        final l10n = AppLocalizations.of(context)!;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.themeMode,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
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
                        ref
                            .read(settingsProvider.notifier)
                            .setThemeMode(newSelection.first);
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.readingDirection,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
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
                        ref
                            .read(settingsProvider.notifier)
                            .setReadingDirection(newSelection.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDataAndLegalPage() {
    return Consumer(
      builder: (context, ref, _) {
        final l10n = AppLocalizations.of(context)!;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(l10n.importSettings),
                    subtitle: Text(l10n.importSettingsSubtitle),
                    trailing: const Icon(Icons.file_download_outlined),
                    onTap: _importSettingsFromFile,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(l10n.exportSettings),
                    subtitle: Text(l10n.exportSettingsSubtitle),
                    trailing: const Icon(Icons.file_upload_outlined),
                    onTap: _exportSettingsToFile,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(l10n.settingsHistory),
                    subtitle: Text(l10n.settingsHistorySubtitle),
                    trailing: const Icon(Icons.history_outlined),
                    onTap: _showSettingsHistorySheet,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(l10n.exportDebugLogs),
                    subtitle: Text(l10n.exportDebugLogsSubtitle),
                    trailing: const Icon(Icons.bug_report_outlined),
                    onTap: _exportDebugLogs,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(l10n.termsOfService),
                    subtitle: Text(l10n.termsOfServiceSubtitle),
                    trailing: const Icon(Icons.description_outlined),
                    onTap: () {
                      _showLegalDocument(
                        title: l10n.termsOfService,
                        content: termsOfServiceText(
                          Localizations.localeOf(context),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(l10n.privacyPolicy),
                    subtitle: Text(l10n.privacyPolicySubtitle),
                    trailing: const Icon(Icons.privacy_tip_outlined),
                    onTap: () {
                      _showLegalDocument(
                        title: l10n.privacyPolicy,
                        content: privacyPolicyText(
                          Localizations.localeOf(context),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(l10n.openSourceLicenses),
                    subtitle: Text(l10n.openSourceLicensesSubtitle),
                    trailing: const Icon(Icons.balance_outlined),
                    onTap: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'Donut',
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importSettingsFromFile() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        dialogTitle: l10n.pickSettingsJson,
      );
      if (result == null || result.files.single.path == null) return;

      final importResult = await ref
          .read(settingsProvider.notifier)
          .importSettingsFromFile(result.files.single.path!);

      if (!mounted) return;

      if (importResult.success) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.importSettingsSuccess)),
        );
        return;
      }

      final message = switch (importResult.error) {
        SettingsImportError.invalidJson => l10n.importSettingsInvalidJson,
        SettingsImportError.invalidStructure =>
          l10n.importSettingsInvalidStructure,
        SettingsImportError.io || null => l10n.importSettingsIoError,
      };
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.importSettingsIoError)),
      );
    }
  }

  Future<void> _exportSettingsToFile() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final filePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.saveSettingsJson,
        fileName: 'donut_settings.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (filePath == null) return;

      final normalizedPath = filePath.endsWith('.json')
          ? filePath
          : '$filePath.json';
      await ref
          .read(settingsProvider.notifier)
          .exportSettingsToFile(normalizedPath);

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.exportSettingsSuccess)),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.exportSettingsIoError)),
      );
    }
  }

  Future<void> _exportDebugLogs() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final sourcePath = await DebugLogService.getLogFilePath();
      final filePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.saveDebugLog,
        fileName: 'donut_debug.log',
        type: FileType.custom,
        allowedExtensions: const ['log', 'txt'],
      );
      if (filePath == null) return;

      final normalizedPath =
          filePath.endsWith('.log') || filePath.endsWith('.txt')
          ? filePath
          : '$filePath.log';
      await File(sourcePath).copy(normalizedPath);

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.exportDebugLogsSuccess)),
      );
    } catch (e) {
      await DebugLogService.log('Export debug logs failed err=$e', tag: 'LOG');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.exportDebugLogsFailed)),
      );
    }
  }

  Future<void> _showSettingsHistorySheet() async {
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 500,
            child: FutureBuilder<List<SettingsBackupEntry>>(
              future: ref.read(settingsProvider.notifier).listSettingsHistory(),
              builder: (context, snapshot) {
                final entries = snapshot.data ?? const <SettingsBackupEntry>[];

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (entries.isEmpty) {
                  return Center(child: Text(l10n.settingsHistoryEmpty));
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.settingsHistory,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = entries[index];
                          final formattedTime = DateFormat(
                            'yyyy-MM-dd HH:mm:ss',
                          ).format(item.modifiedAt.toLocal());
                          return ListTile(
                            title: Text(item.fileName),
                            subtitle: Text(formattedTime),
                            trailing: FilledButton.tonal(
                              onPressed: () async {
                                final navigator = Navigator.of(sheetContext);
                                final messenger = ScaffoldMessenger.of(
                                  this.context,
                                );
                                final result = await ref
                                    .read(settingsProvider.notifier)
                                    .restoreFromHistory(item.filePath);
                                if (!mounted) return;
                                if (result.success) {
                                  navigator.pop();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.settingsHistoryRestoreSuccess,
                                      ),
                                    ),
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.settingsHistoryRestoreFailed,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Text(l10n.restore),
                            ),
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

  Future<void> _showLegalDocument({
    required String title,
    required String content,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(child: SelectableText(content)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.closePanel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showModelReplyLengthSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Consumer(
            builder: (context, ref, _) {
              final settings = ref.watch(settingsProvider);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.modelReplyLength,
                            textAlign: TextAlign.left,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.modelReplyLengthSubtitle,
                            textAlign: TextAlign.left,
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (final option in ModelReplyLength.values)
                    ListTile(
                      title: Text(_replyLengthLabel(l10n, option)),
                      trailing: settings.modelReplyLength == option
                          ? const Icon(Icons.check_circle)
                          : const Icon(Icons.radio_button_unchecked),
                      onTap: () {
                        ref
                            .read(settingsProvider.notifier)
                            .setModelReplyLength(option);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _replyLengthLabel(AppLocalizations l10n, ModelReplyLength value) {
    return switch (value) {
      ModelReplyLength.short => l10n.modelReplyLengthShort,
      ModelReplyLength.medium => l10n.modelReplyLengthMedium,
      ModelReplyLength.long => l10n.modelReplyLengthLong,
      ModelReplyLength.unlimited => l10n.modelReplyLengthUnlimited,
    };
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
                          final isSelected =
                              profile.id == settings.selectedSummaryProfileId;

                          return ListTile(
                            title: Text(profile.name),
                            subtitle: Text(
                              profile.isBuiltIn
                                  ? l10n.defaultSummaryProfileSubtitle
                                  : profile.prompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            leading: isSelected
                                ? const Icon(Icons.check_circle)
                                : const Icon(Icons.radio_button_unchecked),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined),
                                  onPressed: () =>
                                      _showProfileViewer(context, profile),
                                  tooltip: l10n.viewProfile,
                                ),
                                if (!profile.isBuiltIn)
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _showProfileEditor(
                                      context,
                                      profile: profile,
                                    ),
                                    tooltip: l10n.editProfile,
                                  ),
                                if (!profile.isBuiltIn)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      ref
                                          .read(settingsProvider.notifier)
                                          .deleteSummaryProfile(profile.id);
                                    },
                                    tooltip: l10n.deleteProfile,
                                  ),
                              ],
                            ),
                            onTap: () {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setSelectedSummaryProfile(profile.id);
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

  Future<void> _showProfileEditor(
    BuildContext context, {
    SummaryProfile? profile,
  }) async {
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
                profile.copyWith(name: name, prompt: prompt),
              );
            } else {
              notifier.addSummaryProfile(name: name, prompt: prompt);
            }
          },
        );
      },
    );
  }

  Future<void> _showProfileViewer(
    BuildContext context,
    SummaryProfile profile,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(profile.name),
          content: SizedBox(width: 520, child: SelectableText(profile.prompt)),
          actions: [
            TextButton.icon(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(this.context);
                await Clipboard.setData(ClipboardData(text: profile.prompt));
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.promptCopied)),
                );
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
  State<_SummaryProfileEditorDialog> createState() =>
      _SummaryProfileEditorDialogState();
}

class _SummaryProfileEditorDialogState
    extends State<_SummaryProfileEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    _promptController = TextEditingController(
      text: widget.profile?.prompt ?? '',
    );
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
