import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../objectbox.g.dart';
import '../../providers.dart';
import '../../services/dpdf_service.dart';
import '../models/book.dart';
import '../models/chat_message.dart';
import '../models/page_data.dart';
import '../models/reading_session.dart';

part 'book_repository.g.dart';

class DuplicateBookException implements Exception {
  final Book existingBook;

  const DuplicateBookException(this.existingBook);
}

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
  late final Box<PageData> _pageBox;
  late final Box<ChatMessage> _messageBox;

  BookRepository(this._store) {
    _box = _store.box<Book>();
    _sessionBox = _store.box<ReadingSession>();
    _pageBox = _store.box<PageData>();
    _messageBox = _store.box<ChatMessage>();
  }

  Future<Directory> _dpdfLibraryDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'dpdf_library'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _pdfCacheDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'pdf_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> _managedDpdfPathForHash(String hash, {String? suffix}) async {
    final dir = await _dpdfLibraryDirectory();
    final name = suffix == null ? hash : '$hash-$suffix';
    return p.join(dir.path, '$name.dpdf');
  }

  Future<String> _cachePdfPathForHash(String hash) async {
    final dir = await _pdfCacheDirectory();
    return p.join(dir.path, '$hash.pdf');
  }

  Future<String> ensureReadablePdfPath(Book book) async {
    if (!isDpdfPath(book.filePath)) return book.filePath;

    final cachePath = await _cachePdfPathForHash(book.fileHash);
    final cacheFile = File(cachePath);
    if (await cacheFile.exists()) return cachePath;

    final pdfBytes = await extractPdfBytes(book.filePath);
    await cacheFile.writeAsBytes(pdfBytes, flush: true);
    return cachePath;
  }

  // --- Reading Session Tracking ---

  int startSession(int bookId) {
    final session = ReadingSession(startTime: DateTime.now(), duration: 0);
    session.book.targetId = bookId;
    return _sessionBox.put(session);
  }

  void updateSession(int sessionId, int duration) {
    final session = _sessionBox.get(sessionId);
    if (session != null) {
      session.duration = duration;
      session.endTime = DateTime.now();
      _sessionBox.put(session);
    }
  }

  void endSession(int sessionId, {int? duration}) {
    final session = _sessionBox.get(sessionId);
    if (session != null) {
      session.endTime = DateTime.now();
      session.duration =
          duration ?? session.endTime!.difference(session.startTime).inSeconds;
      _sessionBox.put(session);
    }
  }

  Stream<List<Book>> getAllBooks() {
    return _box
        .query()
        .watch(triggerImmediately: true)
        .map((query) => query.find());
  }

  Map<String, dynamic> _buildLegacyAiDataFromObjectBox(int bookId) {
    final pagesQuery = _pageBox.query(PageData_.book.equals(bookId)).build();
    final pages = pagesQuery.find();
    pagesQuery.close();

    final pageEntries = <Map<String, dynamic>>[];
    int maxMessageId = 0;

    for (final page in pages) {
      final msgQuery = _messageBox
          .query(ChatMessage_.pageData.equals(page.id))
          .order(ChatMessage_.timestamp)
          .build();
      final messages = msgQuery.find();
      msgQuery.close();

      final jsonMessages = <Map<String, dynamic>>[];
      for (final message in messages) {
        if (message.id > maxMessageId) maxMessageId = message.id;
        jsonMessages.add({
          'id': message.id,
          'text': message.text,
          'isUser': message.isUser,
          'timestamp': message.timestamp.toUtc().toIso8601String(),
        });
      }

      pageEntries.add({
        'pageIndex': page.pageIndex,
        'profiles': {
          page.profileId: {
            'summary': page.summary ?? '',
            'messages': jsonMessages,
          },
        },
      });
    }

    return {
      'schemaVersion': 1,
      'nextMessageId': maxMessageId + 1,
      'pages': pageEntries,
    };
  }

  Future<void> addBook(String filePath) {
    return addBookWithDuplicateOption(filePath).then((_) {});
  }

  Future<Book> addBookWithDuplicateOption(
    String filePath, {
    bool allowDuplicate = false,
  }) async {
    final source = File(filePath);
    if (!await source.exists()) throw Exception('File not found');

    late final String hash;
    late final String managedDpdfPath;
    late final String title;
    late final DpdfDocument parsedDpdf;

    if (isDpdfPath(filePath)) {
      parsedDpdf = await readDpdf(filePath);
      hash = sha256.convert(parsedDpdf.pdfBytes).toString();
      title = p.basenameWithoutExtension(filePath);

      final duplicate = _box
          .query(Book_.fileHash.equals(hash))
          .build()
          .findFirst();
      if (duplicate != null && !allowDuplicate) {
        throw DuplicateBookException(duplicate);
      }
      final isDuplicateImport = duplicate != null;
      managedDpdfPath = isDuplicateImport
          ? await _managedDpdfPathForHash(
              hash,
              suffix: 'copy-${DateTime.now().microsecondsSinceEpoch}',
            )
          : await _managedDpdfPathForHash(hash);

      if (!await File(managedDpdfPath).exists()) {
        await writeDpdf(
          managedDpdfPath,
          pdfBytes: parsedDpdf.pdfBytes,
          aiData: parsedDpdf.aiData,
          previousManifest: parsedDpdf.manifest,
        );
      }
    } else {
      final digest = await source.openRead().transform(sha256).first;
      hash = digest.toString();
      title = p.basenameWithoutExtension(filePath);

      final duplicate = _box
          .query(Book_.fileHash.equals(hash))
          .build()
          .findFirst();
      if (duplicate != null && !allowDuplicate) {
        throw DuplicateBookException(duplicate);
      }
      final isDuplicateImport = duplicate != null;
      managedDpdfPath = isDuplicateImport
          ? await _managedDpdfPathForHash(
              hash,
              suffix: 'copy-${DateTime.now().microsecondsSinceEpoch}',
            )
          : await _managedDpdfPathForHash(hash);

      if (!await File(managedDpdfPath).exists()) {
        await createDpdfFromPdf(
          sourcePdfPath: filePath,
          targetDpdfPath: managedDpdfPath,
          aiData: defaultAiData(),
        );
      }
    }

    final cachePdfPath = await _cachePdfPathForHash(hash);
    final cacheFile = File(cachePdfPath);
    if (!await cacheFile.exists()) {
      final pdfBytes = await extractPdfBytes(managedDpdfPath);
      await cacheFile.writeAsBytes(pdfBytes, flush: true);
    }

    try {
      final doc = await PdfDocument.openFile(cachePdfPath);
      final totalPages = doc.pages.length;

      final book = Book(
        filePath: managedDpdfPath,
        title: title,
        fileHash: hash,
        totalPages: totalPages,
      );

      final bookId = _box.put(book);
      book.id = bookId;
      _generateCover(book, doc);
      await doc.dispose();
      return book;
    } catch (e) {
      if (kDebugMode) {
        print('Error opening PDF: $e');
      }
      rethrow;
    }
  }

  Future<void> migrateLegacyBooksToDpdf() async {
    final books = _box.getAll();
    for (final book in books) {
      if (isDpdfPath(book.filePath)) continue;

      final sourceFile = File(book.filePath);
      if (!await sourceFile.exists()) continue;

      final digest = await sourceFile.openRead().transform(sha256).first;
      final hash = digest.toString();
      final managedPath = await _managedDpdfPathForHash(hash);

      if (!await File(managedPath).exists()) {
        final aiData = _buildLegacyAiDataFromObjectBox(book.id);
        await createDpdfFromPdf(
          sourcePdfPath: book.filePath,
          targetDpdfPath: managedPath,
          aiData: aiData,
        );
      }

      book.filePath = managedPath;
      book.fileHash = hash;
      _box.put(book);

      final cachePath = await _cachePdfPathForHash(hash);
      if (!await File(cachePath).exists()) {
        final pdfBytes = await extractPdfBytes(managedPath);
        await File(cachePath).writeAsBytes(pdfBytes, flush: true);
      }
    }
  }

  Future<void> _generateCover(Book book, PdfDocument doc) async {
    try {
      if (doc.pages.isEmpty) return;
      final page = doc.pages[0];

      final image = await page.render(
        width: 300,
        height: (300 * page.height / page.width).round(),
      );

      if (image != null) {
        final appDir = await getApplicationSupportDirectory();
        final coversDir = Directory(p.join(appDir.path, 'covers'));
        if (!await coversDir.exists()) {
          await coversDir.create(recursive: true);
        }

        final coverPath = p.join(coversDir.path, '${book.fileHash}.png');
        final file = File(coverPath);
        final uiImage = await image.createImage();
        final byteData = await uiImage.toByteData(
          format: ui.ImageByteFormat.png,
        );

        if (byteData != null) {
          await file.writeAsBytes(byteData.buffer.asUint8List());
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

  Future<void> exportBookFile(
    int bookId,
    String targetPath, {
    required String format,
  }) async {
    final book = _box.get(bookId);
    if (book == null) throw Exception('Book not found');
    if (!isDpdfPath(book.filePath)) throw Exception('Book source is not DPDF');

    final normalizedFormat = format.toLowerCase();
    if (normalizedFormat == 'pdf') {
      final normalized = p.extension(targetPath).toLowerCase() == '.pdf'
          ? targetPath
          : '$targetPath.pdf';
      final pdfBytes = await extractPdfBytes(book.filePath);
      await File(normalized).writeAsBytes(pdfBytes, flush: true);
      return;
    }

    final normalized = p.extension(targetPath).toLowerCase() == '.dpdf'
        ? targetPath
        : '$targetPath.dpdf';
    await File(book.filePath).copy(normalized);
  }

  Future<void> deleteBook(int id) async {
    final book = _box.get(id);
    if (book == null) return;

    _box.remove(id);

    try {
      final file = File(book.filePath);
      if (await file.exists() && isDpdfPath(book.filePath)) {
        await file.delete();
      }
    } catch (_) {}

    try {
      final cachePath = await _cachePdfPathForHash(book.fileHash);
      final cacheFile = File(cachePath);
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
    } catch (_) {}

    try {
      if (book.coverPath != null && book.coverPath!.isNotEmpty) {
        final cover = File(book.coverPath!);
        if (await cover.exists()) {
          await cover.delete();
        }
      }
    } catch (_) {}
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
