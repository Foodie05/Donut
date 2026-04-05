import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import '../data/repositories/book_repository.dart';
import '../data/repositories/page_repository.dart';
import '../data/models/chat_message.dart' as db;

class PdfValidationResult {
  const PdfValidationResult({
    required this.isValid,
    required this.reasonCode,
    required this.isEncrypted,
    required this.isCorrupted,
    required this.garbleScore,
  });

  final bool isValid;
  final String reasonCode;
  final bool isEncrypted;
  final bool isCorrupted;
  final double garbleScore;

  bool get shouldUseExceptionFallback => !isValid;

  Map<String, Object> toJson() {
    return {
      'isValid': isValid,
      'reasonCode': reasonCode,
      'isEncrypted': isEncrypted,
      'isCorrupted': isCorrupted,
      'garbleScore': garbleScore,
      'shouldUseExceptionFallback': shouldUseExceptionFallback,
    };
  }
}

class PdfValidityChecker {
  const PdfValidityChecker({
    this.maxAllowedGarbleScore = 0.45,
    this.maxNativePdfBytes = 8 * 1024 * 1024,
  });

  final double maxAllowedGarbleScore;
  final int maxNativePdfBytes;

  PdfValidationResult validate(Uint8List bytes) {
    if (bytes.isEmpty) {
      return const PdfValidationResult(
        isValid: false,
        reasonCode: 'empty_pdf',
        isEncrypted: false,
        isCorrupted: true,
        garbleScore: 1.0,
      );
    }

    if (bytes.length > maxNativePdfBytes) {
      return PdfValidationResult(
        isValid: false,
        reasonCode: 'pdf_too_large_for_native_injection',
        isEncrypted: false,
        isCorrupted: false,
        garbleScore: 0.0,
      );
    }

    final ascii = String.fromCharCodes(bytes, 0, bytes.length);

    final hasPdfHeader = ascii.startsWith('%PDF-');
    final hasEof = ascii.contains('%%EOF');
    final hasStartXref = ascii.contains('startxref');
    final isEncrypted = ascii.contains('/Encrypt');

    final garbleScore = _estimateGarbleScore(bytes);
    final isCorrupted = !hasPdfHeader || !hasEof || !hasStartXref;

    if (isEncrypted) {
      return PdfValidationResult(
        isValid: false,
        reasonCode: 'encrypted_pdf',
        isEncrypted: true,
        isCorrupted: isCorrupted,
        garbleScore: garbleScore,
      );
    }

    if (isCorrupted) {
      return PdfValidationResult(
        isValid: false,
        reasonCode: 'invalid_pdf_structure',
        isEncrypted: false,
        isCorrupted: true,
        garbleScore: garbleScore,
      );
    }

    if (garbleScore > maxAllowedGarbleScore) {
      return PdfValidationResult(
        isValid: false,
        reasonCode: 'garbled_pdf_content',
        isEncrypted: false,
        isCorrupted: false,
        garbleScore: garbleScore,
      );
    }

    return PdfValidationResult(
      isValid: true,
      reasonCode: 'ok',
      isEncrypted: false,
      isCorrupted: false,
      garbleScore: garbleScore,
    );
  }

  double _estimateGarbleScore(Uint8List bytes) {
    var suspicious = 0;
    var considered = 0;

    for (final b in bytes) {
      final isCommonTextByte =
          (b >= 0x20 && b <= 0x7E) || b == 0x0A || b == 0x0D || b == 0x09;
      final isLikelyBinaryNoise = b == 0x00 || b == 0xFF;

      if (isCommonTextByte || isLikelyBinaryNoise) {
        considered += 1;
        if (isLikelyBinaryNoise) {
          suspicious += 1;
        }
      }
    }

    if (considered == 0) return 1.0;
    return suspicious / considered;
  }
}

