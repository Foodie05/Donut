import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:donut_backend/src/config/config_repository.dart';

Response onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.get) {
    return Response(
      statusCode: HttpStatus.methodNotAllowed,
      headers: {'allow': 'GET'},
    );
  }

  return Response.json(
    headers: {
      HttpHeaders.cacheControlHeader: 'no-store, no-cache, must-revalidate',
      HttpHeaders.pragmaHeader: 'no-cache',
      HttpHeaders.expiresHeader: '0',
    },
    body: const ConfigRepository()
        .buildPublicRosemaryConfig(Platform.environment),
  );
}
