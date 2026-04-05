import 'package:donut_backend/src/config/model_rule.dart';
import 'package:donut_backend/src/config/runtime_env.dart';

class ConfigRepository {
  const ConfigRepository();

  Map<String, dynamic> loadAdminConfig(Map<String, String> processEnv) {
    final merged = resolveRuntimeEnvironment(processEnv);
    final overrides = readRuntimeOverrides(processEnv);
    final availableModels =
        _splitModels(merged['DONUT_AVAILABLE_MODELS'] ?? '');
    final recommendedModels = _splitModels(
      merged['DONUT_RECOMMENDED_MODELS'] ?? '',
    );
    final defaultModel = (merged['DONUT_DEFAULT_MODEL'] ?? 'gpt-4o').trim();
    final modelRules = parseModelRules(
      merged['DONUT_MODEL_RULES'] ?? '',
      fallbackAvailable: availableModels,
      fallbackRecommended: recommendedModels,
      fallbackDefaultModel: defaultModel,
    );
    return {
      'configPath': runtimeConfigPath(processEnv),
      'dotEnvPath': dotEnvFilePath(processEnv),
      'adminEnabled':
          (merged['DONUT_ADMIN_SECRET']?.trim().isNotEmpty ?? false),
      'fields': {
        'upstreamBaseUrl':
            merged['DONUT_UPSTREAM_BASE_URL'] ?? 'https://api.openai.com/v1/',
        'upstreamApiKey': merged['DONUT_UPSTREAM_API_KEY'] ?? '',
        'clientApiKey':
            merged['DONUT_CLIENT_API_KEY'] ?? 'donut-local-client-key',
        'apiTokenSigningSecret': merged['DONUT_API_TOKEN_SIGNING_SECRET'] ?? '',
        'apiTokenIssuer': merged['DONUT_API_TOKEN_ISSUER'] ?? 'donut-backend',
        'apiTokenAudience': merged['DONUT_API_TOKEN_AUDIENCE'] ?? 'donut-edge',
        'apiTokenImageLimit':
            int.tryParse(merged['DONUT_API_TOKEN_IMAGE_LIMIT'] ?? '') ?? 5,
        'authIssuer': merged['DONUT_AUTH_ISSUER'] ?? '',
        'authClientId': merged['DONUT_AUTH_CLIENT_ID'] ?? '',
        'authClientSecret': merged['DONUT_AUTH_CLIENT_SECRET'] ?? '',
        'authScopes': merged['DONUT_AUTH_SCOPES'] ?? 'openid profile email',
        'publicBaseUrl': merged['DONUT_PUBLIC_BASE_URL'] ?? '',
        'storageEndpoint': merged['DONUT_STORAGE_ENDPOINT'] ?? '',
        'storageRegion': merged['DONUT_STORAGE_REGION'] ?? 'auto',
        'storageBucket': merged['DONUT_STORAGE_BUCKET'] ?? '',
        'storageAccessKey': merged['DONUT_STORAGE_ACCESS_KEY'] ?? '',
        'storageSecretKey': merged['DONUT_STORAGE_SECRET_KEY'] ?? '',
        'storagePathPrefix':
            merged['DONUT_STORAGE_PATH_PREFIX'] ?? 'donut-temp',
        'storagePublicBaseUrl': merged['DONUT_STORAGE_PUBLIC_BASE_URL'] ?? '',
        'rosemaryEnabled':
            (merged['DONUT_ROSEMARY_ENABLED'] ?? '').trim().toLowerCase() ==
                'true',
        'rosemaryApiBaseUrl': merged['DONUT_ROSEMARY_API_BASE_URL'] ?? '',
        'rosemaryAppName': merged['DONUT_ROSEMARY_APP_NAME'] ?? '',
        'rosemaryResVersion':
            int.tryParse(merged['DONUT_ROSEMARY_RES_VERSION'] ?? '') ?? 0,
        'dailyPageLimit':
            double.tryParse(merged['DONUT_DAILY_PAGE_LIMIT'] ?? '') ?? 100,
        'defaultModel': defaultModel,
        'availableModels': availableModels,
        'recommendedModels': recommendedModels,
        'modelRules': modelRules
            .map((rule) => rule.toJson(isDefault: rule.name == defaultModel))
            .toList(),
        'modelCatalog': _mergeModels([
          ...modelRules.map((rule) => rule.name),
        ]),
      },
      'sources': {
        for (final key in editableRuntimeEnvKeys)
          key: overrides.containsKey(key) ? 'override' : 'env',
      },
    };
  }

