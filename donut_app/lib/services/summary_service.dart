import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/repositories/page_repository.dart';
import 'ai_service.dart';
import 'debug_log_service.dart';
import 'settings_service.dart';

part 'summary_service.g.dart';

@riverpod
SummaryGenerationService summaryGenerationService(Ref ref) {
  return SummaryGenerationService(ref);
}

class SummaryGenerationService {
  static const int _targetRenderWidth = 2000;
  static const int _maxRenderHeight = 3200;

  final Ref _ref;
  final Map<String, Future<void>> _pendingRequests = {};
  final Map<String, String> _lastErrors = {};

  SummaryGenerationService(this._ref);

  Future<void> ensureSummary(
    int bookId,
    int pageIndex,
    String profileId,
    PdfDocument doc, {
    String? locale,
    bool force = false,
  }) async {
    final key = '${bookId}_${pageIndex}_$profileId';

    final pageRepo = _ref.read(pageRepositoryProvider);
    final existingData = pageRepo.getPageData(bookId, pageIndex, profileId);
    if (existingData?.summary != null && existingData!.summary!.isNotEmpty) {
      unawaited(
        DebugLogService.debug(
          source: 'SUMMARY_PIPELINE',
          message: 'Skipped summary generation because summary already exists.',
          context: {
            'bookId': bookId,
            'pageIndex': pageIndex,
            'profileId': profileId,
            'summaryLength': existingData.summary!.length,
          },
        ),
      );
      return;
    }

    if (_pendingRequests.containsKey(key)) {
      unawaited(
        DebugLogService.debug(
          source: 'SUMMARY_PIPELINE',
          message: 'Reused pending summary generation request.',
          context: {
            'bookId': bookId,
            'pageIndex': pageIndex,
            'profileId': profileId,
          },
        ),
      );
      return _pendingRequests[key];
    }

    unawaited(
      DebugLogService.info(
        source: 'SUMMARY_PIPELINE',
        message: 'Queued summary generation request.',
        context: {
          'bookId': bookId,
          'pageIndex': pageIndex,
          'profileId': profileId,
          'locale': locale,
          'pageCount': doc.pages.length,
        },
      ),
    );
    final future = _generateSummary(
      bookId,
      pageIndex,
      profileId,
      doc,
      locale: locale,
      force: force,
    );
    _pendingRequests[key] = future;

    try {
      await future;
    } finally {
      _pendingRequests.remove(key);
    }
  }

  bool isSummaryPending(int bookId, int pageIndex, String profileId) {
    return _pendingRequests.containsKey('${bookId}_${pageIndex}_$profileId');
  }

  String? lastError(int bookId, int pageIndex, String profileId) {
    return _lastErrors['${bookId}_${pageIndex}_$profileId'];
  }

  Future<void> _generateSummary(
    int bookId,
    int pageIndex,
    String profileId,
    PdfDocument doc, {
    String? locale,
    bool force = false,
  }) async {
    final settings = _ref.read(settingsProvider);
    if (!force && !settings.autoGenerate) {
      await DebugLogService.debug(
        source: 'SUMMARY_PIPELINE',
        message: 'Skipped summary generation because auto-generate is off.',
        context: {
          'bookId': bookId,
          'pageIndex': pageIndex,
          'profileId': profileId,
          'force': force,
        },
      );
      return;
    }

    final profile = settings.profileById(profileId);
    final key = '${bookId}_${pageIndex}_$profileId';

    try {
      var prompt = profile.prompt;
      if (settings.enablePseudoKBMode) {
        prompt +=
            ' If multiple images are present, prioritize current page and use previous pages only as context.';
      }

      await DebugLogService.info(
        source: 'SUMMARY_PIPELINE',
        message: 'Dispatching image-based summary request to AI service.',
        context: {
          'bookId': bookId,
          'pageIndex': pageIndex,
          'profileId': profileId,
          'enablePseudoKbMode': settings.enablePseudoKBMode,
        },
      );

      await _generateSummaryWithImageFallback(
        bookId,
        pageIndex,
        profileId,
        doc,
        locale: locale,
        prompt: prompt,
        includeContextPages: settings.enablePseudoKBMode,
      );

      _lastErrors.remove(key);
    } catch (e, stackTrace) {
      _lastErrors[key] = e.toString();
      await DebugLogService.error(
        source: 'SUMMARY_PIPELINE',
        message: 'Summary generation failed.',
        error: e,
        stackTrace: stackTrace,
        context: {
          'bookId': bookId,
          'pageIndex': pageIndex,
          'profileId': profileId,
          'profileName': profile.name,
        },
      );
      if (kDebugMode) {
        print('Background summary generation failed: $e');
      }
      rethrow;
    }
  }

  Future<void> _generateSummaryWithImageFallback(
    int bookId,
    int pageIndex,
    String profileId,
    PdfDocument doc, {
    required String prompt,
    String? locale,
    bool includeContextPages = false,
  }) async {
    final aiService = _ref.read(aiServiceProvider);
    final pageRepo = _ref.read(pageRepositoryProvider);

    final renderedImages = <Uint8List>[];
    final renderSummaries = <Map<String, dynamic>>[];

    final pagesToRender = <int>[
      if (includeContextPages && pageIndex > 2) pageIndex - 2,
      if (includeContextPages && pageIndex > 1) pageIndex - 1,
      pageIndex,
    ];

    for (final currentPageIndex in pagesToRender) {
      final page = doc.pages[currentPageIndex - 1];
      var renderWidth = _targetRenderWidth;
      var renderHeight = (renderWidth * page.height / page.width).round();
      if (renderHeight > _maxRenderHeight) {
        final scale = _maxRenderHeight / renderHeight;
        renderHeight = _maxRenderHeight;
        renderWidth = (renderWidth * scale).round();
      }

      final image = await page.render(
        width: renderWidth,
        height: renderHeight,
        backgroundColor: 0xFFFFFFFF,
      );

      if (image == null) {
        continue;
      }

      final uiImage = await image.createImage();
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        continue;
      }

      final bytes = byteData.buffer.asUint8List();
      renderedImages.add(bytes);
      renderSummaries.add({
        'pageIndex': currentPageIndex,
        'width': renderWidth,
        'height': renderHeight,
        'bytes': bytes.length,
      });
    }

    await DebugLogService.debug(
      source: 'SUMMARY_PIPELINE',
      message: 'Rendered image fallback content for summary generation.',
      context: {
        'bookId': bookId,
        'pageIndex': pageIndex,
        'profileId': profileId,
        'renderedImageCount': renderedImages.length,
        'renderSummaries': renderSummaries,
        'includeContextPages': includeContextPages,
      },
    );

    if (renderedImages.isEmpty) {
      throw StateError('summary_fallback_no_rendered_image');
    }

    final pageId = pageRepo.savePageSummary(
      bookId,
      pageIndex,
      profileId,
      '',
      null,
    );

    final sb = StringBuffer();
    final stream = aiService.analyzeImageStream(
      renderedImages.map(AiImageInput.bytes).toList(),
      prompt,
      locale: locale,
    );

    await for (final chunk in stream) {
      sb.write(chunk);
      pageRepo.updatePageSummaryDirectly(pageId, sb.toString());
    }

    await DebugLogService.info(
      source: 'SUMMARY_PIPELINE',
      message: 'Summary generation completed via image fallback.',
      context: {
        'bookId': bookId,
        'pageIndex': pageIndex,
        'profileId': profileId,
        'summaryLength': sb.length,
      },
    );
  }
}
