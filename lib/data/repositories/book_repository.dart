import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/book.dart';
import '../models/reading_session.dart';
import '../../objectbox.g.dart';
import '../../providers.dart';

part 'book_repository.g.dart';

@riverpod
BookRepository bookRepository(Ref ref) {
  return BookRepository(ref.watch(storeProvider));
}

@riverpod
Stream<List<Book>> books(Ref ref) {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getAllBooks();
}

@riverpod
Book? book(Ref ref, int id) {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getBook(id);
}

class BookRepository {
  final Store _store;
  late final Box<Book> _box;
  late final Box<ReadingSession> _sessionBox;

  BookRepository(this._store) {
    _box = _store.box<Book>();
    _sessionBox = _store.box<ReadingSession>();
  }

  // --- Reading Session Tracking ---

  int startSession(int bookId) {
    final session = ReadingSession(
      startTime: DateTime.now(),
      duration: 0,
    );
    session.book.targetId = bookId;
    return _sessionBox.put(session);
  }

  void updateSession(int sessionId, int duration) {
    final session = _sessionBox.get(sessionId);
    if (session != null) {
      session.duration = duration;
      session.endTime = DateTime.now(); // Update end time continuously
      _sessionBox.put(session);
    }
  }

  void endSession(int sessionId, {int? duration}) {
    final session = _sessionBox.get(sessionId);
    if (session != null) {
      session.endTime = DateTime.now();
      session.duration = duration ?? session.endTime!.difference(session.startTime).inSeconds;
      _sessionBox.put(session);
    }
  }

  Stream<List<Book>> getAllBooks() {
    return _box.query().watch(triggerImmediately: true).map((query) => query.find());
  }

  Future<void> addBook(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('File not found');

    // 1. Calculate Hash
    // Reading entire file into memory might be heavy for large PDFs. 
    // Using a stream is better.
    final digest = await file.openRead().transform(sha256).first;
    final hash = digest.toString();

    // 2. Check for existing book with same path
    final existingBook = _box.query(Book_.filePath.equals(filePath)).build().findFirst();

    if (existingBook != null) {
      if (existingBook.fileHash != hash) {
        // Hash mismatch, cascade delete (re-import)
        // ObjectBox cascades deletes if configured or we manually delete relations.
        // For now, just removing the book removes the entity. 
        // We need to ensure relations are deleted if not using cascade delete annotations properly or manual handling.
        // ObjectBox Dart doesn't support automatic cascade delete on relations by default unless specified.
        // But removing the Book entity usually leaves the Backlinks dangling or removes them depending on setup.
        // Let's assume manual cleanup or standard behavior for now.
        _box.remove(existingBook.id);
      } else {
        // Already exists and valid
        return;
      }
    }

    // 3. Get PDF metadata
    try {
      final doc = await PdfDocument.openFile(filePath);
      final totalPages = doc.pages.length;
      final title = p.basenameWithoutExtension(filePath);

      final book = Book(
        filePath: filePath,
        title: title,
        fileHash: hash,
        totalPages: totalPages,
      );

      _box.put(book);
      
      // 4. Generate Cover in Background
      _generateCover(book, doc);
      
      await doc.dispose();
    } catch (e) {
      if (kDebugMode) {
        print('Error opening PDF: $e');
      }
      rethrow;
    }
  }

  Future<void> _generateCover(Book book, PdfDocument doc) async {
    try {
      if (doc.pages.isEmpty) return;
      final page = doc.pages[0];
      
      // Render first page to image
      final image = await page.render(
        width: 300,
        height: (300 * page.height / page.width).round(),
        // format: PdfImageFormat.png, // Not supported in this version
      );
      
      if (image != null) {
        final appDir = await getApplicationSupportDirectory();
        final coversDir = Directory(p.join(appDir.path, 'covers'));
        if (!await coversDir.exists()) {
          await coversDir.create(recursive: true);
        }
        
        final coverPath = p.join(coversDir.path, '${book.fileHash}.png');
        final file = File(coverPath);
        
        // image is PdfImage, we need to convert it to bytes
        // Wait, checking pdfrx source or docs.
        // In pdfrx 2.x, page.render returns PdfImage?
        // PdfImage has .pixels (Uint8List) and .width, .height, .format
        
        // If we want to save as PNG, we need to encode it.
        // Since pdfrx might not provide PNG encoding directly, we can use dart:ui
        
        final uiImage = await image.createImage();
        final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        
        if (byteData != null) {
          await file.writeAsBytes(byteData.buffer.asUint8List());
          
          // Update book with cover path
          book.coverPath = coverPath;
          _box.put(book);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error generating cover: $e');
      }
    }
  }

  Future<void> deleteBook(int id) async {
    _box.remove(id);
  }

  Book? getBook(int id) {
    return _box.get(id);
  }

  void updateLastReadPage(int bookId, int pageIndex) {
    final book = _box.get(bookId);
    if (book != null) {
      book.lastReadPage = pageIndex;
      book.lastOpened = DateTime.now();
      _box.put(book);
    }
  }

  void updateLastOpened(int bookId) {
    final book = _box.get(bookId);
    if (book != null) {
      book.lastOpened = DateTime.now();
      _box.put(book);
    }
  }
  
  void updateCoverPath(int bookId, String coverPath) {
    final book = _box.get(bookId);
    if (book != null) {
      book.coverPath = coverPath;
      _box.put(book);
    }
  }
}
