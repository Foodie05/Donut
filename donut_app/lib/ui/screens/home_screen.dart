import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rosemary_updater/rosemary_updater.dart';
import '../../data/models/book.dart';
import '../../data/repositories/book_repository.dart';
import '../../legal/legal_documents.dart';
import '../../services/release_notes.dart';
import '../../services/settings_service.dart';
import '../../services/external_file_open_service.dart';
import '../../services/debug_log_service.dart';
import '../../services/auth_service.dart';
import '../../services/rosemary_update_service.dart';
import '../widgets/book_card.dart';
import 'account_screen.dart';
import 'reader_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import '../../l10n/app_localizations.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _prefSeenVersionCode = 'seen_version_code';
  static const _prefLegalAccepted = 'legal_terms_accepted';
  static const _bookshelfIndex = 0;
  static const _statisticsIndex = 1;
  static const _settingsIndex = 2;
  static const _accountIndex = 3;
  static const _sidebarActionSize = 56.0;

  int _selectedIndex = 0;
  bool _startupHandled = false;
  bool _startupRosemaryChecked = false;
  bool _isImportDialogVisible = false;
  StreamSubscription<String>? _externalFileSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleStartupFlow();
    });
    _externalFileSub = ExternalFileOpenService.paths.listen((path) {
      unawaited(
        DebugLogService.log(
          'External path stream received: $path',
          tag: 'IMPORT',
        ),
      );
      _importBookFromPath(path, openAfterImport: true);
    });
  }

  @override
  void dispose() {
    _externalFileSub?.cancel();
    super.dispose();
  }

  Future<void> _handleStartupFlow() async {
    if (_startupHandled || !mounted) return;
    _startupHandled = true;

    final prefs = ref.read(sharedPreferencesProvider);
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
    final seenVersionCode = prefs.getInt(_prefSeenVersionCode) ?? 0;
    final legalAccepted = prefs.getBool(_prefLegalAccepted) ?? false;
    if (!mounted) return;

    if (seenVersionCode == 0) {
      await _showWelcomeAgreementDialog(packageInfo);
      await prefs.setBool(_prefLegalAccepted, true);
      if (currentVersionCode > 0) {
        await prefs.setInt(_prefSeenVersionCode, currentVersionCode);
      }
      await _checkRosemaryUpdateOnStartup();
      return;
    }

    if (!legalAccepted) {
      await _showAgreementOnlyDialog();
      await prefs.setBool(_prefLegalAccepted, true);
    }

    if (currentVersionCode > 0 && seenVersionCode < currentVersionCode) {
      await _showReleaseNotesDialog(
        fromVersionExclusive: seenVersionCode,
        toVersionInclusive: currentVersionCode,
      );
      await prefs.setInt(_prefSeenVersionCode, currentVersionCode);
    }

    await _checkRosemaryUpdateOnStartup();
  }

  Future<void> _checkRosemaryUpdateOnStartup() async {
    if (_startupRosemaryChecked || !mounted) return;
    _startupRosemaryChecked = true;

    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await ref
          .read(rosemaryUpdateServiceProvider)
          .checkUpdate();
      if (!mounted) return;
      if (result.state != RosemaryCheckState.hasUpdate ||
          result.updateInfo == null) {
        return;
      }
      await _showRosemaryUpdateInfo(result.updateInfo!, l10n: l10n);
    } catch (error, stackTrace) {
      await DebugLogService.error(
        source: 'ROSEMARY',
        message: 'Startup update check failed.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _showRosemaryUpdateInfo(
    UpdateReceive info, {
    required AppLocalizations l10n,
  }) async {
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
                await _runRosemaryUpdate(info, l10n: l10n);
              },
              icon: const Icon(Icons.download_for_offline_outlined),
              label: Text(l10n.rosemaryStartUpdate),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runRosemaryUpdate(
    UpdateReceive info, {
    required AppLocalizations l10n,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
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
              message: 'Startup update task failed.',
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
    } catch (error, stackTrace) {
      await DebugLogService.error(
        source: 'ROSEMARY',
        message: 'Startup update flow threw exception.',
        error: error,
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

  Future<void> _showWelcomeAgreementDialog(PackageInfo packageInfo) async {
    final l10n = AppLocalizations.of(context)!;
    final fullVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool agreed = false;
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(l10n.welcomeTitle),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.welcomeMessageLine1),
                        const SizedBox(height: 6),
                        Text(l10n.welcomeMessageLine2),
                        const SizedBox(height: 6),
                        Text(l10n.welcomeMessageLine3),
                        const SizedBox(height: 12),
                        Text(l10n.currentVersionBeta(fullVersion)),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: agreed,
                          onChanged: (value) {
                            setState(() {
                              agreed = value ?? false;
                            });
                          },
                          title: Text(l10n.agreementCheckboxLabel),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => _showLegalDocument(
                                title: l10n.termsOfService,
                                content: termsOfServiceText(
                                  Localizations.localeOf(context),
                                ),
                              ),
                              child: Text(l10n.viewTermsOfService),
                            ),
                            TextButton(
                              onPressed: () => _showLegalDocument(
                                title: l10n.privacyPolicy,
                                content: privacyPolicyText(
                                  Localizations.localeOf(context),
                                ),
                              ),
                              child: Text(l10n.viewPrivacyPolicy),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  FilledButton(
                    onPressed: agreed
                        ? () => Navigator.of(dialogContext).pop()
                        : null,
                    child: Text(l10n.confirm),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showAgreementOnlyDialog() async {
    final l10n = AppLocalizations.of(context)!;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool agreed = false;
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(l10n.agreementRequiredTitle),
                content: SizedBox(
                  width: 560,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.agreementRequiredBody),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: agreed,
                        onChanged: (value) {
                          setState(() {
                            agreed = value ?? false;
                          });
                        },
                        title: Text(l10n.agreementCheckboxLabel),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => _showLegalDocument(
                              title: l10n.termsOfService,
                              content: termsOfServiceText(
                                Localizations.localeOf(context),
                              ),
                            ),
                            child: Text(l10n.viewTermsOfService),
                          ),
                          TextButton(
                            onPressed: () => _showLegalDocument(
                              title: l10n.privacyPolicy,
                              content: privacyPolicyText(
                                Localizations.localeOf(context),
                              ),
                            ),
                            child: Text(l10n.viewPrivacyPolicy),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  FilledButton(
                    onPressed: agreed
                        ? () => Navigator.of(dialogContext).pop()
                        : null,
                    child: Text(l10n.confirm),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showReleaseNotesDialog({
    required int fromVersionExclusive,
    required int toVersionInclusive,
  }) async {
    final notes = await notesBetweenVersions(
      fromVersionExclusive,
      toVersionInclusive,
    );
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final isZh = locale.languageCode == 'zh';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.releaseNotesTitle),
          content: SizedBox(
            width: 620,
            child: notes.isEmpty
                ? Text(l10n.noReleaseNotes)
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final note in notes) ...[
                          Text(
                            note.versionName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          MarkdownBody(
                            data: isZh ? note.zhMarkdown : note.enMarkdown,
                            selectable: true,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLegalDocument({
    required String title,
    required String content,
  }) async {
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
              child: Text(AppLocalizations.of(context)!.closePanel),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmImportDuplicate({required String duplicateTitle}) async {
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(l10n.duplicateBookTitle),
              content: Text(l10n.duplicateBookMessage(duplicateTitle)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.confirm),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _pickAndImportBook() async {
    if (!kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'PDF or DPDF', extensions: ['pdf', 'dpdf']),
        ],
      );
      if (file == null) return;
      await _importBookFromPath(file.path);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'dpdf'],
    );
    if (result == null || result.files.single.path == null) return;
    await _importBookFromPath(result.files.single.path!);
  }

  Future<void> _importBookFromPath(
    String path, {
    bool openAfterImport = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final repository = ref.read(bookRepositoryProvider);
    await DebugLogService.log(
      'Begin import path=$path openAfterImport=$openAfterImport',
      tag: 'IMPORT',
    );
    try {
      final importedBook = await _runImportWithLoading(
        () => repository.addBookWithDuplicateOption(path),
      );
      ref.invalidate(booksProvider);
      await DebugLogService.log(
        'Import success bookId=${importedBook.id} title=${importedBook.title}',
        tag: 'IMPORT',
      );
      if (openAfterImport && mounted) {
        await DebugLogService.log(
          'Navigate reader bookId=${importedBook.id}',
          tag: 'IMPORT',
        );
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReaderScreen(bookId: importedBook.id),
          ),
        );
      }
    } on DuplicateBookException catch (e) {
      await DebugLogService.log(
        'Duplicate detected existingBookId=${e.existingBook.id} title=${e.existingBook.title}',
        tag: 'IMPORT',
      );
      if (!mounted) return;
      final shouldImport = await _confirmImportDuplicate(
        duplicateTitle: e.existingBook.title,
      );
      await DebugLogService.log(
        'Duplicate confirm result=$shouldImport for path=$path',
        tag: 'IMPORT',
      );
      if (!shouldImport) return;
      try {
        final importedBook = await _runImportWithLoading(
          () =>
              repository.addBookWithDuplicateOption(path, allowDuplicate: true),
        );
        ref.invalidate(booksProvider);
        await DebugLogService.log(
          'Duplicate import success bookId=${importedBook.id}',
          tag: 'IMPORT',
        );
        if (!mounted) return;
        if (openAfterImport) {
          await DebugLogService.log(
            'Navigate reader after duplicate import bookId=${importedBook.id}',
            tag: 'IMPORT',
          );
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReaderScreen(bookId: importedBook.id),
            ),
          );
        }
      } catch (err) {
        await DebugLogService.log(
          'Duplicate import failed err=$err',
          tag: 'IMPORT',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.errorAddingBook}$err')));
      }
    } catch (e) {
      await DebugLogService.log('Import failed err=$e', tag: 'IMPORT');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.errorAddingBook}$e')));
    }
  }

  Future<Book> _runImportWithLoading(Future<Book> Function() task) async {
    _showImportLoadingDialog();
    try {
      return await task();
    } finally {
      _hideImportLoadingDialog();
    }
  }

  void _showImportLoadingDialog() {
    if (_isImportDialogVisible || !mounted) {
      return;
    }
    _isImportDialogVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 16),
                Flexible(child: Text(l10n.addPdf)),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _isImportDialogVisible = false;
    });
  }

  void _hideImportLoadingDialog() {
    if (!_isImportDialogVisible || !mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 92,
            child: Column(
              children: [
                Expanded(
                  child: NavigationRail(
                    selectedIndex: _selectedIndex > _settingsIndex
                        ? _settingsIndex
                        : _selectedIndex,
                    onDestinationSelected: (int index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    labelType: NavigationRailLabelType.all,
                    destinations: <NavigationRailDestination>[
                      NavigationRailDestination(
                        icon: const Icon(Icons.book_outlined),
                        selectedIcon: const Icon(Icons.book),
                        label: Text(l10n.bookshelf),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.bar_chart_outlined),
                        selectedIcon: const Icon(Icons.bar_chart),
                        label: Text(l10n.nav_statistics),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.settings_outlined),
                        selectedIcon: const Icon(Icons.settings),
                        label: Text(l10n.settings),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: _sidebarActionSize,
                    height: _sidebarActionSize,
                    child: FloatingActionButton(
                      onPressed: _pickAndImportBook,
                      child: const Icon(Icons.add),
                    ),
                  ),
                ),
                _AccountNavButton(
                  selected: _selectedIndex == _accountIndex,
                  isAuthenticated: authState.isAuthenticated,
                  label: l10n.account,
                  size: _sidebarActionSize,
                  onTap: () {
                    setState(() {
                      _selectedIndex = _accountIndex;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _selectedIndex == _bookshelfIndex
                ? booksAsync.when(
                    data: (books) {
                      if (books.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.library_books,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noBooks,
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _pickAndImportBook,
                                icon: const Icon(Icons.add),
                                label: Text(l10n.addPdf),
                              ),
                            ],
                          ),
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 200,
                              childAspectRatio: 0.7,
                              crossAxisSpacing: 24,
                              mainAxisSpacing: 24,
                            ),
                        itemCount: books.length,
                        itemBuilder: (context, index) {
                          return BookCard(book: books[index]);
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  )
                : (_selectedIndex == _statisticsIndex
                      ? const StatisticsScreen()
                      : (_selectedIndex == _settingsIndex
                            ? const SettingsScreen()
                            : const AccountScreen())),
          ),
        ],
      ),
    );
  }
}

class _AccountNavButton extends StatelessWidget {
  const _AccountNavButton({
    required this.selected,
    required this.isAuthenticated,
    required this.label,
    required this.size,
    required this.onTap,
  });

  final bool selected;
  final bool isAuthenticated;
  final String label;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: SizedBox(
        width: size,
        child: Material(
          color: selected ? colorScheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAuthenticated ? Icons.person : Icons.person_outline,
                    color: selected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
