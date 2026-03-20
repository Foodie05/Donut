import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:donut_backend/src/config/app_config.dart';
import 'package:http/http.dart' as http;

/// Proxies OpenAI-compatible HTTP requests to the configured upstream.
class OpenAIGatewayProxy {
  /// Creates a gateway proxy.
  OpenAIGatewayProxy({required this.config, http.Client? client})
      : _client = client ?? http.Client();

  /// Runtime configuration for upstream communication.
  final AppConfig config;
  final http.Client _client;

  /// Sends a request to the configured upstream without altering the payload.
  Future<http.StreamedResponse> send(
    Request request, {
    required String upstreamPath,
  }) async {
    final upstreamRequest = http.Request(
      request.method.name,
      config.resolve(upstreamPath, request.uri),
    );

    _copyRequestHeaders(request.headers, upstreamRequest.headers);
    upstreamRequest.headers['authorization'] =
        'Bearer ${config.upstreamApiKey}';

    if (_supportsRequestBody(request.method.name)) {
      upstreamRequest.bodyBytes = await _readBodyBytes(request);
    }

    return _client.send(upstreamRequest);
  }

  /// Forwards a request to an upstream OpenAI-compatible path.
  Future<Response> forward(
    Request request, {
    required String upstreamPath,
  }) async {
    final upstreamResponse = await send(
      request,
      upstreamPath: upstreamPath,
    );
    final responseHeaders = _sanitizeResponseHeaders(upstreamResponse.headers);

    if (_isEventStream(upstreamResponse.headers)) {
      return Response.stream(
        statusCode: upstreamResponse.statusCode,
        headers: responseHeaders,
        body: _closeClientWhenDone(upstreamResponse.stream),
        bufferOutput: false,
      );
    }

    final bytes = await upstreamResponse.stream.toBytes();
    _client.close();
    return Response.bytes(
      statusCode: upstreamResponse.statusCode,
      headers: responseHeaders,
      body: bytes,
    );
  }

  void _copyRequestHeaders(
    Map<String, String> source,
    Map<String, String> target,
  ) {
    for (final entry in source.entries) {
      final key = entry.key.toLowerCase();
      if (_hopByHopHeaders.contains(key) || key == 'authorization') {
        continue;
      }
      target[entry.key] = entry.value;
    }
  }

  Map<String, Object> _sanitizeResponseHeaders(Map<String, String> headers) {
    final sanitized = <String, Object>{};
    for (final entry in headers.entries) {
      if (_hopByHopHeaders.contains(entry.key.toLowerCase())) continue;
      sanitized[entry.key] = entry.value;
    }
    return sanitized;
  }

  Stream<List<int>> _closeClientWhenDone(Stream<List<int>> source) {
    final controller = StreamController<List<int>>();

    late final StreamSubscription<List<int>> subscription;
    subscription = source.listen(
      controller.add,
      onError: (Object error, StackTrace stackTrace) {
        _client.close();
        controller.addError(error, stackTrace);
      },
      onDone: () {
        _client.close();
        unawaited(controller.close());
      },
      cancelOnError: true,
    );

    controller.onCancel = () async {
      await subscription.cancel();
      _client.close();
    };

    return controller.stream;
  }
}

const _hopByHopHeaders = {
  'connection',
  'content-length',
  'host',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
};

bool _supportsRequestBody(String method) {
  switch (method.toUpperCase()) {
    case 'GET':
    case 'HEAD':
      return false;
    default:
      return true;
  }
}

Future<List<int>> _readBodyBytes(Request request) async {
  final bytes = <int>[];
  await for (final chunk in request.bytes()) {
    bytes.addAll(chunk);
  }
  return bytes;
}

bool _isEventStream(Map<String, String> headers) {
  final contentType = headers.entries
      .firstWhere(
        (entry) => entry.key.toLowerCase() == 'content-type',
        orElse: () => const MapEntry('', ''),
      )
      .value
      .toLowerCase();
  return contentType.contains('text/event-stream');
}
