import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

void main() {
  group('GET /', () {
    test('responds with gateway health json.', () async {
      final context = _MockRequestContext();
      final response = route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(
        await response.json() as Map<String, dynamic>,
        equals({
          'service': 'donut_backend',
          'status': 'ok',
          'message': 'OpenAI-compatible gateway is running.',
        }),
      );
    });
  });
}
