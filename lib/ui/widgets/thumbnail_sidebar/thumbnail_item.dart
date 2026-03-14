import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

// Simple memory cache for thumbnails
class ThumbnailCache {
  static final Map<String, Uint8List> _cache = {};
  static const int _maxCacheSize = 50; // Keep last 50 thumbnails

  static Uint8List? get(String key) => _cache[key];

  static void put(String key, Uint8List data) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = data;
  }
}

class ThumbnailItem extends StatefulWidget {
  final PdfDocument document;
  final int pageNumber;
  final bool isSelected;
  final VoidCallback onTap;

  const ThumbnailItem({
    super.key,
    required this.document,
    required this.pageNumber,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<ThumbnailItem> createState() => _ThumbnailItemState();
}

class _ThumbnailItemState extends State<ThumbnailItem> {
  Uint8List? _imageData;
  bool _isLoading = false;
  double _aspectRatio = 1.0; // Default aspect ratio

  @override
  void initState() {
    super.initState();
    _initPageInfo();
    _checkCacheAndLoad();
  }

  @override
  void didUpdateWidget(ThumbnailItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.document != oldWidget.document || widget.pageNumber != oldWidget.pageNumber) {
      _initPageInfo();
      _checkCacheAndLoad();
    }
  }

  void _initPageInfo() {
    // Synchronously get page info if available, or just use what we have.
    // pdfrx PdfDocument.pages is a list of PdfPage, which has width and height.
    // Accessing pages[i] is synchronous.
    try {
      final page = widget.document.pages[widget.pageNumber - 1];
      if (page.width > 0 && page.height > 0) {
        _aspectRatio = page.width / page.height;
      }
    } catch (e) {
      debugPrint('Error getting page info: $e');
    }
  }

  void _checkCacheAndLoad() {
    final key = '${widget.document.sourceName}_${widget.pageNumber}';
    final cached = ThumbnailCache.get(key);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _imageData = cached;
          _isLoading = false;
        });
      }
    } else {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    final key = '${widget.document.sourceName}_${widget.pageNumber}';
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Using pdfrx to render page image
      // Fixed width for thumbnail rendering quality
      const renderWidth = 300.0; 
      final page = widget.document.pages[widget.pageNumber - 1];
      
      // Calculate height to maintain aspect ratio
      final height = (renderWidth / _aspectRatio).toInt();

      final image = await page.render(
        // Set the output image dimensions (pixels)
        width: renderWidth.toInt(),
        height: height,
        
        // Set the "virtual" page size to render into these dimensions.
        // By setting fullWidth/fullHeight to match the output width/height,
        // we force the library to scale the content to fit.
        // If we don't set these, it might use the page's original point size as the virtual size
        // and just crop/viewport into it if scale isn't inferred correctly.
        // Actually, typically fullWidth/fullHeight define the size of the *content area* being rendered.
        
        // Wait, if I set fullWidth = renderWidth, does it mean "render the whole page as if it were renderWidth wide"?
        // Yes, that should achieve scaling.
        fullWidth: renderWidth,
        fullHeight: height.toDouble(),
        
        backgroundColor: Colors.white.value, 
      );
      
      if (image != null && mounted) {
        // Debug: Print dimensions to verify
        // debugPrint('Page ${widget.pageNumber}: Rendered ${image.width}x${image.height}, Expected ${renderWidth.toInt()}x$height');
        
        final uiImage = await image.createImage();
        final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        
        if (byteData != null) {
          final pngBytes = byteData.buffer.asUint8List();
          ThumbnailCache.put(key, pngBytes);
          if (mounted) {
            setState(() {
              _imageData = pngBytes;
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading thumbnail: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Aspect Ratio Container
            AspectRatio(
              aspectRatio: _aspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16), 
                  border: widget.isSelected
                      ? Border.all(color: theme.colorScheme.primary, width: 3)
                      : Border.all(color: Colors.transparent, width: 3), // Keep layout stable
                  color: theme.colorScheme.surfaceContainerHighest, // Shallow gray background
                ),
                padding: const EdgeInsets.all(4), 
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    crossFadeState: _imageData != null
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    secondChild: _imageData != null
                        ? Center( // Ensure image is centered
                            child: Image.memory(
                              _imageData!,
                              fit: BoxFit.contain, // Or BoxFit.fill if we are confident about ratio
                              // Removing width/height infinity to let image size itself naturally within parent constraint
                              gaplessPlayback: true,
                            ),
                          )
                        : const SizedBox(),
                    layoutBuilder: (topChild, topChildKey, bottomChild, bottomChildKey) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            key: bottomChildKey,
                            child: bottomChild,
                          ),
                          Positioned.fill(
                            key: topChildKey,
                            child: topChild,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.pageNumber}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: widget.isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
