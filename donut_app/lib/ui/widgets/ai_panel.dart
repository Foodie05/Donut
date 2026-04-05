import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../data/repositories/page_repository.dart';
import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../services/client_config_service.dart';
import '../../services/debug_log_service.dart';
import '../../services/settings_service.dart';
import '../../services/summary_service.dart';
import '../../l10n/app_localizations.dart';
import '../screens/settings_screen.dart';
import '../screens/reader/reader_state.dart';
import 'streaming_typewriter_text.dart';

enum _AiPanelMode { assistant, note }

class AiPanel extends ConsumerStatefulWidget {
  final int bookId;
  final GlobalKey pdfKey;
  final bool isVisible;
  final VoidCallback onClose;
  final bool attachToLeft;
  // We need PdfDocument for rendering in background service
  // But AiPanel might not have direct access easily unless passed down
  // or accessed via a provider.
  // Ideally, SummaryGenerationService should get PdfDocument from somewhere.
  // For now, let's assume we pass it or the service can retrieve it if we store it in a provider.
  // Actually, ReaderScreen has _document. We can pass it here.
  final dynamic
  pdfDocument; // PdfDocument type, dynamic to avoid import issues if not exported well or just import pdfrx

  const AiPanel({
    super.key,
    required this.bookId,
    required this.pdfKey,
    required this.isVisible,
    required this.onClose,
    required this.attachToLeft,
    required this.pdfDocument,
  });

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends ConsumerState<AiPanel>
    with TickerProviderStateMixin {
  StreamSubscription? _aiSubscription;
  Timer? _debounce;
  late final PageRepository _pageRepository;
  // Remove local _summary state, rely on DB/Stream
  // But for smooth transition we might want to keep local until stream updates
  // Actually, using StreamBuilder on the specific page data is better.

  bool _isLoading = false;
  _AiPanelErrorState? _runtimeErrorState;
  int? _lastProcessedPage;
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  _AiPanelMode _panelMode = _AiPanelMode.assistant;
  bool _isEditingNote = false;

  // Countdown Animation
  late AnimationController _countdownController;

  // Content Transition Animation
  late AnimationController _contentTransitionController;
  int? _pendingPageIndex; // The next page index we are transitioning TO
  int _displayPageIndex = 0; // The page index currently being displayed

  ProviderSubscription<String>? _summaryProfileSubscription;
  ProviderSubscription<int>? _currentPageSubscription;
  int? _activeStreamingMessageId;
  int? _failedAssistantMessageId;
  String? _failedUserPrompt;
  int? _failedPageIndex;
  String? _failedProfileId;

  @override
  void initState() {
    super.initState();
    _pageRepository = ref.read(pageRepositoryProvider);
    // Initialize display page
    _displayPageIndex = ref.read(currentPageProvider);
    _lastProcessedPage = _displayPageIndex;

    _contentTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 300,
      ), // Total cycle: 150ms out + 150ms in
    );
    // Listen to transition status
    _contentTransitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_pendingPageIndex != null) {
          _updateContentToPage(_pendingPageIndex!);
          _contentTransitionController.reverse(); // Fade back in
        }
      }
    });

    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // 2s per cycle
    );

    _contentTransitionController.value = 0.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateContentToPage(_displayPageIndex);
    });

    _noteFocusNode.addListener(() {
      if (_noteFocusNode.hasFocus) {
        if (mounted) {
          setState(() {
            _isEditingNote = true;
          });
        }
        return;
      }
      _persistCurrentNote();
      if (mounted) {
        setState(() {
          _isEditingNote = false;
        });
      }
    });

    _summaryProfileSubscription = ref.listenManual<String>(
      settingsProvider.select((value) => value.selectedSummaryProfileId),
      (previous, next) {
        if (previous == next) {
          return;
        }
        _handlePageChange(_displayPageIndex, ref.read(settingsProvider));
      },
    );

    _currentPageSubscription = ref.listenManual<int>(currentPageProvider, (
      previous,
      next,
    ) {
      if (next == _displayPageIndex) {
        return;
      }
      _handlePageChange(next, ref.read(settingsProvider));
    });

    if (_lastProcessedPage == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final currentPage = ref.read(currentPageProvider);
        if (currentPage > 0) {
          _handlePageChange(currentPage, ref.read(settingsProvider));
        }
      });
    }
  }

  @override
  void didUpdateWidget(AiPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attachToLeft != oldWidget.attachToLeft && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _summaryProfileSubscription?.close();
    _currentPageSubscription?.close();
    _aiSubscription?.cancel();
    _debounce?.cancel();
    _countdownController.dispose();
    _contentTransitionController.dispose();
    _chatController.dispose();
    _persistCurrentNote();
    _noteController.dispose();
    _noteFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Actual content update logic
  void _updateContentToPage(int pageIndex, {bool animateReset = false}) {
    if (_displayPageIndex != pageIndex) {
      _persistCurrentNote();
    }
    _lastProcessedPage = pageIndex;
    final profileId = ref.read(settingsProvider).selectedSummaryProfileId;

    // Animation handling for countdown reset
    Future<void> resetFuture = Future.value();
    if (animateReset &&
        (_countdownController.value > 0 || _countdownController.isAnimating)) {
      _countdownController.stop(); // Stop current forward
      resetFuture = _countdownController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _countdownController.stop();
      _countdownController.reset();
    }

    final repo = ref.read(pageRepositoryProvider);
    final pageData = repo.getPageData(widget.bookId, pageIndex, profileId);
    final settings = ref.read(settingsProvider);

    setState(() {
      _runtimeErrorState = null;
      _displayPageIndex = pageIndex; // Important: update display index
    });
    _loadNoteForPage(pageIndex);

    // Pre-check if we need to load or countdown
    if (pageData != null &&
        pageData.summary != null &&
        pageData.summary!.isNotEmpty) {
      setState(() => _isLoading = false);
    } else {
      setState(() => _isLoading = false);
      if (_canAutoStartSummary(settings)) {
        resetFuture.then((_) {
          if (mounted && _lastProcessedPage == pageIndex) {
            _startCountdownForPage(pageIndex, settings);
          }
        });
      } else {
        _countdownController.reset();
      }
    }

    _scheduleSmoothSummaryPrefetch(pageIndex, settings);
  }

  void _loadNoteForPage(int pageIndex) {
    final note = _pageRepository.getPageNote(widget.bookId, pageIndex);
    if (_noteController.text != note) {
      _noteController.text = note;
    }
    if (!_noteFocusNode.hasFocus && mounted) {
      setState(() {
        _isEditingNote = false;
      });
    }
  }

  void _persistCurrentNote() {
    final pageIndex = _displayPageIndex;
    _pageRepository.savePageNote(
      widget.bookId,
      pageIndex,
      _noteController.text,
    );
  }

  void _togglePanelMode() {
    if (_panelMode == _AiPanelMode.note && _noteFocusNode.hasFocus) {
      _noteFocusNode.unfocus();
    }
    setState(() {
      _panelMode = _panelMode == _AiPanelMode.assistant
          ? _AiPanelMode.note
          : _AiPanelMode.assistant;
      if (_panelMode == _AiPanelMode.note) {
        _loadNoteForPage(_displayPageIndex);
      }
    });
  }

  void _startEditingNote() {
    if (_panelMode != _AiPanelMode.note) return;
    setState(() {
      _isEditingNote = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _noteFocusNode.requestFocus();
      }
    });
  }

  void _startCountdownForPage(int pageIndex, SettingsModel settings) {
    if (!_canAutoStartSummary(settings)) {
      _countdownController.stop();
      _countdownController.reset();
      return;
    }

    final repo = ref.read(pageRepositoryProvider);
    final currentTrackedIndex = pageIndex;
    final profileId = settings.selectedSummaryProfileId;

    _countdownController.duration = Duration(seconds: settings.debounceSeconds);
    _countdownController.forward(from: 0).then((_) {
      if (!mounted ||
          _lastProcessedPage != currentTrackedIndex ||
          !_canAutoStartSummary(settings)) {
        return;
      }

      final freshPageData = repo.getPageData(
        widget.bookId,
        currentTrackedIndex,
        profileId,
      );
      if (freshPageData?.summary != null && freshPageData!.summary!.isNotEmpty)
        return;

      if (widget.pdfDocument != null) {
        setState(() => _isLoading = true);
        ref
            .read(summaryGenerationServiceProvider)
            .ensureSummary(
              widget.bookId,
              currentTrackedIndex,
              profileId,
              widget.pdfDocument,
              locale: Localizations.localeOf(context).languageCode,
            )
            .then((_) {
              if (mounted && _lastProcessedPage == currentTrackedIndex) {
                setState(() {
                  _isLoading = false;
                  _runtimeErrorState = null;
                });
              }
            })
            .catchError((error, stackTrace) {
              unawaited(
                DebugLogService.error(
                  source: 'AI_PANEL',
                  message:
                      'Auto summary generation failed from countdown trigger.',
                  error: error,
                  stackTrace: stackTrace is StackTrace ? stackTrace : null,
                  context: {
                    'bookId': widget.bookId,
                    'pageIndex': currentTrackedIndex,
                    'profileId': profileId,
                  },
                ),
              );
              if (mounted && _lastProcessedPage == currentTrackedIndex) {
                final runtimeError = _classifyAiPanelError(
                  l10n: AppLocalizations.of(context)!,
                  error: error,
                  settings: ref.read(settingsProvider),
                );
                setState(() {
                  _isLoading = false;
                  _runtimeErrorState = runtimeError;
                });
              }
            });
      }
    });
  }

  bool _canAutoStartSummary(SettingsModel settings) {
    if (!settings.autoGenerate) return false;
    if (settings.powerSavingMode && !mounted) return false;
    return true;
  }

  void _scheduleSmoothSummaryPrefetch(
    int currentPageIndex,
    SettingsModel settings,
  ) {
    if (!settings.autoGenerate ||
        !settings.smoothSummary ||
        widget.pdfDocument == null) {
      return;
    }

    final doc = widget.pdfDocument as PdfDocument;
    final nextPageIndex = currentPageIndex + 1;
    if (nextPageIndex < 1 || nextPageIndex > doc.pages.length) return;
    final profileId = settings.selectedSummaryProfileId;

    final repo = ref.read(pageRepositoryProvider);
    final nextPageData = repo.getPageData(
      widget.bookId,
      nextPageIndex,
      profileId,
    );
    if (nextPageData?.summary != null && nextPageData!.summary!.isNotEmpty)
      return;

    final summaryService = ref.read(summaryGenerationServiceProvider);
    if (summaryService.isSummaryPending(
      widget.bookId,
      nextPageIndex,
      profileId,
    ))
      return;

    unawaited(
      summaryService
          .ensureSummary(
            widget.bookId,
            nextPageIndex,
            profileId,
            doc,
            locale: Localizations.localeOf(context).languageCode,
          )
          .catchError((error, stackTrace) {
            return DebugLogService.warn(
              source: 'AI_PANEL',
              message: 'Smooth summary prefetch failed.',
              error: error,
              stackTrace: stackTrace is StackTrace ? stackTrace : null,
              context: {
                'bookId': widget.bookId,
                'pageIndex': nextPageIndex,
                'profileId': profileId,
              },
            );
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authControllerProvider);
    final clientConfigAsync = ref.watch(clientConfigProvider);
    final clientConfig = clientConfigAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final clientConfigError = clientConfigAsync.hasError
        ? clientConfigAsync.error
        : null;
    final panelWidth = ref.watch(aiPanelWidthProvider);
    final l10n = AppLocalizations.of(context)!;
    final aiAvailability = _resolveAiAvailability(
      settings: settings,
      authState: authState,
      clientConfig: clientConfig,
      clientConfigError: clientConfigError,
      l10n: l10n,
    );
    final runtimeError = _runtimeErrorState;

    // Constraints for resizing
    final screenWidth = MediaQuery.of(context).size.width;
    final minWidth = screenWidth * 0.2;
    final maxWidth = screenWidth * 0.5;

    return SizedBox.expand(
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.attachToLeft)
            MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  final newWidth = panelWidth - details.delta.dx;
                  if (newWidth >= minWidth && newWidth <= maxWidth) {
                    ref.read(aiPanelWidthProvider.notifier).setWidth(newWidth);
                  }
                },
                child: Container(
                  width: 8,
                  color: Colors.transparent,
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
              ),
              child: Column(
                children: [
                  // 1. Header (Static - No Blur/Fade)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Consumer(
                      builder: (context, ref, _) {
                        final settings = ref.watch(settingsProvider);
                        final pageDataAsync = ref.watch(
                          watchPageDataProvider((
                            bookId: widget.bookId,
                            pageIndex: _displayPageIndex,
                            profileId: settings.selectedSummaryProfileId,
                          )),
                        );
                        final pageData = pageDataAsync.value;
                        final displaySummary = pageData?.summary;

                        if (_panelMode == _AiPanelMode.note) {
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.pageNote,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _isEditingNote
                                      ? Icons.visibility
                                      : Icons.edit_note,
                                  size: 20,
                                ),
                                onPressed: () {
                                  if (_isEditingNote) {
                                    _noteFocusNode.unfocus();
                                  } else {
                                    _startEditingNote();
                                  }
                                },
                                tooltip: _isEditingNote
                                    ? l10n.previewNote
                                    : l10n.editNote,
                              ),
                              const Gap(4),
                              IconButton(
                                icon: const Icon(Icons.auto_awesome, size: 20),
                                onPressed: _togglePanelMode,
                                tooltip: l10n.aiSummary,
                              ),
                              const Gap(4),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: widget.onClose,
                                tooltip: l10n.closePanel,
                              ),
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: settings.selectedSummaryProfileId,
                                  items: settings.summaryProfiles
                                      .map(
                                        (profile) => DropdownMenuItem<String>(
                                          value: profile.id,
                                          child: Text(profile.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    ref
                                        .read(settingsProvider.notifier)
                                        .setSelectedSummaryProfile(value);
                                  },
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  onPressed: () {
                                    if (displaySummary != null &&
                                        displaySummary.isNotEmpty) {
                                      _copyToClipboard(displaySummary);
                                    }
                                  },
                                  tooltip: 'Copy Summary',
                                ),
                                const Gap(4),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 20),
                                  onPressed:
                                      _isLoading || !aiAvailability.isAvailable
                                      ? null
                                      : () =>
                                            _refreshSummary(_displayPageIndex),
                                  tooltip: l10n.regenerateSummary,
                                ),
                                const Gap(4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.note_alt_outlined,
                                    size: 20,
                                  ),
                                  onPressed: _togglePanelMode,
                                  tooltip: l10n.pageNote,
                                ),
                                const Gap(4),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: widget.onClose,
                                  tooltip: l10n.closePanel,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // 2. Content (Animated - Blur/Fade)
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _contentTransitionController,
                      builder: (context, child) {
                        final transitionProgress = _contentTransitionController
                            .value
                            .clamp(0.0, 1.0);
                        final transitionBlurSigma = transitionProgress * 8.0;
                        final totalBlurSigma = transitionBlurSigma;
                        final contentOpacity = (1 - transitionProgress).clamp(
                          0.0,
                          1.0,
                        );
                        final overlayOpacity = (transitionProgress * 0.24)
                            .clamp(0.0, 1.0);

                        return Stack(
                          children: [
                            Positioned.fill(
                              child: Opacity(
                                opacity: contentOpacity,
                                child: ImageFiltered(
                                  imageFilter: ui.ImageFilter.blur(
                                    sigmaX: totalBlurSigma,
                                    sigmaY: totalBlurSigma,
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  opacity: overlayOpacity.clamp(0.0, 1.0),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          theme.colorScheme.surface.withValues(
                                            alpha: 0.14,
                                          ),
                                          theme.colorScheme.surface.withValues(
                                            alpha: 0.04,
                                          ),
                                          theme.colorScheme.surface.withValues(
                                            alpha: 0.18,
                                          ),
                                        ],
                                        stops: const [0.0, 0.48, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      child: RepaintBoundary(
                        child: _panelMode == _AiPanelMode.note
                            ? _buildNoteView(theme, l10n)
                            : CustomScrollView(
                                controller: _scrollController,
                                slivers: [
                                  // 2.1 Summary Section (Always at top)
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Consumer(
                                        builder: (context, ref, _) {
                                          final settings = ref.watch(
                                            settingsProvider,
                                          );
                                          final pageDataAsync = ref.watch(
                                            watchPageDataProvider((
                                              bookId: widget.bookId,
                                              pageIndex: _displayPageIndex,
                                              profileId: settings
                                                  .selectedSummaryProfileId,
                                            )),
                                          );
                                          final pageData = pageDataAsync.value;
                                          final displaySummary =
                                              pageData?.summary;

                                          return Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surface,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: theme
                                                    .colorScheme
                                                    .outlineVariant
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.auto_awesome,
                                                      size: 16,
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                                    const Gap(8),
                                                    Text(
                                                      l10n.aiSummary,
                                                      style: theme
                                                          .textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            color: theme
                                                                .colorScheme
                                                                .primary,
                                                          ),
                                                    ),
                                                    const Spacer(),
                                                    if (settings
                                                        .enablePseudoKBMode)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: theme
                                                              .colorScheme
                                                              .secondaryContainer,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          l10n.multiPageContext,
                                                          style: theme
                                                              .textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                                fontSize: 10,
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSecondaryContainer,
                                                              ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const Gap(8),
                                                ClipRect(
                                                  child: AnimatedSize(
                                                    duration: const Duration(
                                                      milliseconds: 240,
                                                    ),
                                                    curve: Curves.easeOutCubic,
                                                    alignment:
                                                        Alignment.topCenter,
                                                    child:
                                                        !aiAvailability
                                                            .isAvailable
                                                        ? _AiUnavailableCard(
                                                            title: l10n
                                                                .aiServiceUnavailable,
                                                            subtitle:
                                                                aiAvailability
                                                                    .subtitle,
                                                          )
                                                        : runtimeError != null
                                                        ? _AiUnavailableCard(
                                                            title: runtimeError
                                                                .title,
                                                            subtitle:
                                                                runtimeError
                                                                    .subtitle,
                                                            icon: runtimeError
                                                                .icon,
                                                            extraMessage:
                                                                runtimeError
                                                                    .extraMessage,
                                                            actionLabel:
                                                                runtimeError
                                                                    .showModelSettingsAction
                                                                ? l10n.openModelSettings
                                                                : null,
                                                            onActionTap:
                                                                runtimeError
                                                                    .showModelSettingsAction
                                                                ? _openModelSettings
                                                                : null,
                                                          )
                                                        : (_isLoading &&
                                                              (displaySummary ==
                                                                      null ||
                                                                  displaySummary
                                                                      .isEmpty))
                                                        ? const Center(
                                                            child: Padding(
                                                              padding:
                                                                  EdgeInsets.all(
                                                                    8.0,
                                                                  ),
                                                              child:
                                                                  CircularProgressIndicator(),
                                                            ),
                                                          )
                                                        : (displaySummary ==
                                                                  null ||
                                                              displaySummary
                                                                  .isEmpty)
                                                        ? Center(
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    8.0,
                                                                  ),
                                                              child: AnimatedBuilder(
                                                                animation:
                                                                    _countdownController,
                                                                builder: (context, child) {
                                                                  if (_countdownController
                                                                              .value >
                                                                          0 ||
                                                                      _countdownController
                                                                          .isAnimating) {
                                                                    return CircularProgressIndicator(
                                                                      value: _countdownController
                                                                          .value,
                                                                      backgroundColor: theme
                                                                          .colorScheme
                                                                          .surfaceContainerHighest,
                                                                    );
                                                                  } else {
                                                                    return CircularProgressIndicator(
                                                                      value: 0,
                                                                      backgroundColor: theme
                                                                          .colorScheme
                                                                          .surfaceContainerHighest,
                                                                    );
                                                                  }
                                                                },
                                                              ),
                                                            ),
                                                          )
                                                        : StreamingTypewriterText(
                                                            key: ValueKey(
                                                              '${settings.selectedSummaryProfileId}_$_displayPageIndex',
                                                            ),
                                                            text:
                                                                displaySummary,
                                                            isStreaming: false,
                                                            styleSheet:
                                                                MarkdownStyleSheet.fromTheme(
                                                                  theme,
                                                                ),
                                                          ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final settings = ref.watch(
                                        settingsProvider,
                                      );
                                      final pageDataAsync = ref.watch(
                                        watchPageDataProvider((
                                          bookId: widget.bookId,
                                          pageIndex: _displayPageIndex,
                                          profileId:
                                              settings.selectedSummaryProfileId,
                                        )),
                                      );
                                      final pageData = pageDataAsync.value;
                                      if (pageData == null) {
                                        return const SliverToBoxAdapter(
                                          child: SizedBox.shrink(),
                                        );
                                      }

                                      return Consumer(
                                        builder: (context, ref, _) {
                                          final messagesAsync = ref.watch(
                                            watchMessagesProvider(pageData.id),
                                          );
                                          final messages =
                                              messagesAsync.value ?? [];

                                          return SliverList(
                                            delegate: SliverChildBuilderDelegate((
                                              context,
                                              index,
                                            ) {
                                              final msg = messages[index];
                                              final isUser = msg.isUser;
                                              final isStreamingAssistantMessage =
                                                  !isUser &&
                                                  _isLoading &&
                                                  _activeStreamingMessageId ==
                                                      msg.id;
                                              final isFailedAssistantMessage =
                                                  !isUser &&
                                                  !_isLoading &&
                                                  _failedAssistantMessageId ==
                                                      msg.id;
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 4,
                                                    ),
                                                child: Align(
                                                  alignment: isUser
                                                      ? Alignment.centerRight
                                                      : Alignment.centerLeft,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isUser
                                                          ? theme
                                                                .colorScheme
                                                                .primaryContainer
                                                          : theme
                                                                .colorScheme
                                                                .surfaceContainerHighest,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    constraints: BoxConstraints(
                                                      maxWidth:
                                                          panelWidth * 0.85,
                                                    ),
                                                    child:
                                                        (msg.text.isEmpty &&
                                                            !isUser)
                                                        ? _LoadingDotsIndicator(
                                                            theme: theme,
                                                          )
                                                        : isStreamingAssistantMessage
                                                        ? StreamingTypewriterText(
                                                            text: msg.text,
                                                            isStreaming: true,
                                                            speed:
                                                                const Duration(
                                                                  milliseconds:
                                                                      12,
                                                                ),
                                                            styleSheet:
                                                                MarkdownStyleSheet.fromTheme(
                                                                  theme,
                                                                ).copyWith(
                                                                  p: theme
                                                                      .textTheme
                                                                      .bodyMedium
                                                                      ?.copyWith(
                                                                        color: theme
                                                                            .colorScheme
                                                                            .onSurfaceVariant,
                                                                        fontFamily:
                                                                            'Noto Serif SC',
                                                                      ),
                                                                ),
                                                          )
                                                        : isFailedAssistantMessage
                                                        ? Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              MarkdownBody(
                                                                data: msg.text,
                                                                selectable:
                                                                    true,
                                                                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                                                                  p: theme
                                                                      .textTheme
                                                                      .bodyMedium
                                                                      ?.copyWith(
                                                                        color: theme
                                                                            .colorScheme
                                                                            .onSurfaceVariant,
                                                                        fontFamily:
                                                                            'Noto Serif SC',
                                                                      ),
                                                                ),
                                                              ),
                                                              const Gap(8),
                                                              Align(
                                                                alignment: Alignment
                                                                    .centerLeft,
                                                                child: OutlinedButton.icon(
                                                                  onPressed:
                                                                      _isLoading
                                                                      ? null
                                                                      : () => _retryFailedChat(
                                                                          msg.id,
                                                                        ),
                                                                  icon: const Icon(
                                                                    Icons
                                                                        .refresh_rounded,
                                                                    size: 16,
                                                                  ),
                                                                  label:
                                                                      const Text(
                                                                        'Retry',
                                                                      ),
                                                                ),
                                                              ),
                                                            ],
                                                          )
                                                        : MarkdownBody(
                                                            data: msg.text,
                                                            selectable: true,
                                                            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                                                              p: theme
                                                                  .textTheme
                                                                  .bodyMedium
                                                                  ?.copyWith(
                                                                    color:
                                                                        isUser
                                                                        ? theme
                                                                              .colorScheme
                                                                              .onPrimaryContainer
                                                                        : theme
                                                                              .colorScheme
                                                                              .onSurfaceVariant,
                                                                    fontFamily:
                                                                        'Noto Serif SC',
                                                                  ),
                                                            ),
                                                          ),
                                                  ),
                                                ),
                                              );
                                            }, childCount: messages.length),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  const SliverToBoxAdapter(child: Gap(16)),
                                ],
                              ),
                      ),
                    ),
                  ),

                  if (_panelMode == _AiPanelMode.assistant) ...[
                    Divider(height: 1, color: theme.colorScheme.outlineVariant),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: TextField(
                                controller: _chatController,
                                enabled: aiAvailability.isAvailable,
                                decoration: InputDecoration(
                                  hintText: aiAvailability.isAvailable
                                      ? l10n.enterMessage
                                      : aiAvailability.subtitle,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: theme
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.46),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  isDense: true,
                                ),
                                onSubmitted: (value) => _sendMessage(value),
                              ),
                            ),
                          ),
                          const Gap(8),
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: IconButton.filled(
                              icon: const Icon(Icons.send),
                              onPressed:
                                  _isLoading || !aiAvailability.isAvailable
                                  ? null
                                  : () => _sendMessage(_chatController.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (widget.attachToLeft)
            MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  final newWidth = panelWidth + details.delta.dx;
                  if (newWidth >= minWidth && newWidth <= maxWidth) {
                    ref.read(aiPanelWidthProvider.notifier).setWidth(newWidth);
                  }
                },
                child: Container(
                  width: 8,
                  color: Colors.transparent,
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoteView(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Consumer(
            builder: (context, ref, _) {
              final noteAsync = ref.watch(
                watchPageNoteProvider((
                  bookId: widget.bookId,
                  pageIndex: _displayPageIndex,
                )),
              );
              final note = noteAsync.value ?? _noteController.text;
              if (!_noteFocusNode.hasFocus && _noteController.text != note) {
                _noteController.text = note;
              }

              return ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                  maxWidth: constraints.maxWidth,
                  minHeight: constraints.maxHeight,
                  maxHeight: constraints.maxHeight,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: _isEditingNote
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Scrollbar(
                            child: SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight - 32,
                                ),
                                child: TextField(
                                  controller: _noteController,
                                  focusNode: _noteFocusNode,
                                  maxLines: null,
                                  minLines: 12,
                                  maxLength: 20000,
                                  decoration: InputDecoration(
                                    hintText: l10n.pageNoteHint,
                                    border: InputBorder.none,
                                    counterText: '',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _startEditingNote,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: note.trim().isEmpty
                                ? Text(
                                    l10n.pageNoteEmpty,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                : MarkdownBody(
                                    data: note,
                                    selectable: true,
                                    styleSheet: MarkdownStyleSheet.fromTheme(
                                      theme,
                                    ),
                                  ),
                          ),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _handlePageChange(int pageIndex, SettingsModel settings) {
    unawaited(
      DebugLogService.debug(
        source: 'AI_PANEL',
        message: 'Handling AI panel page change.',
        context: {
          'bookId': widget.bookId,
          'fromPageIndex': _displayPageIndex,
          'toPageIndex': pageIndex,
          'profileId': settings.selectedSummaryProfileId,
        },
      ),
    );
    // 1. Immediate Cleanup
    _aiSubscription?.cancel();
    _activeStreamingMessageId = null;
    _failedAssistantMessageId = null;
    _failedUserPrompt = null;
    _failedPageIndex = null;
    _failedProfileId = null;
    _countdownController.stop();

    // Check if the current page OR the next page has data
    // If both have NO data, we skip the fade animation and just reset/restart countdown
    // This makes scrolling through empty pages feel faster/more responsive

    final repo = ref.read(pageRepositoryProvider);
    final profileId = settings.selectedSummaryProfileId;
    final currentPageData = repo.getPageData(
      widget.bookId,
      _displayPageIndex,
      profileId,
    );
    final nextPageData = repo.getPageData(widget.bookId, pageIndex, profileId);

    final currentHasData =
        currentPageData?.summary != null &&
        currentPageData!.summary!.isNotEmpty;
    final nextHasData =
        nextPageData?.summary != null && nextPageData!.summary!.isNotEmpty;

    if (!currentHasData && !nextHasData) {
      // Both empty: Skip fade animation, just update immediately
      // This feels like "resetting" the countdown rather than fading content
      // We pass true to animateReset to show the countdown circle rewinding
      _updateContentToPage(pageIndex, animateReset: true);
      return;
    }

    // 2. Trigger Fade Out (Breathing Effect)
    // If content is already fading, just update the target
    _pendingPageIndex = pageIndex;

    // Start fade out sequence
    // If controller is at 0 (visible), forward to 1 (hidden)
    if (!_contentTransitionController.isAnimating) {
      _contentTransitionController.forward(from: 0.0);
    } else {
      // Already animating? If fading IN (reverse), stop and fade OUT again?
      // Or if fading OUT (forward), let it finish.
      if (_contentTransitionController.status == AnimationStatus.reverse) {
        _contentTransitionController.forward();
      }
    }
  }

  Future<Uint8List?> _captureScreenshotBytes() async {
    if (widget.pdfKey.currentContext == null) return null;

    try {
      // Small delay to ensure rendering is complete
      await Future.delayed(const Duration(milliseconds: 100));

      RenderRepaintBoundary boundary =
          widget.pdfKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e, stackTrace) {
      unawaited(
        DebugLogService.warn(
          source: 'AI_PANEL',
          message: 'Failed to capture current PDF screenshot for chat.',
          error: e,
          stackTrace: stackTrace,
          context: {
            'bookId': widget.bookId,
            'pageIndex': ref.read(currentPageProvider),
          },
        ),
      );
    }
    return null;
  }

  // Render previous pages for enhanced context (PseudoKB Mode)
  Future<List<Uint8List>> _renderContextPages(int pageIndex) async {
    final settings = ref.read(settingsProvider);
    if (!settings.enablePseudoKBMode || widget.pdfDocument == null) return [];

    final doc = widget.pdfDocument as PdfDocument;
    final contextImages = <Uint8List>[];
    final pagesToRender = <int>[];

    // Add previous 2 pages if available
    if (pageIndex > 2) pagesToRender.add(pageIndex - 2);
    if (pageIndex > 1) pagesToRender.add(pageIndex - 1);

    for (final pNum in pagesToRender) {
      if (pNum > 0 && pNum <= doc.pages.length) {
        try {
          final page = doc.pages[pNum - 1];
          final image = await page.render(
            width: 768,
            height: (768 * page.height / page.width).round(),
            backgroundColor: 0xFFFFFFFF,
          );

          if (image != null) {
            final uiImage = await image.createImage();
            final byteData = await uiImage.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (byteData != null) {
              contextImages.add(byteData.buffer.asUint8List());
            }
          }
        } catch (e, stackTrace) {
          unawaited(
            DebugLogService.warn(
              source: 'AI_PANEL',
              message: 'Failed to render context page for chat.',
              error: e,
              stackTrace: stackTrace,
              context: {
                'bookId': widget.bookId,
                'pageIndex': pageIndex,
                'contextPageIndex': pNum,
              },
            ),
          );
        }
      }
    }
    return contextImages;
  }

  // This local generation is only for manual refresh now, or fallback?
  // Actually, we moved auto-generation to service.
  // Manual refresh should also use the service?
  // If we want to show progress in UI, we can keep using service but we need to know when it finishes.
  // But service is "fire and forget" or "wait".
  // Let's make _refreshSummary use the service too.

  Future<void> _refreshSummary(int pageIndex) async {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    await DebugLogService.info(
      source: 'AI_PANEL',
      message: 'Manual summary refresh requested.',
      context: {
        'bookId': widget.bookId,
        'pageIndex': pageIndex,
        'profileId': ref.read(settingsProvider).selectedSummaryProfileId,
      },
    );
    _countdownController.stop();
    setState(() {
      _isLoading = true;
      _runtimeErrorState = null;
    });
    final settings = ref.read(settingsProvider);
    final profileId = settings.selectedSummaryProfileId;

    try {
      if (widget.pdfDocument != null) {
        ref
            .read(pageRepositoryProvider)
            .savePageSummary(widget.bookId, pageIndex, profileId, "", null);

        await ref
            .read(summaryGenerationServiceProvider)
            .ensureSummary(
              widget.bookId,
              pageIndex,
              profileId,
              widget.pdfDocument,
              locale: locale,
              force: true,
            );
      }
    } catch (error, stackTrace) {
      final uiError = _classifyAiPanelError(
        l10n: l10n,
        error: error,
        settings: settings,
      );
      final shouldRetrySilently =
          uiError.kind == _AiPanelErrorKind.modelUnavailable;
      if (shouldRetrySilently) {
        try {
          await ref
              .read(summaryGenerationServiceProvider)
              .ensureSummary(
                widget.bookId,
                pageIndex,
                profileId,
                widget.pdfDocument,
                locale: locale,
                force: true,
              );
          if (mounted) {
            setState(() {
              _runtimeErrorState = null;
            });
          }
          return;
        } catch (retryError, retryStackTrace) {
          await DebugLogService.error(
            source: 'AI_PANEL',
            message: 'Manual summary refresh failed after retry.',
            error: retryError,
            stackTrace: retryStackTrace,
            context: {
              'bookId': widget.bookId,
              'pageIndex': pageIndex,
              'profileId': profileId,
            },
          );
          if (mounted) {
            final retryUiError = _classifyAiPanelError(
              l10n: l10n,
              error: retryError,
              settings: settings,
            );
            setState(() {
              _runtimeErrorState = retryUiError;
            });
          }
          return;
        }
      }

      await DebugLogService.error(
        source: 'AI_PANEL',
        message: 'Manual summary refresh failed.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'bookId': widget.bookId,
          'pageIndex': pageIndex,
          'profileId': profileId,
        },
      );
      if (mounted) {
        setState(() {
          _runtimeErrorState = uiError;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final pageIndex = ref.read(currentPageProvider);
    final repo = ref.read(pageRepositoryProvider);
    final profileId = ref.read(settingsProvider).selectedSummaryProfileId;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final authState = ref.read(authControllerProvider);
    final clientConfigAsync = ref.read(clientConfigProvider);
    final clientConfig = clientConfigAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final clientConfigError = clientConfigAsync.hasError
        ? clientConfigAsync.error
        : null;
    final availability = _resolveAiAvailability(
      settings: ref.read(settingsProvider),
      authState: authState,
      clientConfig: clientConfig,
      clientConfigError: clientConfigError,
      l10n: l10n,
    );
    if (!availability.isAvailable) {
      await DebugLogService.warn(
        source: 'AI_PANEL',
        message: 'Chat request blocked because AI service is unavailable.',
        context: {
          'bookId': widget.bookId,
          'pageIndex': pageIndex,
          'profileId': profileId,
          'subtitle': availability.subtitle,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(availability.subtitle)));
      return;
    }

    // Ensure PageData exists
    var pageData = repo.getPageData(widget.bookId, pageIndex, profileId);
    if (pageData == null) {
      repo.savePageSummary(widget.bookId, pageIndex, profileId, "", null);
      pageData = repo.getPageData(widget.bookId, pageIndex, profileId);
    }

    if (pageData == null) return;

    final userMessageId = repo.addMessage(pageData.id, text, true);
    _chatController.clear();
    _ensureChatScrollToBottom();

    // Cancel previous AI action
    _aiSubscription?.cancel();
    _activeStreamingMessageId = null;

    setState(() {
      _isLoading = true;
      _runtimeErrorState = null;
      _failedAssistantMessageId = null;
      _failedUserPrompt = null;
      _failedPageIndex = null;
      _failedProfileId = null;
    });

    final history = repo
        .getRecentMessages(pageData.id)
        .where((message) => message.id != userMessageId)
        .toList();
    final aiService = ref.read(aiServiceProvider);
    final settings = ref.read(settingsProvider);
    final StringBuffer responseBuffer = StringBuffer();

    await DebugLogService.info(
      source: 'AI_PANEL',
      message: 'Dispatching chat request from AI panel.',
      context: {
        'bookId': widget.bookId,
        'pageIndex': pageIndex,
        'profileId': profileId,
        'pageDataId': pageData.id,
        'historyCount': history.length,
        'promptLength': text.length,
        'hasSummary': pageData.summary != null && pageData.summary!.isNotEmpty,
        'enablePseudoKbMode': settings.enablePseudoKBMode,
      },
    );

    // Add temporary AI loading message
    final loadingMsgId = repo.addMessage(pageData.id, "", false);
    _activeStreamingMessageId = loadingMsgId;
    _ensureChatScrollToBottom();

    try {
      final screenshotBytes = await _captureScreenshotBytes();
      if (screenshotBytes == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final contextImages = await _renderContextPages(pageIndex);
      final allImages = <AiImageInput>[
        ...contextImages.map(AiImageInput.bytes),
        AiImageInput.bytes(screenshotBytes),
      ];
      final stream = aiService.chatWithPage(
        prompt: text,
        images: allImages,
        summary: pageData.summary,
        history: history,
        locale: locale,
      );

      _aiSubscription = stream.listen(
        (chunk) {
          responseBuffer.write(chunk);
          // Update message content in real-time
          repo.updateMessage(loadingMsgId, responseBuffer.toString());
          _ensureChatScrollToBottom(immediate: true);
        },
        onDone: () {
          unawaited(
            DebugLogService.info(
              source: 'AI_PANEL',
              message: 'Chat request completed.',
              context: {
                'bookId': widget.bookId,
                'pageIndex': pageIndex,
                'profileId': profileId,
                'responseLength': responseBuffer.length,
              },
            ),
          );
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _activeStreamingMessageId = null;
            _failedAssistantMessageId = null;
            _failedUserPrompt = null;
            _failedPageIndex = null;
            _failedProfileId = null;
            _runtimeErrorState = null;
          });
          _ensureChatScrollToBottom();
        },
        onError: (e) {
          unawaited(
            DebugLogService.error(
              source: 'AI_PANEL',
              message: 'Chat stream failed.',
              error: e,
              context: {
                'bookId': widget.bookId,
                'pageIndex': pageIndex,
                'profileId': profileId,
                'responseLength': responseBuffer.length,
              },
            ),
          );
          if (!mounted) return;
          final runtimeError = _classifyAiPanelError(
            l10n: l10n,
            error: e,
            settings: ref.read(settingsProvider),
          );
          repo.updateMessage(loadingMsgId, runtimeError.subtitle);
          setState(() {
            _isLoading = false;
            _activeStreamingMessageId = null;
            _failedAssistantMessageId = loadingMsgId;
            _failedUserPrompt = text;
            _failedPageIndex = pageIndex;
            _failedProfileId = profileId;
            _runtimeErrorState = null;
          });
          _ensureChatScrollToBottom();
        },
        cancelOnError: true,
      );
    } catch (e, stackTrace) {
      await DebugLogService.error(
        source: 'AI_PANEL',
        message: 'Chat request failed before stream subscription.',
        error: e,
        stackTrace: stackTrace,
        context: {
          'bookId': widget.bookId,
          'pageIndex': pageIndex,
          'profileId': profileId,
        },
      );
      if (mounted) {
        final runtimeError = _classifyAiPanelError(
          l10n: l10n,
          error: e,
          settings: ref.read(settingsProvider),
        );
        repo.updateMessage(loadingMsgId, runtimeError.subtitle);
        setState(() {
          _isLoading = false;
          _activeStreamingMessageId = null;
          _failedAssistantMessageId = loadingMsgId;
          _failedUserPrompt = text;
          _failedPageIndex = pageIndex;
          _failedProfileId = profileId;
          _runtimeErrorState = null;
        });
        _ensureChatScrollToBottom();
      }
    }
  }

  Future<void> _retryFailedChat(int failedMessageId) async {
    if (_isLoading) return;
    final retryPrompt = _failedUserPrompt;
    final retryPageIndex = _failedPageIndex;
    final retryProfileId = _failedProfileId;
    if (retryPrompt == null ||
        retryPrompt.trim().isEmpty ||
        retryPageIndex == null ||
        retryProfileId == null) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final pageIndex = ref.read(currentPageProvider);
    if (pageIndex != retryPageIndex) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please return to the original page first.'),
        ),
      );
      return;
    }

    final authState = ref.read(authControllerProvider);
    final clientConfigAsync = ref.read(clientConfigProvider);
    final clientConfig = clientConfigAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final clientConfigError = clientConfigAsync.hasError
        ? clientConfigAsync.error
        : null;
    final availability = _resolveAiAvailability(
      settings: ref.read(settingsProvider),
      authState: authState,
      clientConfig: clientConfig,
      clientConfigError: clientConfigError,
      l10n: l10n,
    );
    if (!availability.isAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(availability.subtitle)));
      return;
    }

    final repo = ref.read(pageRepositoryProvider);
    final pageData = repo.getPageData(
      widget.bookId,
      retryPageIndex,
      retryProfileId,
    );
    if (pageData == null) return;

    _aiSubscription?.cancel();
    _activeStreamingMessageId = null;

    setState(() {
      _isLoading = true;
      _runtimeErrorState = null;
      _activeStreamingMessageId = failedMessageId;
    });
    _ensureChatScrollToBottom();

    final history = repo
        .getRecentMessages(pageData.id)
        .where((message) => message.id != failedMessageId)
        .toList();
    final aiService = ref.read(aiServiceProvider);
    final responseBuffer = StringBuffer();
    repo.updateMessage(failedMessageId, '');
    _ensureChatScrollToBottom();

    try {
      final screenshotBytes = await _captureScreenshotBytes();
      if (screenshotBytes == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _activeStreamingMessageId = null;
          });
        }
        return;
      }
      final contextImages = await _renderContextPages(retryPageIndex);
      final allImages = <AiImageInput>[
        ...contextImages.map(AiImageInput.bytes),
        AiImageInput.bytes(screenshotBytes),
      ];
      final stream = aiService.chatWithPage(
        prompt: retryPrompt,
        images: allImages,
        summary: pageData.summary,
        history: history,
        locale: locale,
      );

      _aiSubscription = stream.listen(
        (chunk) {
          responseBuffer.write(chunk);
          repo.updateMessage(failedMessageId, responseBuffer.toString());
          _ensureChatScrollToBottom(immediate: true);
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _activeStreamingMessageId = null;
            _failedAssistantMessageId = null;
            _failedUserPrompt = null;
            _failedPageIndex = null;
            _failedProfileId = null;
          });
          _ensureChatScrollToBottom();
        },
        onError: (error) {
          if (!mounted) return;
          final runtimeError = _classifyAiPanelError(
            l10n: l10n,
            error: error,
            settings: ref.read(settingsProvider),
          );
          repo.updateMessage(failedMessageId, runtimeError.subtitle);
          setState(() {
            _isLoading = false;
            _activeStreamingMessageId = null;
            _failedAssistantMessageId = failedMessageId;
            _failedUserPrompt = retryPrompt;
            _failedPageIndex = retryPageIndex;
            _failedProfileId = retryProfileId;
          });
          _ensureChatScrollToBottom();
        },
        cancelOnError: true,
      );
    } catch (error) {
      if (!mounted) return;
      final runtimeError = _classifyAiPanelError(
        l10n: l10n,
        error: error,
        settings: ref.read(settingsProvider),
      );
      repo.updateMessage(failedMessageId, runtimeError.subtitle);
      setState(() {
        _isLoading = false;
        _activeStreamingMessageId = null;
        _failedAssistantMessageId = failedMessageId;
        _failedUserPrompt = retryPrompt;
        _failedPageIndex = retryPageIndex;
        _failedProfileId = retryProfileId;
      });
      _ensureChatScrollToBottom();
    }
  }

  void _ensureChatScrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (immediate) {
        _scrollController.jumpTo(target);
        return;
      }
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _openModelSettings() {
    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(l10n.settings)),
          body: const SettingsScreen(openAiConfigurationOnStart: true),
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }
}