  Future<void> saveAdminConfig(
    Map<String, String> processEnv,
    Map<String, dynamic> payload,
  ) async {
    final merged = resolveRuntimeEnvironment(processEnv);
    final availableModels = _normalizeModels(payload['availableModels']);
    final rawRules = payload['modelRules'];
    final modelRules = _normalizeModelRules(rawRules, availableModels);
    final recommendedModels = modelRules
        .where((rule) => rule.enabled && rule.recommended)
        .map((rule) => rule.name)
        .toList();
    final requestedDefaultModel =
        payload['defaultModel']?.toString().trim() ?? '';
    final enabledRules = modelRules.where((rule) => rule.enabled).toList();
    final defaultModel =
        enabledRules.any((rule) => rule.name == requestedDefaultModel)
            ? requestedDefaultModel
            : (enabledRules.isNotEmpty ? enabledRules.first.name : '');
    final values = <String, String>{
      'DONUT_ADMIN_SECRET': merged['DONUT_ADMIN_SECRET'] ?? '',
      'DONUT_UPSTREAM_BASE_URL': payload['upstreamBaseUrl']?.toString() ?? '',
      'DONUT_UPSTREAM_API_KEY': payload['upstreamApiKey']?.toString() ?? '',
      'DONUT_CLIENT_API_KEY': payload['clientApiKey']?.toString() ?? '',
      'DONUT_API_TOKEN_SIGNING_SECRET':
          payload['apiTokenSigningSecret']?.toString() ?? '',
      'DONUT_API_TOKEN_ISSUER':
          payload['apiTokenIssuer']?.toString() ?? 'donut-backend',
      'DONUT_API_TOKEN_AUDIENCE':
          payload['apiTokenAudience']?.toString() ?? 'donut-edge',
      'DONUT_API_TOKEN_IMAGE_LIMIT':
          payload['apiTokenImageLimit']?.toString() ?? '5',
      'DONUT_AUTH_ISSUER': payload['authIssuer']?.toString() ?? '',
      'DONUT_AUTH_CLIENT_ID': payload['authClientId']?.toString() ?? '',
      'DONUT_AUTH_CLIENT_SECRET': payload['authClientSecret']?.toString() ?? '',
      'DONUT_AUTH_SCOPES': payload['authScopes']?.toString() ?? '',
      'DONUT_PUBLIC_BASE_URL': payload['publicBaseUrl']?.toString() ?? '',
      'DONUT_STORAGE_ENDPOINT': payload['storageEndpoint']?.toString() ?? '',
      'DONUT_STORAGE_REGION': payload['storageRegion']?.toString() ?? 'auto',
      'DONUT_STORAGE_BUCKET': payload['storageBucket']?.toString() ?? '',
      'DONUT_STORAGE_ACCESS_KEY': payload['storageAccessKey']?.toString() ?? '',
      'DONUT_STORAGE_SECRET_KEY': payload['storageSecretKey']?.toString() ?? '',
      'DONUT_STORAGE_PATH_PREFIX':
          payload['storagePathPrefix']?.toString() ?? 'donut-temp',
      'DONUT_STORAGE_PUBLIC_BASE_URL':
          payload['storagePublicBaseUrl']?.toString() ?? '',
      'DONUT_ROSEMARY_ENABLED':
          payload['rosemaryEnabled']?.toString() ?? 'false',
      'DONUT_ROSEMARY_API_BASE_URL':
          payload['rosemaryApiBaseUrl']?.toString() ?? '',
      'DONUT_ROSEMARY_APP_NAME': payload['rosemaryAppName']?.toString() ?? '',
      'DONUT_ROSEMARY_RES_VERSION':
          payload['rosemaryResVersion']?.toString() ?? '0',
      'DONUT_DEFAULT_MODEL': defaultModel,
      'DONUT_AVAILABLE_MODELS':
          enabledRules.map((rule) => rule.name).join('\n'),
      'DONUT_RECOMMENDED_MODELS': recommendedModels.join('\n'),
      'DONUT_MODEL_RULES':
          encodeModelRules(modelRules, defaultModel: defaultModel),
      'DONUT_DAILY_PAGE_LIMIT': payload['dailyPageLimit']?.toString() ?? '100',
    };
    await writeRuntimeOverrides(processEnv, values);
  }

