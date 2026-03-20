import 'package:dart_frog/dart_frog.dart';

import 'package:donut_backend/src/openai/openai_handlers.dart';

Future<Response> onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.get) {
    return Future.value(methodNotAllowed(const ['GET']));
  }

  return handleGatewayRequest(
    context.request,
    upstreamPath: 'models',
  );
}
