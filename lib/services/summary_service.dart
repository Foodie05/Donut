import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/repositories/page_repository.dart';
import 'ai_service.dart';
import 'settings_service.dart';

part 'summary_service.g.dart';

@riverpod
SummaryGenerationService summaryGenerationService(Ref ref) {
  return SummaryGenerationService(ref);
}

class SummaryGenerationService {
  final Ref _ref;
  // Track in-flight requests: bookId_pageIndex_profileId -> Future
  final Map<String, Future<void>> _pendingRequests = {};

  SummaryGenerationService(this._ref);

  Future<void> ensureSummary(
    int bookId,
    int pageIndex,
    String profileId,
    PdfDocument doc, {
    String? locale,
  }) async {
    final key = '${bookId}_${pageIndex}_$profileId';
    
    // 1. Check DB
    final pageRepo = _ref.read(pageRepositoryProvider);
    final existingData = pageRepo.getPageData(bookId, pageIndex, profileId);
    if (existingData?.summary != null && existingData!.summary!.isNotEmpty) {
      return;
    }

    // 2. Check pending
    if (_pendingRequests.containsKey(key)) {
      return _pendingRequests[key];
    }

    // 3. Start Request
    final future = _generateSummary(bookId, pageIndex, profileId, doc, locale: locale);
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

  Future<void> _generateSummary(
    int bookId,
    int pageIndex,
    String profileId,
    PdfDocument doc, {
    String? locale,
  }) async {
    final settings = _ref.read(settingsProvider);
    if (!settings.autoGenerate) return;
    final profile = settings.profileById(profileId);

    final aiService = _ref.read(aiServiceProvider);
    final pageRepo = _ref.read(pageRepositoryProvider);

    try {
      // Collect pages to render
      final pagesToRender = <int>[];
      // User request: Summary generation should ONLY use the current page, regardless of settings.
      // Enhanced context is only for Chat.
      /* 
      if (settings.enablePseudoKBMode) {
        if (pageIndex > 2) pagesToRender.add(pageIndex - 2);
        if (pageIndex > 1) pagesToRender.add(pageIndex - 1);
      }
      */
      pagesToRender.add(pageIndex);

      // Render images
      final base64Images = <String>[];
      for (final pNum in pagesToRender) {
        if (pNum > 0 && pNum <= doc.pages.length) {
          final page = doc.pages[pNum - 1];
          // Use smaller scale/size for context pages if needed, but for simplicity use consistent size
          // Compress logic: Use jpeg with 80% quality or resize
          final image = await page.render(
            width: 768, // Reasonable width for AI analysis
            height: (768 * page.height / page.width).round(),
            backgroundColor: 0xFFFFFFFF,
          );
          
          if (image != null) {
            final uiImage = await image.createImage();
            final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              base64Images.add(base64Encode(byteData.buffer.asUint8List()));
            }
          }
        }
      }

      if (base64Images.isEmpty) return;

      // Initialize PageData to get ID for streaming updates
      // This ensures we have a valid ID to update incrementally
      int pageId = pageRepo.savePageSummary(bookId, pageIndex, profileId, "", null);

      // Call AI Service
      final sb = StringBuffer();
      String prompt = profile.prompt;
      if (settings.enablePseudoKBMode && base64Images.length > 1) {
        prompt += " Context from previous pages is included. Please analyze comprehensively.";
      }

      final stream = aiService.analyzeImageStream(base64Images, prompt, locale: locale);
      
      await for (final chunk in stream) {
        sb.write(chunk);
        // Streaming update to DB
        // We update directly by ID which is faster and triggers watchers
        pageRepo.updatePageSummaryDirectly(pageId, sb.toString());
      }

    } catch (e) {
      if (kDebugMode) {
        print('Background summary generation failed: $e');
      }
      // Optionally save error state to DB to avoid infinite retries
    }
  }
}
