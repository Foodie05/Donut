// ignore_for_file: directives_ordering

import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:donut_backend/src/config/app_config.dart';
import 'package:donut_backend/src/openai/openai_handlers.dart';
import 'package:donut_backend/src/openai/openai_gateway_proxy.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request);
}

void main() {
  group('gateway auth handling', () {
    final config = AppConfig(
      upstreamBaseUrl: Uri.parse('https://upstream.example.com/v1/'),
      upstreamApiKey: 'upstream-secret',
      clientApiKey: 'donut-client-key',
    );

    test('rejects invalid bearer token with OpenAI-style error body', () async {
      final response = await handleGatewayRequest(
        Request.post(
          Uri.parse('http://localhost/v1/chat/completions'),
          headers: {
            HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
          },
          body: jsonEncode({'stream': true}),
        ),
        upstreamPath: 'chat/completions',
        config: config,
      );

      expect(response.statusCode, equals(HttpStatus.unauthorized));
      expect(
        await response.json() as Map<String, dynamic>,
        containsPair(
          'error',
          {
            'message': 'Invalid API key provided.',
            'type': 'invalid_request_error',
            'param': null,
            'code': 'invalid_api_key',
          },
        ),
      );
    });
  });

  group('OpenAIGatewayProxy', () {
    final config = AppConfig(
      upstreamBaseUrl: Uri.parse('https://upstream.example.com/v1/'),
      upstreamApiKey: 'upstream-secret',
      clientApiKey: 'donut-client-key',
    );

    test('rewrites authorization and forwards non-stream responses', () async {
      late http.BaseRequest capturedRequest;
      final proxy = OpenAIGatewayProxy(
        config: config,
        client: _FakeHttpClient((request) async {
          capturedRequest = request;
          expect(
            request.headers[HttpHeaders.authorizationHeader],
            equals('Bearer upstream-secret'),
          );
          return http.StreamedResponse(
            Stream.value(utf8.encode('{"id":"chatcmpl_123"}')),
            HttpStatus.ok,
            headers: {
              HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
            },
          );
        }),
      );

      final upstreamResponse = await proxy.send(
        Request.get(
          Uri.parse('http://localhost/v1/models'),
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer donut-client-key',
          },
        ),
        upstreamPath: 'models',
      );

      expect(
        capturedRequest.url.toString(),
        equals('https://upstream.example.com/v1/models'),
      );
      expect(upstreamResponse.statusCode, equals(HttpStatus.ok));
      expect(
        await upstreamResponse.stream.bytesToString(),
        equals('{"id":"chatcmpl_123"}'),
      );
    });

    test('preserves SSE chunks for streaming responses', () async {
      final proxy = OpenAIGatewayProxy(
        config: config,
        client: _FakeHttpClient((request) async {
          return http.StreamedResponse(
            Stream.fromIterable([
              utf8.encode('data: {"id":"chatcmpl_1"}\n\n'),
              utf8.encode('data: [DONE]\n\n'),
            ]),
            HttpStatus.ok,
            headers: {
              HttpHeaders.contentTypeHeader: 'text/event-stream; charset=utf-8',
              HttpHeaders.cacheControlHeader: 'no-cache',
            },
          );
        }),
      );

      final upstreamResponse = await proxy.send(
        Request.get(
          Uri.parse('http://localhost/v1/models'),
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer donut-client-key',
          },
        ),
        upstreamPath: 'models',
      );

      expect(upstreamResponse.statusCode, equals(HttpStatus.ok));
      expect(
        upstreamResponse.headers[HttpHeaders.contentTypeHeader],
        contains('text/event-stream'),
      );
      expect(
        await upstreamResponse.stream.bytesToString(),
        equals('data: {"id":"chatcmpl_1"}\n\ndata: [DONE]\n\n'),
      );
    });
  });
}
