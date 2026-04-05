import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/chat_message.dart' as db;
import 'auth_service.dart';
import 'client_config_service.dart';
import 'debug_log_service.dart';
import 'openai_compatible_api.dart';
import 'settings_service.dart';
import 'temporary_asset_service.dart';

part 'ai_service.g.dart';

@riverpod
AiService aiService(Ref ref) {
  final settings = ref.watch(settingsProvider);
  final auth = ref.watch(authControllerProvider);
  final clientConfigAsync = ref.watch(clientConfigProvider);
  final clientConfig = clientConfigAsync is AsyncData<ClientConfigSummary>
      ? clientConfigAsync.value
      : null;
  return AiService(
    settings.apiKey,
    settings.baseUrl,
    settings.modelName,
    settings.selectedServerModelName,
    settings.useCustomModelConfig,
    settings.modelReplyLength,
    sessionToken: auth.sessionToken,
    apiToken: auth.apiToken,
    refreshServerApiToken: () async {
      await ref.read(authControllerProvider.notifier).refreshSession();
      return ref.read(authControllerProvider).apiToken;
    },
    refreshSessionSnapshot: () async {
      await ref.read(authControllerProvider.notifier).refreshSession();
    },
    temporaryAssetUploadEnabled:
        clientConfig?.temporaryAssetUploadEnabled ?? false,
  );
}

