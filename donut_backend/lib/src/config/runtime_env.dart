import 'dart:io';

import 'package:donut_backend/src/config/runtime_paths.dart' as runtime_paths;
import 'package:donut_backend/src/persistence/backend_database.dart';

const editableRuntimeEnvKeys = <String>[
  'DONUT_ADMIN_SECRET',
  'DONUT_UPSTREAM_BASE_URL',
  'DONUT_UPSTREAM_API_KEY',
  'DONUT_CLIENT_API_KEY',
  'DONUT_API_TOKEN_SIGNING_SECRET',
  'DONUT_API_TOKEN_ISSUER',
  'DONUT_API_TOKEN_AUDIENCE',
  'DONUT_API_TOKEN_IMAGE_LIMIT',
  'DONUT_AUTH_ISSUER',
  'DONUT_AUTH_CLIENT_ID',
  'DONUT_AUTH_CLIENT_SECRET',
  'DONUT_AUTH_SCOPES',
  'DONUT_PUBLIC_BASE_URL',
  'DONUT_DEFAULT_MODEL',
  'DONUT_AVAILABLE_MODELS',
  'DONUT_RECOMMENDED_MODELS',
  'DONUT_MODEL_RULES',
  'DONUT_DAILY_PAGE_LIMIT',
  'DONUT_STORAGE_ENDPOINT',
  'DONUT_STORAGE_REGION',
  'DONUT_STORAGE_BUCKET',
  'DONUT_STORAGE_ACCESS_KEY',
  'DONUT_STORAGE_SECRET_KEY',
  'DONUT_STORAGE_PATH_PREFIX',
  'DONUT_STORAGE_PUBLIC_BASE_URL',
  'DONUT_ROSEMARY_ENABLED',
  'DONUT_ROSEMARY_API_BASE_URL',
  'DONUT_ROSEMARY_APP_NAME',
  'DONUT_ROSEMARY_RES_VERSION',
];

Map<String, String> resolveRuntimeEnvironment(Map<String, String> processEnv) {
  final merged = <String, String>{};
  merged.addAll(_readDotEnv(runtime_paths.dotEnvFilePath(processEnv)));
  merged.addAll(processEnv);
  merged.addAll(readRuntimeOverrides(processEnv));
  return merged;
}

String runtimeConfigPath(Map<String, String> processEnv) {
  return runtime_paths.runtimeConfigPath(processEnv);
}

String dotEnvFilePath(Map<String, String> processEnv) {
  return runtime_paths.dotEnvFilePath(processEnv);
}

Map<String, String> readRuntimeOverrides(Map<String, String> processEnv) {
  try {
    final database = BackendDatabase.instanceFor(processEnv);
    return database.configOverrides();
  } catch (_) {
    return const {};
  }
}

Future<void> writeRuntimeOverrides(
  Map<String, String> processEnv,
  Map<String, String> values,
) async {
  final payload = <String, String>{};
  for (final key in editableRuntimeEnvKeys) {
    final value = values[key]?.trim() ?? '';
    if (value.isNotEmpty) {
      payload[key] = value;
    }
  }
  final database = BackendDatabase.instanceFor(processEnv);
  await database.replaceConfigOverrides(payload);
}

Map<String, String> _readDotEnv(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) return const {};

  final result = <String, String>{};
  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final equalsIndex = line.indexOf('=');
    if (equalsIndex <= 0) continue;
    final key = line.substring(0, equalsIndex).trim();
    var value = line.substring(equalsIndex + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    result[key] = value;
  }
  return result;
}
