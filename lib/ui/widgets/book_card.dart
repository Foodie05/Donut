import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/book.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/page_repository.dart';
import '../../l10n/app_localizations.dart';
import '../screens/reader_screen.dart';

class BookCard extends ConsumerStatefulWidget {
  final Book book;

  const BookCard({super.key, required this.book});

  @override
  ConsumerState<BookCard> createState() => _BookCardState();
}

class _BookCardState extends ConsumerState<BookCard> {
  bool _isHovering = false;

  Future<String?> _selectExportFormat() async {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.exportBookFile),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('PDF'),
                subtitle: Text(l10n.exportFormatPdfSubtitle),
                onTap: () => Navigator.of(dialogContext).pop('pdf'),
              ),
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const Text('DPDF'),
                subtitle: Text(l10n.exportFormatDpdfSubtitle),
                onTap: () => Navigator.of(dialogContext).pop('dpdf'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showDelayedConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            var secondsLeft = 3;
            Timer? timer;

            return StatefulBuilder(
              builder: (context, setState) {
                timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
                  if (!dialogContext.mounted) return;
                  setState(() {
                    secondsLeft -= 1;
                    if (secondsLeft <= 0) {
                      secondsLeft = 0;
                      timer?.cancel();
                    }
                  });
                });

                return PopScope(
                  canPop: false,
                  child: AlertDialog(
                    title: Text(title),
                    content: Text(message),
                    actions: [
                      TextButton(
                        onPressed: () {
                          timer?.cancel();
                          Navigator.of(dialogContext).pop(false);
                        },
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: secondsLeft <= 0
                            ? () {
                                timer?.cancel();
                                Navigator.of(dialogContext).pop(true);
                              }
                            : null,
                        child: Text(
                          secondsLeft <= 0
                              ? confirmLabel
                              : '$confirmLabel (${secondsLeft}s)',
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ) ??
        false;
  }

  Future<void> _showContextMenu(Offset globalPosition) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'export',
          child: Text(l10n.exportBookFile),
        ),
        PopupMenuItem<String>(value: 'reset_ai', child: Text(l10n.resetAiData)),
        PopupMenuItem<String>(value: 'delete', child: Text(l10n.deleteBook)),
      ],
    );

    if (!mounted || selected == null) return;

    if (selected == 'export') {
      final selectedFormat = await _selectExportFormat();
      if (!mounted || selectedFormat == null) return;

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.exportBookFile,
        fileName: '${widget.book.title}.$selectedFormat',
        type: FileType.custom,
        allowedExtensions: [selectedFormat],
      );
      if (savePath == null) return;
      try {
        await ref
            .read(bookRepositoryProvider)
            .exportBookFile(widget.book.id, savePath, format: selectedFormat);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.exportBookFileSuccess)));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.exportBookFileFailed)));
      }
      return;
    }

    if (selected == 'reset_ai') {
      final confirmed = await _showDelayedConfirmDialog(
        title: l10n.resetAiData,
        message: l10n.resetAiDataWarning,
        confirmLabel: l10n.confirm,
      );
      if (!confirmed || !mounted) return;

      ref.read(pageRepositoryProvider).clearBookAiData(widget.book.id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.resetAiDataDone)));
      return;
    }

    if (selected == 'delete') {
      final confirmed = await _showDelayedConfirmDialog(
        title: l10n.deleteBook,
        message: l10n.deleteBookWarning,
        confirmLabel: l10n.confirm,
      );
      if (!confirmed || !mounted) return;
      await ref.read(bookRepositoryProvider).deleteBook(widget.book.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        onSecondaryTapUp: (details) => _showContextMenu(details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          transform: _isHovering
              ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Card(
            elevation: _isHovering ? 8 : 2,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: widget.book.coverPath != null
                      ? Image.file(
                          File(widget.book.coverPath!),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHigh,
                          child: Icon(
                            Icons.picture_as_pdf,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
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