class AiService {
  AiService(
    this.apiKey,
    this.baseUrl,
    this.customModelName,
    this.selectedServerModelName,
    this.useCustomModelConfig,
    this.modelReplyLength, {
    this.sessionToken,
    this.apiToken,
    this.refreshServerApiToken,
    this.refreshSessionSnapshot,
    this.temporaryAssetUploadEnabled = false,
  }) : _dio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 20),
           receiveTimeout: const Duration(seconds: 90),
           validateStatus: (_) => true,
         ),
       ) {
    final useServerConfig = !useCustomModelConfig;
    _effectiveApiKey = useServerConfig
        ? (apiToken != null && apiToken!.trim().isNotEmpty
              ? apiToken!.trim()
              : '')
        : apiKey.trim();
    _effectiveBaseUrl = useServerConfig
        ? defaultGatewayBaseUrl
        : baseUrl.trim();
    _effectiveModelName = useServerConfig
        ? (selectedServerModelName.isNotEmpty
              ? selectedServerModelName
              : defaultGatewayModelName)
        : (customModelName.isNotEmpty
              ? customModelName
              : defaultGatewayModelName);
  }

  final String apiKey;
  final String baseUrl;
  final String customModelName;
  final String selectedServerModelName;
  final bool useCustomModelConfig;
  final ModelReplyLength modelReplyLength;
  final String? sessionToken;
  final String? apiToken;
  final Future<String?> Function()? refreshServerApiToken;
  final Future<void> Function()? refreshSessionSnapshot;
  final bool temporaryAssetUploadEnabled;
  final Dio _dio;

  late String _effectiveApiKey;
  late final String _effectiveBaseUrl;
  late final String _effectiveModelName;

  static const _defaultImageContentType = 'image/png';

  Stream<String> analyzeImageStream(
    List<AiImageInput> images,
    String prompt, {
    String? locale,
  }) async* {
    _ensureAvailable();
    await DebugLogService.info(
      source: 'AI_SUMMARY',
      message: 'Starting summary completion request.',
      context: {
        'mode': useCustomModelConfig ? 'custom' : 'server',
        'model': _effectiveModelName,
        'baseHost': OpenAiCompatibleApi.safeBaseHost(_effectiveBaseUrl),
        'imageCount': images.length,
        'promptLength': prompt.length,
        'maxTokens': modelReplyLength.maxTokens,
      },
    );

    String finalPrompt = prompt;
    if (_looksLikeTranslationTask(prompt)) {
      finalPrompt = '${_strictTranslationInstruction()}\n\n$prompt';
    }
    if (locale != null && locale.isNotEmpty) {
      finalPrompt +=
          "\nIMPORTANT: Your response MUST be in the same language as the user's system interface. Current system language: $locale. Do not respond in English unless the system language is English.";
    }

    final prepared = await _prepareImageInputs(images);
    final contentParts = <Map<String, dynamic>>[
      {'type': 'text', 'text': finalPrompt},
      ...prepared.imageParts,
    ];

    final stream = _createCompletionStream(
      messages: [
        {'role': 'user', 'content': contentParts},
      ],
      tempObjectKeys: prepared.tempObjectKeys,
      temperature: 0.2,
      source: 'AI_SUMMARY',
      usageMode: 'summary',
    );
    yield* stream;
  }

  Stream<String> chatWithPage({
    required String prompt,
    required List<AiImageInput> images,
    String? summary,
    List<db.ChatMessage> history = const [],
    String? locale,
  }) async* {
    _ensureAvailable();
    await DebugLogService.info(
      source: 'AI_CHAT',
      message: 'Starting chat completion request.',
      context: {
        'mode': useCustomModelConfig ? 'custom' : 'server',
        'model': _effectiveModelName,
        'baseHost': OpenAiCompatibleApi.safeBaseHost(_effectiveBaseUrl),
        'imageCount': images.length,
        'historyCount': history.length,
        'hasSummary': summary != null && summary.isNotEmpty,
        'promptLength': prompt.length,
        'maxTokens': modelReplyLength.maxTokens,
      },
    );

    var systemPrompt =
        "You are a helpful AI assistant in a PDF Reader application. "
        "You have access to the current page image(s) and its summary. "
        "If multiple images are provided, they represent the previous pages for context (n-2, n-1, n). "
        "Answer the user's questions based on this context.";

    if (locale != null && locale.isNotEmpty) {
      systemPrompt +=
          " IMPORTANT: Your response MUST be in the same language as the user's system interface. Current system language: $locale. Do not respond in English unless the system language is English.";
    }

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final msg in history) {
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text,
      });
    }

    final prepared = await _prepareImageInputs(images);
    final contentParts = <Map<String, dynamic>>[
      if (summary != null && summary.isNotEmpty)
        {'type': 'text', 'text': 'Page Summary: $summary\n\n'},
      {'type': 'text', 'text': prompt},
      ...prepared.imageParts,
    ];

    messages.add({'role': 'user', 'content': contentParts});

    final stream = _createCompletionStream(
      messages: messages,
      tempObjectKeys: prepared.tempObjectKeys,
      temperature: 0.3,
      source: 'AI_CHAT',
      usageMode: 'chat',
    );
    yield* stream;
  }

  Stream<String> chatWithStructuredMessages({
    required List<Map<String, dynamic>> messages,
    required String source,
    required String usageMode,
    double temperature = 0.3,
  }) async* {
    _ensureAvailable();
    await DebugLogService.info(
      source: source,
      message: 'Starting structured chat completion request.',
      context: {
        'mode': useCustomModelConfig ? 'custom' : 'server',
        'model': _effectiveModelName,
        'baseHost': OpenAiCompatibleApi.safeBaseHost(_effectiveBaseUrl),
        'messageCount': messages.length,
        'maxTokens': modelReplyLength.maxTokens,
      },
    );

    yield* _createCompletionStream(
      messages: messages,
      tempObjectKeys: const <String>[],
      temperature: temperature,
      source: source,
      usageMode: usageMode,
    );
  }

  Stream<String> _createCompletionStream({
    required List<Map<String, dynamic>> messages,
    required List<String> tempObjectKeys,
    required double temperature,
    required String source,
    required String usageMode,
  }) async* {
    final payload = <String, dynamic>{
      'model': _effectiveModelName,
      'messages': messages,
      'temperature': temperature,
      'stream': true,
    };
    if (tempObjectKeys.isNotEmpty) {
      payload['donut_temp_objects'] = tempObjectKeys
          .map((key) => {'objectKey': key})
          .toList();
    }
    if (modelReplyLength.maxTokens != null) {
      payload['max_tokens'] = modelReplyLength.maxTokens;
    }

    final requestSummary = _requestSummary(messages, temperature);
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _postToCompatibleCompletionEndpoint(
          payload: payload,
          source: source,
          requestSummary: requestSummary,
          usageMode: usageMode,
        );

        yield* _consumeCompletionResponse(
          response: response,
          source: source,
          requestSummary: requestSummary,
        );
        await _refreshSessionSnapshotIfNeeded();
        return;
      } on AiServiceException catch (error) {
        if (attempt == 0 &&
            await _refreshServerApiTokenIfNeeded(
              source: source,
              reasonCode: error.code,
            )) {
          continue;
        }
        rethrow;
      } on DioException catch (error, stackTrace) {
        await DebugLogService.error(
          source: source,
          message: 'Completion request failed with DioException.',
          error: error,
          stackTrace: stackTrace,
          context: {
            'model': _effectiveModelName,
            'baseHost': OpenAiCompatibleApi.safeBaseHost(_effectiveBaseUrl),
            'request': requestSummary,
            'dioType': error.type.name,
            'responseStatusCode': error.response?.statusCode,
            'responseHeaders': error.response?.headers.map,
            'responseType': error.requestOptions.responseType.name,
            'rawBodyType': error.response?.data.runtimeType.toString(),
            'rawBodyPreview': _previewDynamic(error.response?.data),
          },
        );
        throw AiServiceException(_mapDioExceptionToCode(error));
      } catch (error, stackTrace) {
        await DebugLogService.error(
          source: source,
          message: 'Completion request failed unexpectedly.',
          error: error,
          stackTrace: stackTrace,
          context: {
            'model': _effectiveModelName,
            'baseHost': OpenAiCompatibleApi.safeBaseHost(_effectiveBaseUrl),
            'request': requestSummary,
          },
        );
        throw AiServiceException(_mapUnexpectedErrorToCode(error));
      }
    }
  }

  Stream<String> _consumeCompletionResponse({
    required Response<dynamic> response,
    required String source,
    required Map<String, dynamic> requestSummary,
  }) async* {
    final statusCode = response.statusCode;
    final contentType = response.headers.value(Headers.contentTypeHeader) ?? '';
    if (contentType.toLowerCase().contains('text/event-stream') &&
        response.data is ResponseBody) {
      if (statusCode == null || statusCode < 200 || statusCode >= 300) {
        await DebugLogService.warn(
          source: source,
          message: 'SSE completion request returned non-success status.',
          context: {
            'statusCode': statusCode,
            'contentType': contentType,
            'request': requestSummary,
          },
        );
        final normalizedData = await _normalizeResponseData(response.data);
        throw AiServiceException(
          _extractErrorCode(normalizedData) ?? 'unknown_error',
        );
      }
      yield* _consumeSseStream(
        responseBody: response.data as ResponseBody,
        source: source,
        requestSummary: requestSummary,
      );
      return;
    }

    final normalizedData = await _normalizeResponseData(response.data);
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      final responseBody = _asJsonMap(normalizedData);
      await DebugLogService.warn(
        source: source,
        message: 'Completion request returned non-success status.',
        context: {
          'statusCode': statusCode,
          'request': requestSummary,
          'responseKeys': responseBody.keys.toList(),
          'responseShape': _describeResponseStructure(normalizedData),
          'responsePreview': _previewDynamic(normalizedData),
        },
      );
      throw AiServiceException(
        _extractErrorCode(normalizedData) ?? 'unknown_error',
      );
    }

    final body = _asJsonMap(normalizedData);
    await DebugLogService.debug(
      source: source,
      message: 'Completion response received as non-stream payload.',
      context: {
        'statusCode': statusCode,
        'contentType': contentType,
        'request': requestSummary,
        'topLevelKeys': body.keys.toList(),
        'choicesCount': body['choices'] is List
            ? (body['choices'] as List).length
            : null,
        'choiceShape': _describeChoiceShape(body),
        'responseShape': _describeResponseStructure(normalizedData),
      },
    );
    final text = _extractAssistantText(body);
    if (text == null || text.trim().isEmpty) {
      await DebugLogService.warn(
        source: source,
        message: 'Completion response did not contain readable text.',
        context: {
          'request': requestSummary,
          'topLevelKeys': body.keys.toList(),
          'choiceShape': _describeChoiceShape(body),
          'responseShape': _describeResponseStructure(normalizedData),
        },
      );
      throw AiServiceException('unknown_error');
    }
    await DebugLogService.info(
      source: source,
      message: 'Completion parsed successfully from non-stream payload.',
      context: {'textLength': text.length, 'request': requestSummary},
    );
    yield text;
  }

  Stream<String> _consumeSseStream({
    required ResponseBody responseBody,
    required String source,
    required Map<String, dynamic> requestSummary,
  }) async* {
    await DebugLogService.debug(
      source: source,
      message: 'Consuming SSE completion stream.',
      context: {
        'request': requestSummary,
        'headers': responseBody.headers,
        'statusCode': responseBody.statusCode,
      },
    );

    var chunkCount = 0;
    var totalTextLength = 0;
    final eventDataLines = <String>[];

    Future<List<String>> flushEvent() async {
      if (eventDataLines.isEmpty) return const <String>[];
      final payload = eventDataLines.join('\n').trim();
      eventDataLines.clear();
      if (payload.isEmpty || payload == '[DONE]') {
        return const <String>[];
      }
      final decoded = jsonDecode(payload);
      final body = _asJsonMap(decoded);
      final text = _extractAssistantText(body);
      if (text == null || text.isEmpty) {
        return const <String>[];
      }
      return <String>[text];
    }

    final decodedLines = utf8.decoder
        .bind(responseBody.stream.map(Uint8List.fromList))
        .transform(const LineSplitter());
    await for (final line in decodedLines) {
      if (line.isEmpty) {
        final flushed = await flushEvent();
        for (final text in flushed) {
          chunkCount += 1;
          totalTextLength += text.length;
          yield text;
        }
        continue;
      }
      if (line.startsWith('data:')) {
        eventDataLines.add(line.substring(5).trimLeft());
      }
    }

    final trailing = await flushEvent();
    for (final text in trailing) {
      chunkCount += 1;
      totalTextLength += text.length;
      yield text;
    }

    await DebugLogService.info(
      source: source,
      message: 'SSE completion stream finished.',
      context: {
        'request': requestSummary,
        'chunkCount': chunkCount,
        'totalTextLength': totalTextLength,
      },
    );
  }

  Future<dynamic> _normalizeResponseData(dynamic data) async {
    if (data is! ResponseBody) {
      return data;
    }
    final bytes = await data.stream.expand((chunk) => chunk).toList();
    final decoded = utf8.decode(bytes, allowMalformed: true);
    try {
      return jsonDecode(decoded);
    } catch (_) {
      return decoded;
    }
  }

  Future<Response<dynamic>> _postToCompatibleCompletionEndpoint({
    required Map<String, dynamic> payload,
    required String source,
    required Map<String, dynamic> requestSummary,
    required String usageMode,
  }) async {
    final candidates = OpenAiCompatibleApi.completionUris(_effectiveBaseUrl);
    if (candidates.isEmpty) {
      throw const AiServiceException('invalid_config');
    }

    DioException? lastDioError;
    Response<dynamic>? lastResponse;

    for (var i = 0; i < candidates.length; i++) {
      final uri = candidates[i];
      try {
        await DebugLogService.debug(
          source: source,
          message: 'Sending completion request to OpenAI-compatible endpoint.',
          context: {
            'request': requestSummary,
            'resolvedUri': uri.toString(),
            'candidateIndex': i,
            'candidateCount': candidates.length,
          },
        );

        final response = await _dio.postUri(
          uri,
          data: payload,
          options: Options(
            responseType: ResponseType.stream,
            headers: {
              ...OpenAiCompatibleApi.headers(
                _effectiveApiKey,
                accept: 'text/event-stream, application/json',
              ),
              if (!useCustomModelConfig) 'X-Donut-Usage-Mode': usageMode,
            },
          ),
        );

        final isNotFound =
            response.statusCode == 404 || response.statusCode == 405;
        if (isNotFound && i < candidates.length - 1) {
          await DebugLogService.warn(
            source: source,
            message:
                'OpenAI-compatible endpoint candidate rejected request, trying next candidate.',
            context: {
              'request': requestSummary,
              'resolvedUri': uri.toString(),
              'statusCode': response.statusCode,
            },
          );
          lastResponse = response;
          continue;
        }
        return response;
      } on DioException catch (error) {
        lastDioError = error;
        if (i < candidates.length - 1) {
          await DebugLogService.warn(
            source: source,
            message:
                'OpenAI-compatible endpoint candidate failed, trying next candidate.',
            error: error,
            context: {
              'request': requestSummary,
              'resolvedUri': uri.toString(),
              'candidateIndex': i,
              'candidateCount': candidates.length,
            },
          );
          continue;
        }
        rethrow;
      }
    }

    if (lastDioError != null) throw lastDioError;
    if (lastResponse != null) return lastResponse;
    throw const AiServiceException('unknown_error');
  }

  Future<void> _refreshSessionSnapshotIfNeeded() async {
    if (useCustomModelConfig || sessionToken == null || sessionToken!.isEmpty) {
      return;
    }
    final callback = refreshSessionSnapshot;
    if (callback == null) return;
    try {
      await callback();
    } catch (_) {
      // Best effort refresh to keep quota display up to date.
    }
  }

  Future<({List<Map<String, dynamic>> imageParts, List<String> tempObjectKeys})>
  _prepareImageInputs(List<AiImageInput> images) async {
    if (images.isEmpty) {
      return (
        imageParts: const <Map<String, dynamic>>[],
        tempObjectKeys: const <String>[],
      );
    }
    final byteImages = images.where((image) => image.bytes != null).toList();
    if (!useCustomModelConfig &&
        temporaryAssetUploadEnabled &&
        apiToken != null &&
        apiToken!.isNotEmpty &&
        byteImages.isNotEmpty) {
      try {
        final uploads =
            await TemporaryAssetService(
              apiToken: apiToken!.trim(),
              refreshApiToken: () => _refreshServerApiTokenForUpload(),
            ).uploadImages(
              byteImages
                  .map(
                    (image) => (
                      bytes: image.bytes!,
                      contentType:
                          image.contentType ?? _defaultImageContentType,
                    ),
                  )
                  .toList(),
            );
        if (uploads.length == byteImages.length) {
          final uploadedParts = uploads
              .map(
                (upload) => {
                  'type': 'image_url',
                  'image_url': {
                    'url': upload.downloadUrl.toString(),
                    'detail': 'high',
                  },
                },
              )
              .toList();
          var uploadIndex = 0;
          return (
            imageParts: images.map((image) {
              if (image.url != null && image.url!.isNotEmpty) {
                return {
                  'type': 'image_url',
                  'image_url': {'url': image.url!, 'detail': 'high'},
                };
              }
              final part = uploadedParts[uploadIndex];
              uploadIndex += 1;
              return part;
            }).toList(),
            tempObjectKeys: uploads.map((item) => item.objectKey).toList(),
          );
        }
      } catch (error, stackTrace) {
        await DebugLogService.warn(
          source: 'TEMP_ASSET',
          message:
              'Falling back to inline image data after temporary upload failed.',
          error: error,
          stackTrace: stackTrace,
          context: {'imageCount': images.length},
        );
      }
    }

    return (
      imageParts: images.map((image) {
        final inlineUrl =
            image.url ??
            'data:${image.contentType ?? _defaultImageContentType};base64,'
                '${base64Encode(image.bytes!)}';
        return {
          'type': 'image_url',
          'image_url': {'url': inlineUrl, 'detail': 'high'},
        };
      }).toList(),
      tempObjectKeys: const <String>[],
    );
  }

  Future<String?> _refreshServerApiTokenForUpload() async {
    final refreshed = await _refreshServerApiTokenIfNeeded(
      source: 'TEMP_ASSET',
      reasonCode: 'token_refresh_required',
    );
    return refreshed ? _effectiveApiKey : null;
  }

  Future<bool> _refreshServerApiTokenIfNeeded({
    required String source,
    required String reasonCode,
  }) async {
    if (useCustomModelConfig || refreshServerApiToken == null) return false;
    if (!_shouldRefreshForError(reasonCode)) return false;

    try {
      final refreshed = await refreshServerApiToken!.call();
      if (refreshed == null || refreshed.trim().isEmpty) return false;
      _effectiveApiKey = refreshed.trim();
      await DebugLogService.info(
        source: source,
        message: 'Refreshed server API token after gateway rejection.',
        context: {'reasonCode': reasonCode},
      );
      return true;
    } catch (error, stackTrace) {
      await DebugLogService.warn(
        source: source,
        message: 'Failed to refresh server API token after gateway rejection.',
        error: error,
        stackTrace: stackTrace,
        context: {'reasonCode': reasonCode},
      );
      return false;
    }
  }

  bool _shouldRefreshForError(String code) {
    return code == 'token_refresh_required' ||
        code == 'invalid_or_expired_api_token' ||
        code == 'auth_session_expired';
  }

  void _ensureAvailable() {
    if (_effectiveApiKey.isEmpty) {
      throw AiServiceException(
        useCustomModelConfig ? 'invalid_config' : 'sign_in_required',
      );
    }
    if (useCustomModelConfig && _effectiveBaseUrl.isEmpty) {
      throw const AiServiceException('invalid_config');
    }
    if (_effectiveModelName.trim().isEmpty) {
      throw const AiServiceException('invalid_config');
    }
  }

  Map<String, dynamic> _describeChoiceShape(Map<String, dynamic> body) {
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) {
      return const {'kind': 'none'};
    }
    final first = choices.first;
    if (first is! Map) {
      return {
        'kind': 'non_map_choice',
        'runtimeType': first.runtimeType.toString(),
      };
    }
    final choice = first.map((key, value) => MapEntry(key.toString(), value));
    final message = choice['message'];
    final delta = choice['delta'];
    return {
      'choiceKeys': choice.keys.toList(),
      'messageType': message.runtimeType.toString(),
      'messageKeys': message is Map
          ? message.keys.map((e) => e.toString()).toList()
          : null,
      'deltaType': delta.runtimeType.toString(),
      'deltaKeys': delta is Map
          ? delta.keys.map((e) => e.toString()).toList()
          : null,
    };
  }

  Map<String, dynamic> _describeResponseStructure(dynamic data) {
    if (data is Map<String, dynamic>) {
      return {'kind': 'map', 'keys': data.keys.toList()};
    }
    if (data is Map) {
      return {
        'kind': 'map',
        'keys': data.keys.map((e) => e.toString()).toList(),
      };
    }
    if (data is List) {
      return {
        'kind': 'list',
        'length': data.length,
        'itemTypes': data
            .take(5)
            .map((item) => item.runtimeType.toString())
            .toList(),
      };
    }
    if (data is String) {
      final trimmed = data.trimLeft();
      return {
        'kind': 'string',
        'length': data.length,
        'looksLikeJson': trimmed.startsWith('{') || trimmed.startsWith('['),
      };
    }
    return {'kind': data.runtimeType.toString()};
  }

  Map<String, dynamic> _requestSummary(
    List<Map<String, dynamic>> messages,
    double temperature,
  ) {
    final imageCount = messages
        .expand((message) {
          final content = message['content'];
          if (content is List) return content;
          return const <dynamic>[];
        })
        .where((item) => item is Map && item['type']?.toString() == 'image_url')
        .length;
    return {
      'mode': useCustomModelConfig ? 'custom' : 'server',
      'model': _effectiveModelName,
      'baseHost': OpenAiCompatibleApi.safeBaseHost(_effectiveBaseUrl),
      'messageCount': messages.length,
      'imageCount': imageCount,
      'temperature': temperature,
      'maxTokens': modelReplyLength.maxTokens,
    };
  }

  Object? _previewDynamic(dynamic data) {
    if (data == null) return null;
    if (data is List<int>) {
      return {
        'kind': 'bytes',
        'length': data.length,
        'utf8Preview': utf8.decode(
          data.length <= 320 ? data : data.sublist(0, 320),
          allowMalformed: true,
        ),
      };
    }
    if (data is String) {
      return data;
    }
    if (data is Map || data is List) {
      return data;
    }
    return data.toString();
  }

  Map<String, dynamic> _asJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } on FormatException {
        // Some upstream gateways/proxies return HTML/plaintext for errors.
        // Treat it as non-JSON and fall through to empty map.
      } catch (_) {
        // Keep this parser defensive: any decode failure should not crash
        // request handling.
      }
    }
    return const {};
  }

  String? _extractAssistantText(Map<String, dynamic> body) {
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final choice = first.map((key, value) => MapEntry(key.toString(), value));
    final message = choice['message'];
    if (message is Map) {
      final normalized = message.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final content = normalized['content'];
      return _contentToText(content);
    }
    final delta = choice['delta'];
    if (delta is Map) {
      final normalized = delta.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return _contentToText(normalized['content']);
    }
    return null;
  }

  String? _extractErrorCode(dynamic data) {
    final body = _asJsonMap(data);
    final error = body['error'];
    if (error is Map) {
      return error['code']?.toString();
    }
    return body['code']?.toString();
  }

  String? _contentToText(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is Map) {
          final text = item['text']?.toString();
          if (text != null && text.isNotEmpty) {
            buffer.write(text);
          }
        } else if (item != null) {
          buffer.write(item.toString());
        }
      }
      final value = buffer.toString();
      return value.isEmpty ? null : value;
    }
    return content?.toString();
  }

  bool _looksLikeTranslationTask(String prompt) {
    final lower = prompt.toLowerCase();
    return lower.contains('translate') ||
        lower.contains('translation') ||
        lower.contains('verbatim') ||
        lower.contains('一字不落') ||
        lower.contains('原封不动') ||
        lower.contains('逐字') ||
        lower.contains('翻译');
  }

  String _strictTranslationInstruction() {
    return '''
你是“逐字完整翻译器”。你的唯一任务是把输入页面内容完整翻译为简体中文。

必须遵守：
1) 不得省略、跳过、合并、总结、改写任何信息。
2) 必须保持原文顺序；标题、段落、列表、脚注、编号、标点、数字、单位、日期、公式、代码、URL、邮箱、专有名词都必须保留。
3) 每一行或每一项都必须在译文中有对应内容，不得少项。
4) 对于无法辨认的字符或片段，在对应位置标注「[无法辨认]」，不得直接跳过。
5) 只输出译文本体，不要输出解释或额外说明。

在输出前先进行完整性检查，确认没有遗漏任何可见文本。
''';
  }
}

class AiImageInput {
  const AiImageInput._({this.bytes, this.url, this.contentType});

  factory AiImageInput.bytes(
    Uint8List bytes, {
    String contentType = AiService._defaultImageContentType,
  }) {
    return AiImageInput._(bytes: bytes, contentType: contentType);
  }

  factory AiImageInput.url(
    String url, {
    String contentType = AiService._defaultImageContentType,
  }) {
    return AiImageInput._(url: url, contentType: contentType);
  }

  final Uint8List? bytes;
  final String? url;
  final String? contentType;
}

class AiServiceException implements Exception {
  const AiServiceException(this.code);

  final String code;

  @override
  String toString() => code;
}

String _mapDioExceptionToCode(DioException error) {
  return switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => 'network_unavailable',
    _ => 'unknown_error',
  };
}

String _mapUnexpectedErrorToCode(Object error) {
  if (error is DioException) {
    return _mapDioExceptionToCode(error);
  }
  return 'unknown_error';
}
