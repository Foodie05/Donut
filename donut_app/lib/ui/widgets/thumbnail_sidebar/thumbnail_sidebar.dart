import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'thumbnail_item.dart';

class ThumbnailSidebar extends ConsumerStatefulWidget {
  final PdfDocument document;
  final int currentPage;
  final Function(int) onPageSelected;

  const ThumbnailSidebar({
    super.key,
    required this.document,
    required this.currentPage,
    required this.onPageSelected,
  });

  @override
  ConsumerState<ThumbnailSidebar> createState() => _ThumbnailSidebarState();
}

class _ThumbnailSidebarState extends ConsumerState<ThumbnailSidebar> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  
  @override
  void initState() {
    super.initState();
    // Ensure initial scroll after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToCurrentPage();
      }
    });
  }

  @override
  void didUpdateWidget(ThumbnailSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPage != oldWidget.currentPage) {
      _scrollToCurrentPage();
    }
  }

  void _scrollToCurrentPage() {
    if (!_itemScrollController.isAttached) return;

    final index = widget.currentPage - 1;
    
    // Use scrollable_positioned_list for precise alignment
    // alignment: 0.5 means the item will be centered in the viewport
    _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.5, 
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageCount = widget.document.pages.length;

    return Container(
      width: 200, // Fixed width for sidebar
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: ScrollablePositionedList.builder(
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        itemCount: pageCount,
        itemBuilder: (context, index) {
          final pageNumber = index + 1;
          final isSelected = pageNumber == widget.currentPage;
          
          return Container(
            // Ensure style consistency for selected item
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ThumbnailItem(
              document: widget.document,
              pageNumber: pageNumber,
              isSelected: isSelected,
              onTap: () => widget.onPageSelected(pageNumber),
            ),
          );
        },
      ),
    );
  }
}