class _ConversationEvidenceState {
  final Set<String> activeEvidenceIds = <String>{};
  final Set<String> readEvidenceIds = <String>{};
}

class _CachedPdf {
  const _CachedPdf({
    required this.path,
    required this.lastModifiedMillis,
    required this.bytes,
    required this.base64,
  });

  final String path;
  final int lastModifiedMillis;
  final Uint8List bytes;
  final String base64;
}

class PdfContextEnvelope {
  const PdfContextEnvelope({
    required this.messages,
    required this.stablePrefixHash,
    required this.validation,
    required this.usedExceptionFallback,
  });

  final List<Map<String, dynamic>> messages;
  final String stablePrefixHash;
  final PdfValidationResult validation;
  final bool usedExceptionFallback;
}

class PdfContextService {
  PdfContextService({
    required BookRepository bookRepository,
    required PageRepository pageRepository,
  }) : _bookRepository = bookRepository,
       _pageRepository = pageRepository;

  final BookRepository _bookRepository;
  final PageRepository _pageRepository;

  static const String _systemPromptVersion = 'pdf_native_v1';
  static const String _toolSchemaVersion = 'donut_pdf_ctx_v1';
  static const int _nativePageRenderWidth = 1240;
  static const int _nativePageMaxRenderHeight = 1800;
  static const int _nativeDocumentPageNumber = 1;

  static final Map<int, _CachedPdf> _pdfCache = <int, _CachedPdf>{};
  static final Map<String, _ConversationEvidenceState> _conversationStates =
      <String, _ConversationEvidenceState>{};

  final PdfValidityChecker _checker = const PdfValidityChecker();

