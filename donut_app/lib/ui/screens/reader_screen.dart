import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../data/repositories/book_repository.dart';
import '../widgets/ai_panel.dart';
import 'reader/reader_state.dart';

import '../../services/settings_service.dart';

import '../widgets/thumbnail_sidebar/thumbnail_sidebar.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final int bookId;

  const ReaderScreen({super.key, required this.bookId});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  final GlobalKey _pdfKey = GlobalKey(); 
  bool _showAiPanel = true;
  bool _showSidebar = true;
  bool _immersiveMode = false;
  bool _focusMode = false;
  bool _isPdfReady = false; // Add flag for lazy loading sidebars
  
  // Reading Session
  int? _sessionId;
  Timer? _sessionTimer;
  DateTime? _activeSegmentStartTime;
  int _accumulatedActiveSeconds = 0;
  bool _isReaderForegroundActive = false;
  late final AppLifecycleListener _lifecycleListener;
  late final BookRepository _bookRepository;

  PdfDocument? _document;
  Future<String>? _resolvedPdfPathFuture;
  String? _resolvedForBookPath;

  @override
  void initState() {
    super.initState();
    // Capture the repository instance in initState where ref is safe
    _bookRepository = ref.read(bookRepositoryProvider);
    
    // Defer heavy session logic to next frame to allow UI to render first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startSession();
      }
    });
    
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _handleLifecycleChange,
    );
    
    // 修复初始化时页码可能为 0 的问题
    // Also use addPostFrameCallback for page jump, which is good.
    // We can combine these or keep them separate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (mounted) {
         // bookProvider is synchronous here
         final book = ref.read(bookProvider(widget.bookId));
         if (book != null && book.lastReadPage > 0) {
           ref.read(currentPageProvider.notifier).setPage(book.lastReadPage);
         } else {
           ref.read(currentPageProvider.notifier).setPage(1);
         }
       }
    });
    
    // Delay AiPanel initialization slightly if possible?
    // Actually, AiPanel is in build().
    // We can use a flag to delay showing heavy widgets until PDF is ready.
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _endSession();
    super.dispose();
  }

  void _startSession() {
    _sessionId = _bookRepository.startSession(widget.bookId);
    _accumulatedActiveSeconds = 0;
    _activeSegmentStartTime = null;
    _isReaderForegroundActive = false;
    _setReaderForegroundActive(
      SchedulerBinding.instance.lifecycleState == null ||
          SchedulerBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
    
    // Auto-save every 1 minute
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_sessionId != null) {
        final duration = _currentForegroundDurationInSeconds();
        if (duration > 86400) {
          _endSession();
          _startSession();
          return;
        }
        _bookRepository.updateSession(_sessionId!, duration);
      }
    });
  }

  void _endSession() {
    _sessionTimer?.cancel();
    if (_sessionId != null) {
      _setReaderForegroundActive(false);
      final duration = _currentForegroundDurationInSeconds();
      if (duration < 86400) {
        _bookRepository.updateSession(_sessionId!, duration);
      }
      _bookRepository.endSession(_sessionId!, duration: duration);
      _sessionId = null;
      _activeSegmentStartTime = null;
      _accumulatedActiveSeconds = 0;
      _isReaderForegroundActive = false;
    }
  }

  void _handleLifecycleChange(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _setReaderForegroundActive(false);
      if (_sessionId != null) {
        final duration = _currentForegroundDurationInSeconds();
        if (duration < 86400) {
          _bookRepository.updateSession(_sessionId!, duration);
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      _setReaderForegroundActive(true);
    }
  }

  void _setReaderForegroundActive(bool isActive) {
    if (_sessionId == null || _isReaderForegroundActive == isActive) return;

    if (isActive) {
      _activeSegmentStartTime ??= DateTime.now();
    } else {
      if (_activeSegmentStartTime != null) {
        _accumulatedActiveSeconds += DateTime.now().difference(_activeSegmentStartTime!).inSeconds;
        _activeSegmentStartTime = null;
      }
    }

    _isReaderForegroundActive = isActive;
  }

  int _currentForegroundDurationInSeconds() {
    final liveSeconds = _isReaderForegroundActive && _activeSegmentStartTime != null
        ? DateTime.now().difference(_activeSegmentStartTime!).inSeconds
        : 0;
    return _accumulatedActiveSeconds + liveSeconds;
  }

  @override
  Widget build(BuildContext context) {
    // bookProvider returns Book? (synchronous), not AsyncValue
    final book = ref.watch(bookProvider(widget.bookId));
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    if (book == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Book not found')),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true, // Allow content to go behind app bar
      appBar: (_immersiveMode || _focusMode)
          ? null // Hide app bar in immersive mode or focus mode
          : AppBar(
              title: Text(book.title),
              backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.9), // Semi-transparent
              elevation: 0,
              // Explicitly add back button AND sidebar toggle
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                  ),
                ],
              ),
              leadingWidth: 100, // Allocate space for leading row
              titleSpacing: 0, // Reduce gap
              actions: [
                IconButton(
                  icon: const Icon(Icons.filter_center_focus),
                  onPressed: () {
                    setState(() {
                      _focusMode = true;
                      _immersiveMode = true; // Also trigger immersive logic
                    });
                  },
                  tooltip: 'Focus Mode',
                ),
                IconButton(
                  icon: Icon(_showSidebar ? Icons.menu_open : Icons.menu),
                  onPressed: () {
                    setState(() {
                      _showSidebar = !_showSidebar;
                    });
                  },
                  tooltip: 'Toggle Sidebar',
                ),
                IconButton(
                  icon: Icon(_showAiPanel ? Icons.auto_awesome : Icons.auto_awesome_outlined),
                  onPressed: () {
                    setState(() {
                      _showAiPanel = !_showAiPanel;
                    });
                  },
                  tooltip: 'Toggle AI Panel',
                ),
              ],
            ),
      body: Stack(
        children: [
          // Background Listener for taps (using Listener to avoid stealing gestures from PDF)
          // Actually, pdfrx might consume taps.
          // Let's try wrapping the PDF viewer specifically or use a transparent overlay that passes through?
          // If we use HitTestBehavior.translucent in a stack above, it might block if it handles onTap.
          
          // Better approach: Wrap the Scaffold body content in a GestureDetector that handles tap
          // BUT ensure PDF viewer gets it too.
          // Since pdfrx doesn't expose onTap easily, we might need to rely on the fact that 
          // if we put a GestureDetector *below* the PDF (in Z-index), it won't get hit if PDF consumes it.
          // If we put it *above* with translucent, it gets hit first.
          
          // Let's put the main content (including PDF) in the stack.
          // And we want a tap ANYWHERE to toggle immersive mode, unless it's a button.
          
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (_focusMode) {
                    // In focus mode, tap does NOT toggle app bar
                  } else {
                    _immersiveMode = !_immersiveMode;
                  }
                });
              },
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),

      // Main Content
          Padding(
            padding: EdgeInsets.only(top: (_immersiveMode || _focusMode) ? 0 : kToolbarHeight + MediaQuery.of(context).padding.top), 
            child: Row(
              children: [
              // Sidebar
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                width: _showSidebar ? 200 : 0,
                // Ensure Sidebar content respects the top padding as well if needed, 
                // but since we are inside a Padding that already pushes everything down by kToolbarHeight,
                // the sidebar starts below the AppBar. Correct.
                child: _showSidebar && _isPdfReady && _document != null
                    ? ThumbnailSidebar(
                        document: _document!,
                        currentPage: ref.watch(currentPageProvider),
                        onPageSelected: (page) {
                          _pdfController.goToPage(pageNumber: page);
                        },
                      )
                    : null,
              ),
              Expanded(
                child: Stack(
                  children: [
                    RepaintBoundary(
                      key: _pdfKey,
                      child: Builder(
                        builder: (context) {
                          if (_resolvedForBookPath != book.filePath ||
                              _resolvedPdfPathFuture == null) {
                            _resolvedForBookPath = book.filePath;
                            _resolvedPdfPathFuture =
                                _bookRepository.ensureReadablePdfPath(book);
                          }

                          return FutureBuilder<String>(
                            future: _resolvedPdfPathFuture,
                            builder: (context, snapshot) {
                              final resolvedPath = snapshot.data;
                              if (resolvedPath == null) {
                                if (snapshot.hasError) {
                                  return const Center(child: Text('Failed to load PDF'));
                                }
                                return const Center(child: CircularProgressIndicator());
                              }

                              return PdfViewer.file(
                                resolvedPath,
                                controller: _pdfController,
                                initialPageNumber: book.lastReadPage > 0
                                    ? book.lastReadPage
                                    : 1,
                                params: PdfViewerParams(
                                  layoutPages:
                                      settings.readingDirection ==
                                              ReadingDirection.vertical
                                          ? null
                                          : (pages, params) {
                                              double x = 0;
                                              final pageLayouts = <Rect>[];
                                              for (var page in pages) {
                                                final rect = Rect.fromLTWH(
                                                  x,
                                                  0,
                                                  page.width,
                                                  page.height,
                                                );
                                                pageLayouts.add(rect);
                                                x += page.width;
                                              }
                                              return PdfPageLayout(
                                                pageLayouts: pageLayouts,
                                                documentSize: Size(
                                                  x,
                                                  pages.isEmpty ? 0 : pages[0].height,
                                                ),
                                              );
                                            },
                                  onPageChanged: (page) {
                                    ref.read(currentPageProvider.notifier).setPage(page ?? 1);
                                    ref
                                        .read(bookRepositoryProvider)
                                        .updateLastReadPage(widget.bookId, page ?? 1);
                                  },
                                  onViewerReady: (document, controller) {
                                    if (mounted) {
                                      setState(() {
                                        _document = document;
                                        _isPdfReady = true;
                                      });
                                    }
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    // Page Indicator (Bottom)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      bottom: (_immersiveMode || _focusMode) ? -100 : 16, // Slide out in immersive OR focus mode
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Consumer(
                            builder: (context, ref, _) {
                              final page = ref.watch(currentPageProvider);
                              return Text('$page/${book.totalPages}');
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Spacer to prevent PDF from being covered by AI Panel
              // We need to know the width of the AI Panel to add correct padding/spacer
              // Using a Consumer to listen to panel width state would be ideal, 
              // but for now let's rely on the AI Panel being an overlay or adjust layout.
              // The requirement says: "PDF 阅读区域能够根据 AI 面板的 width 动态挤压"
              // So we should put AI Panel in the Row, but the requirement also says:
              // "在 Stack 布局中，使用 Positioned 将 AI 面板固定在 right: 0"
              // This seems contradictory. 
              // "锚点固定： 在 Stack 布局中，使用 Positioned 将 AI 面板固定在 right: 0。宽度调整时，应改变面板的左侧边界"
              // AND "需确保 PDF 阅读区域能够根据 AI 面板的 width 动态挤压"
              
              // To satisfy both:
              // 1. We use a Row. Left side is Expanded PDF. Right side is a SizedBox with width matching AI Panel.
              // 2. BUT the AI Panel itself is in a Stack on top of everything? 
              // If we use Row, resizing AI Panel (changing its width) will automatically squeeze the PDF (Expanded).
              // So a simple Row structure is actually better and simpler than Stack+Positioned for "squeezing" effect.
              // However, the prompt explicitly asks for "Stack layout" and "Positioned right:0".
              
              // Let's implement the "Squeeze" effect by having a transparent placeholder in the Row that matches the panel width.
              // And the actual Panel is in a Stack on top.
              
              // Actually, if we use a Row with [Expanded(PDF), AiPanel()], resizing AiPanel width will squeeze PDF.
              // This is the standard behavior.
              // The "Stack + Positioned" requirement might be for the *animation* or *overlay* effect?
              // "SlideTransition" suggests it might slide *over* content or push content.
              
              // Let's follow the "Stack + Positioned" instruction strictly for the Panel itself, 
              // and use a "SizedBox" in the Row to achieve the squeeze effect.
              Consumer(builder: (context, ref, _) {
                 final panelWidth = ref.watch(aiPanelWidthProvider);
                 return AnimatedContainer(
                   duration: const Duration(milliseconds: 300),
                   curve: Curves.easeInOutCubic,
                   width: _showAiPanel ? panelWidth : 0,
                 );
              }),
            ],
          ),
        ), // End Row Padding
          
          // AI Panel Overlay
          if (_isPdfReady && _document != null)
            Positioned(
              top: (_immersiveMode || _focusMode) ? 0 : kToolbarHeight + MediaQuery.of(context).padding.top,
              bottom: 0,
              right: 0,
              child: AiPanel(
                bookId: widget.bookId,
                pdfKey: _pdfKey,
                isVisible: _showAiPanel,
                onClose: () {
                  setState(() {
                    _showAiPanel = false;
                  });
                },
                pdfDocument: _document,
              ),
            ),
          // Persistent Focus Mode Controls
          if (_focusMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'exit_focus',
                    onPressed: () {
                      setState(() {
                        _focusMode = false;
                        _immersiveMode = false;
                      });
                    },
                    tooltip: 'Exit Focus Mode',
                    child: const Icon(Icons.close_fullscreen),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'toggle_sidebar',
                    onPressed: () {
                      setState(() {
                        _showSidebar = !_showSidebar;
                      });
                    },
                    tooltip: 'Toggle Sidebar',
                    child: Icon(_showSidebar ? Icons.menu_open : Icons.menu),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'toggle_ai',
                    onPressed: () {
                      setState(() {
                        _showAiPanel = !_showAiPanel;
                      });
                    },
                    tooltip: 'Toggle AI Panel',
                    child: Icon(_showAiPanel ? Icons.auto_awesome : Icons.auto_awesome_outlined),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