  Map<String, dynamic> buildPublicSummary(Map<String, String> processEnv) {
    final merged = resolveRuntimeEnvironment(processEnv);
    final availableModels =
        _splitModels(merged['DONUT_AVAILABLE_MODELS'] ?? '');
    final recommendedModels = _splitModels(
      merged['DONUT_RECOMMENDED_MODELS'] ?? '',
    );
    final defaultModel = merged['DONUT_DEFAULT_MODEL'] ?? 'gpt-4o';
    final modelRules = parseModelRules(
      merged['DONUT_MODEL_RULES'] ?? '',
      fallbackAvailable: availableModels,
      fallbackRecommended: recommendedModels,
      fallbackDefaultModel: defaultModel,
    );
    return {
      'defaultModel': defaultModel,
      'availableModels': availableModels,
      'recommendedModels': recommendedModels,
      'serverModels': modelRules
          .where((rule) => rule.enabled)
          .map((rule) => rule.toJson(isDefault: rule.name == defaultModel))
          .toList(),
      'dailyPageLimit':
          double.tryParse(merged['DONUT_DAILY_PAGE_LIMIT'] ?? '') ?? 100,
      'temporaryAssetUploadEnabled': (merged['DONUT_STORAGE_ENDPOINT']
                  ?.trim()
                  .isNotEmpty ??
              false) &&
          (merged['DONUT_STORAGE_BUCKET']?.trim().isNotEmpty ?? false) &&
          (merged['DONUT_STORAGE_ACCESS_KEY']?.trim().isNotEmpty ?? false) &&
          (merged['DONUT_STORAGE_SECRET_KEY']?.trim().isNotEmpty ?? false) &&
          (merged['DONUT_STORAGE_PUBLIC_BASE_URL']?.trim().isNotEmpty ?? false),
      'oidcConfigured':
          (merged['DONUT_AUTH_ISSUER']?.trim().isNotEmpty ?? false) &&
              (merged['DONUT_AUTH_CLIENT_ID']?.trim().isNotEmpty ?? false),
      'publicBaseUrl': merged['DONUT_PUBLIC_BASE_URL'] ?? '',
      'rosemary': buildPublicRosemaryConfig(processEnv),
    };
  }

  Map<String, dynamic> buildPublicRosemaryConfig(
      Map<String, String> processEnv) {
    final merged = resolveRuntimeEnvironment(processEnv);
    final enabled =
        (merged['DONUT_ROSEMARY_ENABLED'] ?? '').trim().toLowerCase() == 'true';
    return {
      'enabled': enabled,
      'apiBaseUrl': merged['DONUT_ROSEMARY_API_BASE_URL'] ?? '',
      'appName': merged['DONUT_ROSEMARY_APP_NAME'] ?? '',
      'resVersion':
          int.tryParse(merged['DONUT_ROSEMARY_RES_VERSION'] ?? '') ?? 0,
    };
  }

  List<String> _splitModels(String raw) {
    return raw
        .split(RegExp(r'[\n,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<String> _normalizeModels(dynamic raw) {
    if (raw is List) {
      return _mergeModels(
        raw
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty),
      );
    }
    return _splitModels(raw?.toString() ?? '');
  }

  List<ModelRule> _normalizeModelRules(
      dynamic raw, List<String> availableModels) {
    final rules = <ModelRule>[];
    final seen = <String>{};
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final rule = ModelRule.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (rule.name.isEmpty || !seen.add(rule.name)) continue;
        rules.add(rule);
      }
    }
    for (final model in availableModels) {
      if (seen.add(model)) {
        rules.add(ModelRule(name: model, enabled: true));
      }
    }
    return rules;
  }

  List<String> _mergeModels(Iterable<String> models) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final model in models) {
      final value = model.trim();
      if (value.isEmpty || !seen.add(value)) continue;
      ordered.add(value);
    }
    return ordered;
  }
}

bool constantTimeEquals(String left, String right) {
  if (left.length != right.length) return false;
  var result = 0;
  for (var i = 0; i < left.length; i++) {
    result |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
  }
  return result == 0;
}

Future<Map<String, dynamic>> parseJsonBody(
  Future<dynamic> Function() requestBodyReader,
) async {
  final body = await requestBodyReader();
  if (body is Map<String, dynamic>) return body;
  if (body is Map) {
    return body.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}