  Future<PdfContextEnvelope> buildChatEnvelope({
    required int bookId,
    required int pageIndex,
    required String profileId,
    required String latestUserQuery,
    required List<db.ChatMessage> history,
    required bool enablePseudoKbMode,
    required String? locale,
  }) async {
    final payload = await _loadPdfPayload(bookId: bookId);
    final validation = _checker.validate(payload.bytes);
    if (!validation.isValid) {
      return PdfContextEnvelope(
        messages: const <Map<String, dynamic>>[],
        stablePrefixHash: '',
        validation: validation,
        usedExceptionFallback: true,
      );
    }

    final conversationKey = '$bookId|$profileId';
    final evidenceState = _conversationStates.putIfAbsent(
      conversationKey,
      _ConversationEvidenceState.new,
    );

    final evidenceRefs = _collectEvidenceRefs(
      bookId: bookId,
      pageIndex: pageIndex,
      profileId: profileId,
      enablePseudoKbMode: enablePseudoKbMode,
      docId: 'book:$bookId',
      docSha256: payload.docSha256,
    );

    final currentEvidenceIds = evidenceRefs
        .map((item) => item['evidence_id']!.toString())
        .toSet();

    final addedEvidenceIds =
        currentEvidenceIds
            .where((id) => !evidenceState.activeEvidenceIds.contains(id))
            .toList()
          ..sort();

    final readDeltaIds =
        currentEvidenceIds
            .where((id) => !evidenceState.readEvidenceIds.contains(id))
            .toList()
          ..sort();

    final stablePrefix = {
      'system_prompt_version': _systemPromptVersion,
      'tool_schema_version': _toolSchemaVersion,
      'document_meta': {
        'doc_id': 'book:$bookId',
        'doc_sha256': payload.docSha256,
      },
      'stable_evidence_ids': evidenceState.activeEvidenceIds.toList()..sort(),
      'stable_evidence_refs': evidenceRefs,
      'pseudo_kb_mode': enablePseudoKbMode,
    };

    final volatileSuffix = {
      'latest_user_query': latestUserQuery,
      'pool_delta': {
        'added_evidence_ids': addedEvidenceIds,
        'removed_evidence_ids': const <String>[],
      },
      'read_log_delta': {'read_evidence_ids': readDeltaIds},
      'turn_state': {
        'focus_pages': _focusPages(
          pageIndex: pageIndex,
          enablePseudoKbMode: enablePseudoKbMode,
        ),
        if (locale != null && locale.isNotEmpty) 'locale': locale,
      },
    };

    final stablePrefixCanonical = _canonicalJson(stablePrefix);
    final stablePrefixHash = sha256
        .convert(utf8.encode(stablePrefixCanonical))
        .toString();

    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            'You are a helpful AI assistant for a PDF reader. The first user message is stable context. Use stable evidence IDs for citation and prefer cited pages.',
      },
      {
        'role': 'user',
        'content': <Map<String, dynamic>>[
          {
            'type': 'text',
            'text':
                '[DONUT_STABLE_PREFIX_HASH]\n$stablePrefixHash\n\n[DONUT_STABLE_PREFIX_JSON]\n$stablePrefixCanonical',
          },
          {
            'type': 'document',
            'mime_type': 'application/pdf',
            'doc_id': 'book:$bookId',
            'doc_sha256': payload.docSha256,
            'page_range': {
              'start': _nativeDocumentPageNumber,
              'end': _nativeDocumentPageNumber,
            },
            'data_base64': payload.base64,
          },
        ],
      },
      ...history.map((msg) {
        return {'role': msg.isUser ? 'user' : 'assistant', 'content': msg.text};
      }),
      {
        'role': 'user',
        'content': [
          {
            'type': 'text',
            'text':
                '[DONUT_VOLATILE_SUFFIX_JSON]\n${_canonicalJson(volatileSuffix)}\n\n[USER_QUERY]\n$latestUserQuery',
          },
        ],
      },
    ];

    evidenceState.activeEvidenceIds.addAll(currentEvidenceIds);
    evidenceState.readEvidenceIds.addAll(readDeltaIds);

    return PdfContextEnvelope(
      messages: messages,
      stablePrefixHash: stablePrefixHash,
      validation: validation,
      usedExceptionFallback: false,
    );
  }

  Future<PdfContextEnvelope> buildSummaryEnvelope({
    required int bookId,
    required int pageIndex,
    required String profileId,
    required String summaryPrompt,
    required bool enablePseudoKbMode,
    required String? locale,
  }) {
    return buildChatEnvelope(
      bookId: bookId,
      pageIndex: pageIndex,
      profileId: profileId,
      latestUserQuery: summaryPrompt,
      history: const <db.ChatMessage>[],
      enablePseudoKbMode: enablePseudoKbMode,
      locale: locale,
    );
  }

  Future<({Uint8List bytes, String base64, String docSha256})> _loadPdfPayload({
    required int bookId,
  }) async {
    final book = _bookRepository.getBook(bookId);
    if (book == null) {
      throw StateError('book_not_found:$bookId');
    }

    final readablePath = await _bookRepository.ensureReadablePdfPath(book);
    final file = File(readablePath);
    final stat = await file.stat();

    final cached = _pdfCache[bookId];
    if (cached != null &&
        cached.path == readablePath &&
        cached.lastModifiedMillis == stat.modified.millisecondsSinceEpoch) {
      return (
        bytes: cached.bytes,
        base64: cached.base64,
        docSha256: book.fileHash,
      );
    }

    final bytes = await _buildSinglePagePdfBytes(
      sourcePdfPath: readablePath,
      pageNumber: _nativeDocumentPageNumber,
    );
    final base64 = base64Encode(bytes);
    _pdfCache[bookId] = _CachedPdf(
      path: readablePath,
      lastModifiedMillis: stat.modified.millisecondsSinceEpoch,
      bytes: bytes,
      base64: base64,
    );

    return (bytes: bytes, base64: base64, docSha256: book.fileHash);
  }

  Future<Uint8List> _buildSinglePagePdfBytes({
    required String sourcePdfPath,
    required int pageNumber,
  }) async {
    final document = await pdfrx.PdfDocument.openFile(sourcePdfPath);
    try {
      if (document.pages.isEmpty) {
        throw StateError('pdf_has_no_pages');
      }
      final resolvedPageNumber = pageNumber.clamp(1, document.pages.length);
      final page = document.pages[resolvedPageNumber - 1];

      var renderWidth = _nativePageRenderWidth;
      var renderHeight = (renderWidth * page.height / page.width).round();
      if (renderHeight > _nativePageMaxRenderHeight) {
        final scale = _nativePageMaxRenderHeight / renderHeight;
        renderHeight = _nativePageMaxRenderHeight;
        renderWidth = (renderWidth * scale).round();
      }

      final image = await page.render(
        width: renderWidth,
        height: renderHeight,
        backgroundColor: 0xFFFFFFFF,
      );
      if (image == null) {
        throw StateError('pdf_page_render_failed');
      }
      try {
        final uiImage = await image.createImage();
        try {
          final byteData = await uiImage.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (byteData == null) {
            throw StateError('pdf_page_png_encode_failed');
          }
          final pagePngBytes = byteData.buffer.asUint8List();

          final onePagePdf = pw.Document();
          final pageImage = pw.MemoryImage(pagePngBytes);
          onePagePdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(page.width, page.height),
              margin: pw.EdgeInsets.zero,
              build: (_) {
                return pw.Image(pageImage, fit: pw.BoxFit.contain);
              },
            ),
          );
          return Uint8List.fromList(await onePagePdf.save());
        } finally {
          uiImage.dispose();
        }
      } finally {
        image.dispose();
      }
    } finally {
      await document.dispose();
    }
  }

  List<int> _focusPages({
    required int pageIndex,
    required bool enablePseudoKbMode,
  }) {
    final pages = <int>[];
    if (enablePseudoKbMode) {
      if (pageIndex > 2) pages.add(pageIndex - 2);
      if (pageIndex > 1) pages.add(pageIndex - 1);
    }
    pages.add(pageIndex);
    return pages;
  }

  List<Map<String, Object>> _collectEvidenceRefs({
    required int bookId,
    required int pageIndex,
    required String profileId,
    required bool enablePseudoKbMode,
    required String docId,
    required String docSha256,
  }) {
    final pages = _focusPages(
      pageIndex: pageIndex,
      enablePseudoKbMode: enablePseudoKbMode,
    );

    final refs = <Map<String, Object>>[];
    for (final page in pages) {
      final summary =
          _pageRepository.getPageData(bookId, page, profileId)?.summary ?? '';
      final normalized = summary.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (normalized.isEmpty) continue;
      final spanHash = sha1.convert(utf8.encode(normalized)).toString();
      refs.add({
        'evidence_id': 'ev:$docSha256:$page:$spanHash',
        'doc_id': docId,
        'doc_sha256': docSha256,
        'page': page,
        'span_start': 0,
        'span_end': normalized.length,
      });
    }

    refs.sort((a, b) {
      final docCompare = a['doc_id'].toString().compareTo(
        b['doc_id'].toString(),
      );
      if (docCompare != 0) return docCompare;
      final pageCompare = (a['page'] as int).compareTo(b['page'] as int);
      if (pageCompare != 0) return pageCompare;
      final startCompare = (a['span_start'] as int).compareTo(
        b['span_start'] as int,
      );
      if (startCompare != 0) return startCompare;
      return a['evidence_id'].toString().compareTo(b['evidence_id'].toString());
    });

    return refs;
  }

  String _canonicalJson(Map<String, Object?> input) {
    final canonical = _canonicalize(input);
    return jsonEncode(canonical);
  }

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in value.entries) {
        sorted[entry.key.toString()] = _canonicalize(entry.value);
      }
      return sorted;
    }
    if (value is List) {
      return value.map(_canonicalize).toList(growable: false);
    }
    return value;
  }
}
