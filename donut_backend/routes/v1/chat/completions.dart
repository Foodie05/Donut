import 'package:dart_frog/dart_frog.dart';

import 'package:donut_backend/src/openai/openai_handlers.dart';

Future<Response> onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.post) {
    return Future.value(methodNotAllowed(const ['POST']));
  }

  return handleGatewayRequest(
    context.request,
    upstreamPath: 'chat/completions',
  );
}
