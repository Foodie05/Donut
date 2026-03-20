import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:donut_backend/src/config/app_config.dart';
import 'package:donut_backend/src/openai/openai_gateway_proxy.dart';

/// Handles a validated OpenAI-compatible gateway request.
Future<Response> handleGatewayRequest(
  Request request, {
  required String upstreamPath,
  AppConfig? config,
  OpenAIGatewayProxy? proxy,
}) async {
  final resolvedConfig =
      config ?? AppConfig.fromEnvironment(Platform.environment);

  if (!resolvedConfig.isAuthorized(request)) {
    return _errorResponse(
      statusCode: HttpStatus.unauthorized,
      message: 'Invalid API key provided.',
      code: 'invalid_api_key',
      type: 'invalid_request_error',
      headers: const {
        'www-authenticate': 'Bearer realm="OpenAI API"',
      },
    );
  }

  if (resolvedConfig.upstreamApiKey.isEmpty) {
    return _errorResponse(
      statusCode: HttpStatus.internalServerError,
      message: 'The Donut gateway is missing '
          'DONUT_UPSTREAM_API_KEY configuration.',
      code: 'gateway_not_configured',
      type: 'server_error',
    );
  }

  final gatewayProxy = proxy ?? OpenAIGatewayProxy(config: resolvedConfig);
  return gatewayProxy.forward(request, upstreamPath: upstreamPath);
}

/// Returns an OpenAI-style error for unsupported methods.
Response methodNotAllowed(List<String> allowedMethods) {
  return _errorResponse(
    statusCode: HttpStatus.methodNotAllowed,
    message: 'The requested method is not supported for this endpoint.',
    code: 'method_not_allowed',
    type: 'invalid_request_error',
    headers: {
      'allow': allowedMethods.join(', '),
    },
  );
}

Response _errorResponse({
  required int statusCode,
  required String message,
  required String code,
  required String type,
  Map<String, Object> headers = const {},
}) {
  return Response.json(
    statusCode: statusCode,
    headers: headers,
    body: {
      'error': {
        'message': message,
        'type': type,
        'param': null,
        'code': code,
      },
    },
  );
}
