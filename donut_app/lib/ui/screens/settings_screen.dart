import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rosemary_updater/rosemary_updater.dart';
import 'package:share_plus/share_plus.dart';

import '../../legal/legal_documents.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/client_config_service.dart';
import '../../services/debug_log_service.dart';
import '../../services/model_connection_service.dart';
import '../../services/rosemary_update_service.dart';
import '../../services/settings_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.openAiConfigurationOnStart = false});

  final bool openAiConfigurationOnStart;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isTestingCustomConnection = false;
  bool _isCheckingRosemaryUpdate = false;
  bool _didAutoOpenInitialSection = false;

  bool get _useShareBasedExport =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<File> _prepareSharedExportFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory(p.join(tempDir.path, 'exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final exportFile = File(p.join(exportDir.path, fileName));
    await exportFile.writeAsBytes(bytes, flush: true);
    return exportFile;
  }

  Future<File> _prepareSharedCopy({
    required String sourcePath,
    required String fileName,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory(p.join(tempDir.path, 'exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final exportFile = File(p.join(exportDir.path, fileName));
    if (await exportFile.exists()) {
      await exportFile.delete();
    }
    return File(sourcePath).copy(exportFile.path);
  }

  Future<bool> _shareExportedFile({
    required File file,
    required String title,
    String? text,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        title: title,
        text: text,
        sharePositionOrigin: _sharePositionOrigin(),
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  Rect _sharePositionOrigin() {
    Rect? rectFromRenderObject(RenderObject? renderObject) {
      if (renderObject is! RenderBox || !renderObject.hasSize) return null;
      final size = renderObject.size;
      if (size.width <= 0 || size.height <= 0) return null;
      final origin = renderObject.localToGlobal(Offset.zero);
      return Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);
    }

    final overlayRect = rectFromRenderObject(
      Overlay.maybeOf(context)?.context.findRenderObject(),
    );
    final directRect = rectFromRenderObject(context.findRenderObject());
    if (directRect != null && overlayRect != null) {
      final visibleRect = directRect.intersect(overlayRect);
      if (visibleRect.width > 0 && visibleRect.height > 0) {
        return visibleRect;
      }
    }

    if (overlayRect != null) {
      return Rect.fromCenter(center: overlayRect.center, width: 1, height: 1);
    }

    final mediaSize = MediaQuery.sizeOf(context);
    final safeWidth = mediaSize.width <= 0 ? 1.0 : mediaSize.width;
    final safeHeight = mediaSize.height <= 0 ? 1.0 : mediaSize.height;
    return Rect.fromCenter(
      center: Offset(safeWidth / 2, safeHeight / 2),
      width: 1,
      height: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (widget.openAiConfigurationOnStart && !_didAutoOpenInitialSection) {
      _didAutoOpenInitialSection = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openSubPage(l10n.aiConfiguration, _buildAiConfigurationPage());
      });
    }

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
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.system_update_alt_outlined),
                title: Text(l10n.checkAppUpdateTitle),
                subtitle: Text(
                  l10n.checkAppUpdateSubtitle(_currentPlatformLabel(l10n)),
                ),
                trailing: _isCheckingRosemaryUpdate
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _isCheckingRosemaryUpdate ? null : _checkRosemaryUpdate,
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
        final authState = ref.watch(authControllerProvider);
        final clientConfigAsync = ref.watch(clientConfigProvider);
        final l10n = AppLocalizations.of(context)!;
        final clientConfig = clientConfigAsync.maybeWhen(
          data: (value) => value,
          orElse: () => null,
        );
        final serverModelDescriptors =
            clientConfig?.serverModels
                .where((item) => item.supportsChat)
                .toList() ??
            const [];
        final serverModels = serverModelDescriptors
            .map((item) => item.name)
            .toList();
        final selectedModelOption = settings.useCustomModelConfig
            ? '__custom__'
            : settings.selectedServerModelName;

        if (authState.isAuthenticated &&
            !settings.useCustomModelConfig &&
            clientConfig != null &&
            serverModels.isNotEmpty &&
            !serverModels.contains(settings.selectedServerModelName)) {
          Future<void>.microtask(() {
            if (!mounted) return;
            ref
                .read(settingsProvider.notifier)
                .setSelectedServerModelName(
                  serverModels.contains(clientConfig.defaultModel)
                      ? clientConfig.defaultModel
                      : serverModels.first,
                );
          });
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Column(
                children: [
                  if (authState.isAuthenticated) ...[
                    for (final model in serverModels)
                      (() {
                        final descriptor = serverModelDescriptors.firstWhere(
                          (item) => item.name == model,
                        );
                        final subtitleParts = <String>[
                          l10n.serverModelSelection,
                          'x${descriptor.multiplier.toStringAsFixed(descriptor.multiplier % 1 == 0 ? 0 : 1)}',
                          if (!descriptor.supportsSummary)
                            l10n.chatOnlyModelTag,
                        ];
                        return Column(
                          children: [
                            RadioListTile<String>(
                              value: model,
                              groupValue: selectedModelOption,
                              onChanged: (_) {
                                ref
                                    .read(settingsProvider.notifier)
                                    .setUseCustomModelConfig(false);
                                ref
                                    .read(settingsProvider.notifier)
                                    .setSelectedServerModelName(model);
                              },
                              title: Row(
                                children: [
                                  Expanded(child: Text(model)),
                                  if (descriptor.recommended)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        l10n.recommendedModelTag,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(subtitleParts.join(' · ')),
                              selected:
                                  !settings.useCustomModelConfig &&
                                  settings.selectedServerModelName == model,
                            ),
                            if (model != serverModels.last)
                              const Divider(height: 1),
                          ],
                        );
                      })(),
                    if (clientConfigAsync.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (!clientConfigAsync.isLoading && serverModels.isEmpty)
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text(l10n.serverModelsUnavailable),
                      ),
                  ] else
                    ListTile(
                      enabled: false,
                      leading: const Icon(Icons.lock_outline),
                      title: Text(l10n.loginForAiService),
                      subtitle: Text(l10n.loginForAiServiceSubtitle),
                    ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    value: '__custom__',
                    groupValue: selectedModelOption,
                    onChanged: (_) {
                      ref
                          .read(settingsProvider.notifier)
                          .setUseCustomModelConfig(true);
                    },
                    title: Text(l10n.customModelOption),
                    subtitle: Text(l10n.customModelOptionSubtitle),
                  ),
                  if (settings.useCustomModelConfig) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.customConnectionTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.customConnectionHint,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: settings.baseUrl,
                            decoration: InputDecoration(
                              labelText: l10n.apiBaseUrl,
                              border: const OutlineInputBorder(),
                              helperText: 'e.g. https://api.openai.com/v1',
                            ),
                            onChanged: (value) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setBaseUrl(value);
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: settings.modelName,
                            decoration: InputDecoration(
                              labelText: l10n.modelName,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setModelName(value);
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
                              ref
                                  .read(settingsProvider.notifier)
                                  .setApiKey(value);
                            },
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _isTestingCustomConnection
                                ? null
                                : () => _testCustomConnection(
                                    settings.baseUrl,
                                    settings.apiKey,
                                    l10n,
                                  ),
                            icon: _isTestingCustomConnection
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.network_check_rounded),
                            label: Text(
                              _isTestingCustomConnection
                                  ? l10n.testingConnection
                                  : l10n.testConnection,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
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
          ],
        );
      },
    );
  }

  Future<void> _testCustomConnection(
    String baseUrl,
    String apiKey,
    AppLocalizations l10n,
  ) async {
    setState(() {
      _isTestingCustomConnection = true;
    });
    try {
      final result = await ModelConnectionService().test(
        baseUrl: baseUrl,
        apiKey: apiKey,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.testConnectionSuccess(result.modelCount))),
      );
    } on ModelConnectionException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.testConnectionFailed)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.testConnectionFailed)));
    } finally {
      if (mounted) {
        setState(() {
          _isTestingCustomConnection = false;
        });
      }
    }
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
                  SwitchListTile(
                    title: Text(l10n.swapReaderPanels),
                    subtitle: Text(l10n.swapReaderPanelsSubtitle),
                    value: settings.readerPanelsSwapped,
                    onChanged: (value) {
                      ref
                          .read(settingsProvider.notifier)
                          .setReaderPanelsSwapped(value);
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
      if (_useShareBasedExport) {
        final exportFile = await _prepareSharedExportFile(
          fileName: 'donut_settings.json',
          bytes: utf8.encode(
            ref
                .read(settingsProvider.notifier)
                .exportSettingsAsJson(pretty: true),
          ),
        );
        final didShare = await _shareExportedFile(
          file: exportFile,
          title: l10n.saveSettingsJson,
          text: 'Donut settings',
        );
        if (!mounted || !didShare) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.exportSettingsSuccess)),
        );
        return;
      }

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
      if (_useShareBasedExport) {
        final exportFile = await _prepareSharedCopy(
          sourcePath: sourcePath,
          fileName: 'donut_debug.log',
        );
        final didShare = await _shareExportedFile(
          file: exportFile,
          title: l10n.saveDebugLog,
          text: 'Donut debug log',
        );
        if (!mounted || !didShare) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.exportDebugLogsSuccess)),
        );
        return;
      }

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
    } catch (e, stackTrace) {
      await DebugLogService.error(
        source: 'LOG',
        message: 'Export debug logs failed.',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.exportDebugLogsFailed)),
      );
    }
  }

  Future<void> _checkRosemaryUpdate() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isCheckingRosemaryUpdate = true;
    });

    try {
      final result = await ref
          .read(rosemaryUpdateServiceProvider)
          .checkUpdate();
      if (!mounted) return;

      switch (result.state) {
        case RosemaryCheckState.unsupportedPlatform:
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.rosemaryUnsupportedPlatform)),
          );
          return;
        case RosemaryCheckState.notConfigured:
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.rosemaryNotConfigured)),
          );
          return;
        case RosemaryCheckState.noUpdate:
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                result.currentVersion == null
                    ? l10n.rosemaryNoUpdate
                    : l10n.rosemaryNoUpdateWithVersion(result.currentVersion!),
              ),
            ),
          );
          return;
        case RosemaryCheckState.failed:
          await DebugLogService.error(
            source: 'ROSEMARY',
            message: 'Check update failed.',
            error: result.errorMessage ?? 'unknown_error',
          );
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.rosemaryCheckFailedBrief)),
          );
          return;
        case RosemaryCheckState.hasUpdate:
          final info = result.updateInfo;
          if (info != null) {
            await _showRosemaryUpdateInfo(info);
          }
          return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingRosemaryUpdate = false;
        });
      }
    }
  }

  Future<void> _showRosemaryUpdateInfo(UpdateReceive info) async {
    final l10n = AppLocalizations.of(context)!;
    final appDescription = _localizedPlatformText(
      info.appUpgradeDescription,
      l10n.rosemaryAppUpdateAvailable,
    );
    final appNotes = _localizedPlatformText(info.appUpgradeNotes, '');
    final resDescription = _localizedPlatformText(
      info.resUpgradeDescription,
      l10n.rosemaryResourceUpdateAvailable,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.rosemaryUpdateAvailableTitle),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (info.appUpgrade) ...[
                    Text(
                      l10n.rosemaryAppUpdateSectionTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(appDescription),
                    if (appNotes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(l10n.rosemaryNotesLabel(appNotes)),
                    ],
                    const SizedBox(height: 12),
                  ],
                  if (info.resUpgrade) ...[
                    Text(
                      l10n.rosemaryResourceUpdateSectionTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(resDescription),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.rosemaryLater),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _runRosemaryUpdate(info);
              },
              icon: const Icon(Icons.download_for_offline_outlined),
              label: Text(l10n.rosemaryStartUpdate),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runRosemaryUpdate(UpdateReceive info) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final requiresMacDmgFlow = _requiresMacDmgExitFlow(info);
    if (requiresMacDmgFlow) {
      final confirmed = await _confirmMacDmgFlow(l10n);
      if (!confirmed) return;
    }
    final notifier = ValueNotifier<UpdateStatus>(
      UpdateStatus(checking: true, message: l10n.rosemaryPreparingUpdate),
    );

    final runFuture =
        ref
            .read(rosemaryUpdateServiceProvider)
            .runUpdate(
              updateInfo: info,
              onStatusChanged: (status) {
                notifier.value = status;
              },
            )
          ..catchError((error, stackTrace) async {
            await DebugLogService.error(
              source: 'ROSEMARY',
              message: 'Update task failed.',
              error: error,
              stackTrace: stackTrace is StackTrace ? stackTrace : null,
            );
            notifier.value = UpdateStatus(
              error: error.toString(),
              message: l10n.rosemaryUpdateFailedCloseAndRetry,
            );
          });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ValueListenableBuilder<UpdateStatus>(
          valueListenable: notifier,
          builder: (context, status, _) {
            final progress = status.progress.clamp(0, 100);
            final isBusy =
                status.checking || status.downloading || status.installing;
            final hasError = status.error != null && status.error!.isNotEmpty;
            final canClose = hasError || !isBusy || status.success;

            return PopScope(
              canPop: canClose,
              child: AlertDialog(
                title: Text(l10n.rosemaryRunningUpdateTitle),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: isBusy ? progress / 100 : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _localizedUpdateStatusMessage(
                          status.message,
                          l10n: l10n,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(l10n.rosemaryProgress(progress)),
                      if (hasError) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.rosemaryUpdateFailedCloseAndRetry,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  if (canClose)
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(l10n.rosemaryClose),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      await runFuture;
      if (!mounted) return;
      final finalStatus = notifier.value;
      if (finalStatus.error != null && finalStatus.error!.isNotEmpty) {
        await DebugLogService.error(
          source: 'ROSEMARY',
          message: 'Update completed with error status.',
          error: finalStatus.error,
          context: {'finalMessage': finalStatus.message},
        );
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.rosemaryUpdateFailedBrief)),
        );
      } else {
        if (requiresMacDmgFlow) {
          await DebugLogService.info(
            source: 'ROSEMARY',
            message: 'macOS DMG opened, app will exit shortly for replacement.',
          );
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          exit(0);
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              finalStatus.message.isEmpty
                  ? l10n.rosemaryUpdateCompleted
                  : _localizedUpdateStatusMessage(
                      finalStatus.message,
                      l10n: l10n,
                    ),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      await DebugLogService.error(
        source: 'ROSEMARY',
        message: 'Update flow threw exception.',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.rosemaryUpdateFailedBrief)),
      );
    } finally {
      notifier.dispose();
    }
  }

  bool _requiresMacDmgExitFlow(UpdateReceive info) {
    if (kIsWeb) return false;
    return Platform.isMacOS &&
        info.appUpgradeInstallKind.toLowerCase().trim() == 'dmg';
  }

  Future<bool> _confirmMacDmgFlow(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.rosemaryMacDmgPromptTitle),
          content: Text(l10n.rosemaryMacDmgPromptBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.rosemaryLater),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.rosemaryMacDmgPromptConfirm),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  String _currentPlatformLabel(AppLocalizations l10n) {
    if (kIsWeb) return l10n.platformWeb;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return l10n.platformAndroid;
      case TargetPlatform.iOS:
        return l10n.platformIos;
      case TargetPlatform.macOS:
        return l10n.platformMacos;
      case TargetPlatform.windows:
        return l10n.platformWindows;
      case TargetPlatform.linux:
        return l10n.platformLinux;
      case TargetPlatform.fuchsia:
        return l10n.platformFuchsia;
    }
  }

  String _stripParentheticalContent(String text) {
    return text
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'（[^）]*）'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _localizedPlatformText(String raw, String fallback) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return fallback;
    final l10n = AppLocalizations.of(context)!;
    final currentPlatform = _currentPlatformLabel(l10n);
    final candidates = normalized
        .split(RegExp(r'[\n;；]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    for (final item in candidates) {
      if (item.contains(currentPlatform)) {
        return _stripParentheticalContent(item);
      }
    }
    return _stripParentheticalContent(normalized);
  }

  String _localizedUpdateStatusMessage(
    String raw, {
    required AppLocalizations l10n,
  }) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return l10n.rosemaryProcessing;
    if (normalized == 'Checking for updates...') return l10n.rosemaryChecking;
    if (normalized == 'No updates available') return l10n.rosemaryNoUpdate;
    if (normalized == 'Downloading app update...') {
      return l10n.rosemaryDownloadingApp;
    }
    if (normalized == 'Installing app update...') {
      return l10n.rosemaryInstallingApp;
    }
    if (normalized == 'Downloading resources...') {
      return l10n.rosemaryDownloadingResources;
    }
    if (normalized == 'Installing resources...') {
      return l10n.rosemaryInstallingResources;
    }
    if (normalized == 'Update completed successfully') {
      return l10n.rosemaryUpdateCompleted;
    }
    if (normalized == 'Update failed') return l10n.rosemaryUpdateFailedBrief;
    if (normalized.startsWith('DMG opened.')) {
      return l10n.rosemaryDmgOpenedHint;
    }
    return _stripParentheticalContent(normalized);
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