class _LoadingDotsIndicator extends StatefulWidget {
  const _LoadingDotsIndicator({required this.theme});

  final ThemeData theme;

  @override
  State<_LoadingDotsIndicator> createState() => _LoadingDotsIndicatorState();
}

class _LoadingDotsIndicatorState extends State<_LoadingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (index) {
                final phase = (_controller.value + index * 0.2) % 1.0;
                final pulse = (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
                final dotColor = Color.lerp(
                  Colors.black.withValues(alpha: 0.45),
                  widget.theme.colorScheme.primary.withValues(alpha: 0.95),
                  pulse,
                )!;
                return Transform.translate(
                  offset: Offset(0, -2.5 * pulse),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          dotColor.withValues(alpha: 0.92),
                          dotColor.withValues(alpha: 0.58),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ).expand((dot) => [dot, const SizedBox(width: 3)]).take(5).toList(),
          );
        },
      ),
    );
  }
}

class _AiUnavailableCard extends StatelessWidget {
  const _AiUnavailableCard({
    required this.title,
    required this.subtitle,
    this.icon = Icons.error_outline,
    this.extraMessage,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? extraMessage;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const Gap(10),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const Gap(6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (extraMessage != null && extraMessage!.isNotEmpty) ...[
            const Gap(8),
            Text(
              extraMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (actionLabel != null && onActionTap != null) ...[
            const Gap(12),
            FilledButton.icon(
              onPressed: onActionTap,
              icon: const Icon(Icons.tune),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

enum _AiPanelErrorKind {
  quotaExceeded,
  networkUnavailable,
  modelUnavailable,
  signInRequired,
}

class _AiPanelErrorState {
  const _AiPanelErrorState({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.showModelSettingsAction,
    this.extraMessage,
  });

  final _AiPanelErrorKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool showModelSettingsAction;
  final String? extraMessage;
}

class _AiAvailabilityState {
  const _AiAvailabilityState({
    required this.isAvailable,
    required this.subtitle,
  });

  final bool isAvailable;
  final String subtitle;
}

_AiAvailabilityState _resolveAiAvailability({
  required SettingsModel settings,
  required AuthState authState,
  required ClientConfigSummary? clientConfig,
  required Object? clientConfigError,
  required AppLocalizations l10n,
}) {
  if (!settings.useCustomModelConfig) {
    if (!authState.isAuthenticated) {
      return _AiAvailabilityState(
        isAvailable: false,
        subtitle: l10n.aiServiceSignInRequiredSubtitle,
      );
    }

    if (clientConfigError != null && _isLikelyNetworkError(clientConfigError)) {
      return _AiAvailabilityState(
        isAvailable: false,
        subtitle: l10n.aiNetworkUnavailableSubtitle,
      );
    }

    final availableModels = clientConfig?.availableModels ?? const <String>[];
    if (availableModels.isEmpty ||
        !availableModels.contains(settings.selectedServerModelName)) {
      return _AiAvailabilityState(
        isAvailable: false,
        subtitle: l10n.aiServiceUnavailableSubtitle,
      );
    }

    return _AiAvailabilityState(isAvailable: true, subtitle: '');
  }

  final isConfigured =
      settings.baseUrl.trim().isNotEmpty &&
      settings.apiKey.trim().isNotEmpty &&
      settings.modelName.trim().isNotEmpty;
  return _AiAvailabilityState(
    isAvailable: isConfigured,
    subtitle: isConfigured ? '' : l10n.aiServiceUnavailableSubtitle,
  );
}

_AiPanelErrorState _classifyAiPanelError({
  required AppLocalizations l10n,
  required Object error,
  required SettingsModel settings,
}) {
  final raw = error.toString().toLowerCase();
  final code = error is AiServiceException ? error.code : raw;

  if (_isLikelyNetworkError(error)) {
    return _AiPanelErrorState(
      kind: _AiPanelErrorKind.networkUnavailable,
      title: l10n.aiNetworkUnavailableTitle,
      subtitle: l10n.aiNetworkUnavailableSubtitle,
      icon: Icons.wifi_off_rounded,
      showModelSettingsAction: false,
    );
  }

  if (code.contains('daily_quota_exceeded')) {
    return _AiPanelErrorState(
      kind: _AiPanelErrorKind.quotaExceeded,
      title: l10n.aiQuotaExceededTitle,
      subtitle: l10n.aiQuotaExceededSubtitle,
      icon: Icons.hourglass_top_rounded,
      showModelSettingsAction: false,
    );
  }

  if (code.contains('sign_in_required') || raw.contains('please sign in')) {
    return _AiPanelErrorState(
      kind: _AiPanelErrorKind.signInRequired,
      title: l10n.aiServiceUnavailable,
      subtitle: l10n.aiServiceSignInRequiredSubtitle,
      icon: Icons.login_rounded,
      showModelSettingsAction: false,
    );
  }

  return _AiPanelErrorState(
    kind: _AiPanelErrorKind.modelUnavailable,
    title: l10n.aiModelUnavailableTitle,
    subtitle: l10n.aiModelUnavailableSubtitle,
    icon: Icons.cloud_off_rounded,
    showModelSettingsAction: true,
    extraMessage: settings.useCustomModelConfig ? l10n.aiCustomModelHint : null,
  );
}

bool _isLikelyNetworkError(Object error) {
  final raw = error.toString().toLowerCase();
  return error is SocketException ||
      error is TimeoutException ||
      (error is DioException &&
          (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout)) ||
      raw.contains('socketexception') ||
      raw.contains('connection refused') ||
      raw.contains('failed host lookup') ||
      raw.contains('network is unreachable') ||
      raw.contains('connection error') ||
      raw.contains('timed out');
}
