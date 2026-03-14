import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/book.dart';
import '../screens/reader_screen.dart';
import '../../data/repositories/book_repository.dart';
import '../../l10n/app_localizations.dart';
import 'dart:io';

class BookCard extends ConsumerStatefulWidget {
  final Book book;

  const BookCard({super.key, required this.book});

  @override
  ConsumerState<BookCard> createState() => _BookCardState();
}

class _BookCardState extends ConsumerState<BookCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(bookId: widget.book.id),
            ),
          );
        },
        onSecondaryTapUp: (details) {
          showMenu(
            context: context,
            position: RelativeRect.fromLTRB(
              details.globalPosition.dx,
              details.globalPosition.dy,
              details.globalPosition.dx,
              details.globalPosition.dy,
            ),
            items: [
              PopupMenuItem(
                child: Text(l10n.deleteBook),
                onTap: () {
                  ref.read(bookRepositoryProvider).deleteBook(widget.book.id);
                },
              ),
              PopupMenuItem(
                child: Text(l10n.resetAiData),
                onTap: () {
                  // TODO: Reset AI data logic
                },
              ),
            ],
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          transform: _isHovering ? Matrix4.diagonal3Values(1.05, 1.05, 1.0) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Card(
            elevation: _isHovering ? 8 : 2,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: widget.book.coverPath != null
                      ? Image.file(File(widget.book.coverPath!), fit: BoxFit.cover)
                      : Container(
                          color: theme.colorScheme.surfaceContainerHigh,
                          child: Icon(Icons.picture_as_pdf, size: 48, color: theme.colorScheme.onSurfaceVariant),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: widget.book.totalPages > 0 
                            ? widget.book.lastReadPage / widget.book.totalPages 
                            : 0,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
