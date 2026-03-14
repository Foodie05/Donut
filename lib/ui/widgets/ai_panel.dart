import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/chat_message.dart';
import '../../data/models/page_data.dart';
import '../../data/repositories/page_repository.dart';
import '../../services/ai_service.dart';
import '../../services/settings_service.dart';
import '../../services/summary_service.dart';
import '../../l10n/app_localizations.dart';
import '../screens/reader/reader_state.dart';
import 'streaming_typewriter_text.dart';
import 'typing_indicator.dart';

class AiPanel extends ConsumerStatefulWidget {
  final int bookId;
  final GlobalKey pdfKey;
  final bool isVisible;
  final VoidCallback onClose;
  // We need PdfDocument for rendering in background service
  // But AiPanel might not have direct access easily unless passed down
  // or accessed via a provider. 
  // Ideally, SummaryGenerationService should get PdfDocument from somewhere.
  // For now, let's assume we pass it or the service can retrieve it if we store it in a provider.
  // Actually, ReaderScreen has _document. We can pass it here.
  final dynamic pdfDocument; // PdfDocument type, dynamic to avoid import issues if not exported well or just import pdfrx

  const AiPanel({
    super.key,
    required this.bookId,
    required this.pdfKey,
    required this.isVisible,
    required this.onClose,
    required this.pdfDocument,
  });

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends ConsumerState<AiPanel> with TickerProviderStateMixin {
  StreamSubscription? _aiSubscription;
  Timer? _debounce;
  // Remove local _summary state, rely on DB/Stream
  // But for smooth transition we might want to keep local until stream updates
  // Actually, using StreamBuilder on the specific page data is better.
  
  bool _isLoading = false;
  int? _lastProcessedPage;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Countdown Animation
  late AnimationController _countdownController;
  PageData? _currentPageData;

  // Content Transition Animation
  late AnimationController _contentTransitionController;
  late Animation<double> _contentFadeAnimation;
  int? _pendingPageIndex; // The next page index we are transitioning TO
  int _displayPageIndex = 0; // The page index currently being displayed

  // Slide Animation Controller
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize display page
    _displayPageIndex = ref.read(currentPageProvider);
    _lastProcessedPage = _displayPageIndex;

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _contentTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Total cycle: 150ms out + 150ms in
    );
    _contentFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _contentTransitionController,
      curve: Curves.easeInOutCubic,
    ));

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
    )..repeat();
    
    if (widget.isVisible) {
      _slideController.value = 1.0;
      _contentTransitionController.value = 0.0; // Visible
    } else {
      _contentTransitionController.value = 1.0; // Hidden
    }
  }

  @override
  void didUpdateWidget(AiPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _slideController.forward();
        _contentTransitionController.reverse(); // Ensure visible
      } else {
        _slideController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _aiSubscription?.cancel();
    _debounce?.cancel();
    _countdownController.dispose();
    _contentTransitionController.dispose();
    _slideController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Actual content update logic
  void _updateContentToPage(int pageIndex, {bool animateReset = false}) {
    _lastProcessedPage = pageIndex;
    
    // Animation handling for countdown reset
    Future<void> resetFuture = Future.value();
    if (animateReset && (_countdownController.value > 0 || _countdownController.isAnimating)) {
        _countdownController.stop(); // Stop current forward
        resetFuture = _countdownController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } else {
        _countdownController.stop();
        _countdownController.reset();
    }

    final repo = ref.read(pageRepositoryProvider);
    final pageData = repo.getPageData(widget.bookId, pageIndex);
    final settings = ref.read(settingsProvider);

    setState(() {
      _currentPageData = pageData;
      _displayPageIndex = pageIndex; // Important: update display index
    });
    
    // Pre-check if we need to load or countdown
    if (pageData != null && pageData.summary != null && pageData.summary!.isNotEmpty) {
      setState(() => _isLoading = false);
      // If we have data, we don't need to wait for reset animation to finish to show it?
      // But circle should probably disappear or reset.
      // The original logic just did reset().
    } else {
       setState(() => _isLoading = false);
       if (settings.autoGenerate) {
         // Wait for reset to finish before starting new one
         resetFuture.then((_) {
            if (mounted && _lastProcessedPage == pageIndex) {
                _startCountdownForPage(pageIndex, settings);
            }
         });
       } else {
         _countdownController.reset();
       }
    }
  }

  void _startCountdownForPage(int pageIndex, SettingsModel settings) {
      final repo = ref.read(pageRepositoryProvider);
      final currentTrackedIndex = pageIndex;
      
      _countdownController.duration = Duration(seconds: settings.debounceSeconds);
      _countdownController.forward(from: 0).then((_) {
         if (!mounted || _lastProcessedPage != currentTrackedIndex) return;
         
         final freshPageData = repo.getPageData(widget.bookId, currentTrackedIndex);
         if (freshPageData?.summary != null && freshPageData!.summary!.isNotEmpty) return;
         
         if (widget.pdfDocument != null) {
            setState(() => _isLoading = true);
            ref.read(summaryGenerationServiceProvider).ensureSummary(
              widget.bookId, 
              currentTrackedIndex, 
              widget.pdfDocument,
              locale: Localizations.localeOf(context).languageCode,
            ).then((_) {
              if (mounted && _lastProcessedPage == currentTrackedIndex) {
                 setState(() => _isLoading = false);
              }
            });
         }
      });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPage = ref.watch(currentPageProvider);
    final settings = ref.watch(settingsProvider);
    final panelWidth = ref.watch(aiPanelWidthProvider);
    final l10n = AppLocalizations.of(context)!;

    // Listen to page changes
    ref.listen(currentPageProvider, (previous, next) {
      if (next == _displayPageIndex) return;
      
      // Cleanup previous page logic
      _handlePageChange(next, settings);
      
      // Animation is triggered by _handlePageChange via _contentTransitionController.forward()
      // We don't need to manually trigger it here again, or we might double-trigger.
      // _handlePageChange calls forward(). The listener on controller calls _updateContentToPage + reverse().
    });
    
    // Initial load if needed
    if (_lastProcessedPage == null && currentPage > 0) {
      Future.microtask(() => _handlePageChange(currentPage, settings));
    }

    // Constraints for resizing
    final screenWidth = MediaQuery.of(context).size.width;
    final minWidth = screenWidth * 0.2;
    final maxWidth = screenWidth * 0.5;

    return SlideTransition(
      position: _slideAnimation,
      child: Row(
        mainAxisSize: MainAxisSize.min, // Important for right anchoring
        children: [
          // Resize Handle (Left Edge)
          MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                // Dragging left (negative dx) increases width
                // Dragging right (positive dx) decreases width
                final newWidth = panelWidth - details.delta.dx;
                if (newWidth >= minWidth && newWidth <= maxWidth) {
                   ref.read(aiPanelWidthProvider.notifier).setWidth(newWidth);
                }
              },
              child: Container(
                width: 8,
                color: Colors.transparent, // Invisible handle area
                child: VerticalDivider(
                  width: 1, 
                  thickness: 1, 
                  color: theme.colorScheme.outlineVariant
                ),
              ),
            ),
          ),
          
          // Main Panel Content
          SizedBox(
            width: panelWidth,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
              ),
              child: Column(
                children: [
                  // 1. Header (Static - No Blur/Fade)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
                    ),
                    child: Consumer(
                      builder: (context, ref, _) {
                        final pageDataAsync = ref.watch(watchPageDataProvider((bookId: widget.bookId, pageIndex: _displayPageIndex)));
                        final pageData = pageDataAsync.value;
                        final displaySummary = pageData?.summary;
                        
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('${l10n.pageSummary} $_displayPageIndex', style: theme.textTheme.titleSmall)),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  onPressed: () {
                                    if (displaySummary != null && displaySummary.isNotEmpty) {
                                      _copyToClipboard(displaySummary);
                                    }
                                  },
                                  tooltip: 'Copy Summary',
                                ),
                                const Gap(4),
                                IconButton(
                                  icon: const Icon(Icons.share, size: 20),
                                  onPressed: () => _exportContent(_displayPageIndex),
                                  tooltip: 'Export Page Content',
                                ),
                                const Gap(4),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 20),
                                  onPressed: _isLoading ? null : () => _refreshSummary(_displayPageIndex),
                                  tooltip: l10n.regenerateSummary,
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
                      }
                    ),
                  ),

                  // 2. Content (Animated - Blur/Fade)
                  Expanded(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _contentTransitionController,
                        builder: (context, child) {
                           // _contentFadeAnimation goes from 1.0 (Visible) to 0.0 (Hidden)
                           final visibility = _contentFadeAnimation.value;
                           
                           // Optimization: If hidden, don't paint
                           if (visibility <= 0) return const SizedBox();
                           
                           // Apply Blur and Opacity
                           // Blur: 10.0 (Hidden) -> 0.0 (Visible)
                           // Opacity: 0.0 (Hidden) -> 1.0 (Visible)
                           final blur = (1.0 - visibility) * 10.0;
                           final opacity = visibility.clamp(0.0, 1.0);
                           
                           Widget content = child!;
                           if (blur > 0) {
                             content = ImageFiltered(
                               imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                               child: content,
                             );
                           }
                           
                           return Opacity(
                             opacity: opacity,
                             child: content,
                           );
                        },
                        child: CustomScrollView(
                          controller: _scrollController,
                          slivers: [
                            // 2.1 Summary Section (Always at top)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final pageDataAsync = ref.watch(watchPageDataProvider((bookId: widget.bookId, pageIndex: _displayPageIndex)));
                                    final pageData = pageDataAsync.value;
                                    final displaySummary = pageData?.summary;

                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
                                              const Gap(8),
                                              Text(l10n.aiSummary, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                                              const Spacer(),
                                              if (settings.enablePseudoKBMode)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.secondaryContainer,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    l10n.multiPageContext,
                                                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSecondaryContainer),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const Gap(8),
                                          // Priority 1: Loading (Show if loading AND no summary text yet)
                                          if (_isLoading && (displaySummary == null || displaySummary.isEmpty))
                                            const Center(child: Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: CircularProgressIndicator(),
                                            ))
                                          // Priority 2: Countdown (Show if NOT loading and no summary text yet)
                                          // Ensure it shows when we are waiting (countdown running)
                                          else if (displaySummary == null || displaySummary.isEmpty)
                                            Center(child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: AnimatedBuilder(
                                                animation: _countdownController,
                                                builder: (context, child) {
                                                  // Only show if we have a valid countdown value or it's animating
                                                  // But we want it visible even at 0 if we are waiting for trigger?
                                                  // No, usually it animates 0->1.
                                                  // If value is 0 and not animating, maybe we shouldn't show it unless we want to show "ready"?
                                                  // Let's show it if value > 0 or animating.
                                                  if (_countdownController.value > 0 || _countdownController.isAnimating) {
                                                    return CircularProgressIndicator(
                                                      value: _countdownController.value,
                                                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                                    );
                                                  } else {
                                                    // If not animating and 0, maybe just a placeholder or empty?
                                                    // User said "circle disappeared". Maybe it's resetting too fast or not starting?
                                                    // Let's ensure we show SOMETHING if no summary.
                                                    return CircularProgressIndicator(
                                                      value: 0,
                                                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                                    );
                                                  }
                                                },
                                              ),
                                            ))
                                          // Priority 3: Content
                                          else
                                            StreamingTypewriterText(
                                              key: ValueKey(_displayPageIndex), 
                                              text: displaySummary!,
                                              speed: const Duration(milliseconds: 20),
                                              isStreaming: _isLoading, 
                                            ),
                                        ],
                                      ),
                                    );
                                  }
                                ),
                              ),
                            ),
                            
                            // 2.2 Chat History
                            Consumer(
                              builder: (context, ref, _) {
                                final pageDataAsync = ref.watch(watchPageDataProvider((bookId: widget.bookId, pageIndex: _displayPageIndex)));
                                final pageData = pageDataAsync.value;
                                if (pageData == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

                                return Consumer(
                                  builder: (context, ref, _) {
                                    final messagesAsync = ref.watch(watchMessagesProvider(pageData.id));
                                    final messages = messagesAsync.value ?? [];
                                    
                                    if (messages.isNotEmpty) {
                                       WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                                    }

                                    return SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final msg = messages[index];
                                          final isUser = msg.isUser;
                                          final isStreaming = !isUser && index == messages.length - 1 && _isLoading;
                                          
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                            child: Align(
                                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: isUser ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                constraints: BoxConstraints(maxWidth: panelWidth * 0.85),
                                                child: (msg.text.isEmpty && !isUser) 
                                                  ? const TypingIndicator()
                                                  : StreamingTypewriterText(
                                                      text: msg.text,
                                                      isStreaming: isStreaming,
                                                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                                                        p: theme.textTheme.bodyMedium?.copyWith(
                                                          color: isUser ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                                                          fontFamily: 'Noto Serif SC', // Ensure Serif font as requested
                                                        ),
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          );
                                        },
                                        childCount: messages.length,
                                      ),
                                    );
                                  }
                                );
                              }
                            ),
                            
                            // Bottom padding
                            const SliverToBoxAdapter(child: Gap(16)),
                          ],
                        ),
                      ),
                    ),
                  ),
              
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
              
                  // 3. Input Area (Static)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        decoration: InputDecoration(
                          hintText: l10n.enterMessage,
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                        onSubmitted: (value) => _sendMessage(value),
                      ),
                    ),
                    const Gap(8),
                    IconButton.filled(
                      icon: const Icon(Icons.send),
                      onPressed: _isLoading ? null : () => _sendMessage(_chatController.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
       )
      ]), // End Row
    ); // End SlideTransition
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handlePageChange(int pageIndex, SettingsModel settings) {
    // 1. Immediate Cleanup
    _aiSubscription?.cancel();
    _countdownController.stop();

    // Check if the current page OR the next page has data
    // If both have NO data, we skip the fade animation and just reset/restart countdown
    // This makes scrolling through empty pages feel faster/more responsive
    
    final repo = ref.read(pageRepositoryProvider);
    final currentPageData = repo.getPageData(widget.bookId, _displayPageIndex);
    final nextPageData = repo.getPageData(widget.bookId, pageIndex);
    
    final currentHasData = currentPageData?.summary != null && currentPageData!.summary!.isNotEmpty;
    final nextHasData = nextPageData?.summary != null && nextPageData!.summary!.isNotEmpty;

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

  Future<String?> _captureScreenshotBase64() async {
    if (widget.pdfKey.currentContext == null) return null;

    try {
      // Small delay to ensure rendering is complete
      await Future.delayed(const Duration(milliseconds: 100));

      RenderRepaintBoundary boundary = widget.pdfKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        return base64Encode(byteData.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint("Error capturing screenshot: $e");
    }
    return null;
  }
  
  // Render previous pages for enhanced context (PseudoKB Mode)
  Future<List<String>> _renderContextPages(int pageIndex) async {
    final settings = ref.read(settingsProvider);
    if (!settings.enablePseudoKBMode || widget.pdfDocument == null) return [];

    final doc = widget.pdfDocument as PdfDocument;
    final contextImages = <String>[];
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
            final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              contextImages.add(base64Encode(byteData.buffer.asUint8List()));
            }
          }
        } catch (e) {
          debugPrint('Error rendering context page $pNum: $e');
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
    _countdownController.stop();
    setState(() {
      _isLoading = true;
    });
    
    if (widget.pdfDocument != null) {
      // Force regeneration by clearing existing summary first?
      // Service checks DB. If we want to force, we might need to clear DB first.
      ref.read(pageRepositoryProvider).savePageSummary(widget.bookId, pageIndex, "", null);
      
      await ref.read(summaryGenerationServiceProvider).ensureSummary(
        widget.bookId, 
        pageIndex, 
        widget.pdfDocument,
        locale: Localizations.localeOf(context).languageCode,
      );
    }
    
    if (mounted) {
      setState(() {
        _currentPageData = ref.read(pageRepositoryProvider).getPageData(widget.bookId, pageIndex);
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    final pageIndex = ref.read(currentPageProvider);
    final repo = ref.read(pageRepositoryProvider);
    final l10n = AppLocalizations.of(context)!;
    
    // Ensure PageData exists
    var pageData = repo.getPageData(widget.bookId, pageIndex);
    if (pageData == null) {
       repo.savePageSummary(widget.bookId, pageIndex, "", null);
       pageData = repo.getPageData(widget.bookId, pageIndex);
    }
    
    if (pageData == null) return;
    
    setState(() {
      _currentPageData = pageData;
    });

    repo.addMessage(pageData.id, text, true);
    _chatController.clear();
    
    // Cancel previous AI action
    _aiSubscription?.cancel();

    setState(() {
      _isLoading = true;
    });

    final base64Image = await _captureScreenshotBase64();
    if (base64Image == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    
    // Get context pages if enabled
    final contextImages = await _renderContextPages(pageIndex);
    // Combine context + current page (screenshot)
    final allImages = [...contextImages, base64Image];

    final history = repo.getRecentMessages(pageData.id);
    final aiService = ref.read(aiServiceProvider);
    final StringBuffer responseBuffer = StringBuffer();
    final locale = Localizations.localeOf(context).toString();
    
    // Add temporary AI loading message
    final loadingMsgId = repo.addMessage(pageData.id, "", false);

    try {
      final stream = aiService.chatWithPage(
        prompt: text,
        base64Images: allImages,
        summary: pageData.summary,
        history: history,
        locale: locale,
      );

      _aiSubscription = stream.listen(
        (chunk) {
          responseBuffer.write(chunk);
          // Update message content in real-time
          repo.updateMessage(loadingMsgId, responseBuffer.toString());
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _isLoading = false);
        },
        onError: (e) {
          if (!mounted) return;
          repo.updateMessage(loadingMsgId, "${l10n.errorPrefix}$e");
          setState(() => _isLoading = false);
        },
        cancelOnError: true,
      );

    } catch (e) {
      if (mounted) {
          repo.updateMessage(loadingMsgId, "${l10n.errorPrefix}$e");
          setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportContent(int pageNumber) async {
    final l10n = AppLocalizations.of(context)!;
    final sb = StringBuffer();
    sb.writeln('${l10n.pageSummary} $pageNumber');
    sb.writeln('=' * 20);
    sb.writeln();
    
    // Use currentPageData summary directly
    final currentSummary = _currentPageData?.summary;
    if (currentSummary != null && currentSummary.isNotEmpty) {
      sb.writeln(l10n.aiSummary);
      sb.writeln('-' * 10);
      sb.writeln(currentSummary);
      sb.writeln();
    }
    
    if (_currentPageData != null) {
      // Fetch recent messages synchronously (or we need to add a method to repo to get all)
      // For now, let's just use what's available or implement a getAllMessages
      final messages = ref.read(pageRepositoryProvider).getRecentMessages(_currentPageData!.id, limit: 100);
      if (messages.isNotEmpty) {
        sb.writeln(l10n.chat);
        sb.writeln('-' * 10);
        for (final msg in messages) {
          sb.writeln('${msg.isUser ? "User" : "AI"}: ${msg.text}');
          sb.writeln();
        }
      }
    }
    
    final text = sb.toString();
    if (text.trim().isEmpty) return;
    
    await Share.share(text, subject: '${l10n.pageSummary} $pageNumber');
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}
