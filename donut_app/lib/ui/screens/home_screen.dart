import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../data/repositories/book_repository.dart';
import '../../legal/legal_documents.dart';
import '../../services/release_notes.dart';
import '../../services/settings_service.dart';
import '../../services/external_file_open_service.dart';
import '../../services/debug_log_service.dart';
import '../widgets/book_card.dart';
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

  int _selectedIndex = 0;
  bool _startupHandled = false;
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
      final importedBook = await repository.addBookWithDuplicateOption(path);
      await DebugLogService.log(
        'Import success bookId=${importedBook.id} title=${importedBook.title}',
        tag: 'IMPORT',
      );
      if (openAfterImport && mounted) {
        await DebugLogService.log(
          'Navigate reader bookId=${importedBook.id}',
          tag: 'IMPORT',
        );
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
        final importedBook = await repository.addBookWithDuplicateOption(
          path,
          allowDuplicate: true,
        );
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

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
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
            trailing: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: FloatingActionButton(
                onPressed: _pickAndImportBook,
                child: const Icon(Icons.add),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _selectedIndex == 0
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
                : (_selectedIndex == 1
                      ? const StatisticsScreen()
                      : const SettingsScreen()),
          ),
        ],
      ),
    );
  }
}
