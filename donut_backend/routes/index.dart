import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  return Response.json(
    body: {
      'service': 'donut_backend',
      'status': 'ok',
      'message': 'OpenAI-compatible gateway is running.',
    },
  );
}
