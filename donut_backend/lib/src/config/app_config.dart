import 'package:dart_frog/dart_frog.dart';

const _defaultUpstreamBaseUrl = 'https://api.openai.com/v1/';
const _defaultClientApiKey = 'donut-local-client-key';

/// Runtime configuration for the Donut gateway.
class AppConfig {
  /// Creates an application configuration.
  AppConfig({
    required this.upstreamBaseUrl,
    required this.upstreamApiKey,
    required this.clientApiKey,
  });

  /// Builds configuration from environment variables.
  factory AppConfig.fromEnvironment(Map<String, String> env) {
    return AppConfig(
      upstreamBaseUrl: _normalizeBaseUrl(
        env['DONUT_UPSTREAM_BASE_URL'] ?? _defaultUpstreamBaseUrl,
      ),
      upstreamApiKey: (env['DONUT_UPSTREAM_API_KEY'] ?? '').trim(),
      clientApiKey:
          (env['DONUT_CLIENT_API_KEY'] ?? _defaultClientApiKey).trim(),
    );
  }

  /// Base URL for the upstream OpenAI-compatible provider.
  final Uri upstreamBaseUrl;

  /// Secret API key used when the gateway talks to the upstream provider.
  final String upstreamApiKey;

  /// Bearer token accepted from the Donut app.
  final String clientApiKey;

  /// Resolves an upstream path while preserving the incoming query string.
  Uri resolve(String path, Uri requestUri) {
    final sanitizedPath = path.startsWith('/') ? path.substring(1) : path;
    final resolved = upstreamBaseUrl.resolve(sanitizedPath);
    if (requestUri.hasQuery) {
      return resolved.replace(query: requestUri.query);
    }
    return resolved;
  }

  /// Returns whether the incoming request uses the expected client token.
  bool isAuthorized(Request request) {
    if (clientApiKey.isEmpty) return true;
    return bearerTokenFrom(request.headers['authorization']) == clientApiKey;
  }

  /// Extracts a bearer token value from an Authorization header.
  static String? bearerTokenFrom(String? authorizationHeader) {
    if (authorizationHeader == null || authorizationHeader.isEmpty) {
      return null;
    }

    final parts = authorizationHeader.split(' ');
    if (parts.length != 2) return null;
    if (parts.first.toLowerCase() != 'bearer') return null;
    final token = parts.last.trim();
    return token.isEmpty ? null : token;
  }
}

Uri _normalizeBaseUrl(String raw) {
  final normalized = raw.endsWith('/') ? raw : '$raw/';
  return Uri.parse(normalized);
}
