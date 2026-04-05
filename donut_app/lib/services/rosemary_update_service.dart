import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rosemary_updater/rosemary_updater.dart';

import 'debug_log_service.dart';
import 'settings_service.dart';

enum RosemaryCheckState {
  unsupportedPlatform,
  notConfigured,
  noUpdate,
  hasUpdate,
  failed,
}

class RosemaryCheckResult {
  const RosemaryCheckResult({
    required this.state,
    this.updateInfo,
    this.errorMessage,
    this.currentVersion,
  });

  final RosemaryCheckState state;
  final UpdateReceive? updateInfo;
  final String? errorMessage;
  final String? currentVersion;
}

class RosemaryPublicConfig {
  const RosemaryPublicConfig({
    required this.enabled,
    required this.apiBaseUrl,
    required this.appName,
    required this.resVersion,
  });

  final bool enabled;
  final String apiBaseUrl;
  final String appName;
  final int resVersion;

  bool get isUsable => enabled && apiBaseUrl.isNotEmpty && appName.isNotEmpty;

  factory RosemaryPublicConfig.fromJson(Map<String, dynamic> json) {
    final rawResVersion = json['resVersion'];
    final parsedResVersion = rawResVersion is num
        ? rawResVersion.toInt()
        : int.tryParse(rawResVersion?.toString() ?? '') ?? 0;
    return RosemaryPublicConfig(
      enabled: json['enabled'] == true,
      apiBaseUrl: json['apiBaseUrl']?.toString().trim() ?? '',
      appName: json['appName']?.toString().trim() ?? '',
      resVersion: parsedResVersion < 0 ? 0 : parsedResVersion,
    );
  }
}

class RosemaryUpdateService {
  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
        return false;
    }
  }

  Future<RosemaryPublicConfig?> _fetchPublicConfig() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        validateStatus: (_) => true,
      ),
    );
    final endpoint = _backendRootUri().resolve('config/rosemary');
    final response = await dio.getUri(
      endpoint,
      options: Options(
        headers: const {'cache-control': 'no-cache', 'pragma': 'no-cache'},
      ),
    );
    if (response.statusCode != 200) {
      await DebugLogService.warn(
        source: 'ROSEMARY',
        message: 'Failed to fetch Rosemary public config.',
        context: {
          'endpoint': endpoint.toString(),
          'statusCode': response.statusCode,
          'responsePreview': response.data?.toString().substring(
            0,
            response.data.toString().length > 500
                ? 500
                : response.data.toString().length,
          ),
        },
      );
      return null;
    }
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return RosemaryPublicConfig.fromJson(data);
    }
    if (data is Map) {
      return RosemaryPublicConfig.fromJson(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return null;
  }

  UpdaterConfig _buildUpdaterConfig({
    required RosemaryPublicConfig publicConfig,
    required int appVersion,
  }) {
    return UpdaterConfig(
      apiBaseUrl: publicConfig.apiBaseUrl,
      appName: publicConfig.appName,
      appPasswd: '',
      betaPasswd: '',
      appVersion: appVersion,
      resVersion: publicConfig.resVersion,
    );
  }

  Future<RosemaryCheckResult> checkUpdate() async {
    if (!_isSupportedPlatform) {
      return const RosemaryCheckResult(
        state: RosemaryCheckState.unsupportedPlatform,
      );
    }

    try {
      final publicConfig = await _fetchPublicConfig();
      if (publicConfig == null || !publicConfig.isUsable) {
        return const RosemaryCheckResult(
          state: RosemaryCheckState.notConfigured,
        );
      }
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = int.tryParse(packageInfo.buildNumber) ?? 0;
      final updater = RosemaryUpdater(
        _buildUpdaterConfig(publicConfig: publicConfig, appVersion: appVersion),
      );

      final info = await updater.checkUpdate();
      final currentVersion =
          '${packageInfo.version}+${packageInfo.buildNumber}';
      if (info == null || (!info.appUpgrade && !info.resUpgrade)) {
        return RosemaryCheckResult(
          state: RosemaryCheckState.noUpdate,
          currentVersion: currentVersion,
        );
      }

      return RosemaryCheckResult(
        state: RosemaryCheckState.hasUpdate,
        updateInfo: info,
        currentVersion: currentVersion,
      );
    } catch (e, stackTrace) {
      await DebugLogService.error(
        source: 'ROSEMARY',
        message: 'Rosemary check update failed.',
        error: e,
        stackTrace: stackTrace,
      );
      return RosemaryCheckResult(
        state: RosemaryCheckState.failed,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> runUpdate({
    required UpdateReceive updateInfo,
    required void Function(UpdateStatus status) onStatusChanged,
  }) async {
    final publicConfig = await _fetchPublicConfig();
    if (publicConfig == null || !publicConfig.isUsable) {
      throw Exception('Rosemary public config is not ready.');
    }
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = int.tryParse(packageInfo.buildNumber) ?? 0;

    final updater = RosemaryUpdater(
      _buildUpdaterConfig(publicConfig: publicConfig, appVersion: appVersion),
    );

    try {
      await updater.runUpdate(
        updateInfo: updateInfo,
        onStatusChanged: onStatusChanged,
      );
    } catch (e, stackTrace) {
      await DebugLogService.error(
        source: 'ROSEMARY',
        message: 'Rosemary run update failed.',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

Uri _backendRootUri() {
  final uri = Uri.parse(defaultGatewayBaseUrl);
  var normalizedPath = uri.path;
  if (normalizedPath.endsWith('/')) {
    normalizedPath = normalizedPath.substring(0, normalizedPath.length - 1);
  }
  if (normalizedPath == '/v1') {
    normalizedPath = '/';
  } else if (normalizedPath.endsWith('/v1')) {
    normalizedPath = normalizedPath.substring(0, normalizedPath.length - 3);
    if (normalizedPath.isEmpty) {
      normalizedPath = '/';
    }
  }
  return uri.replace(
    path: normalizedPath.isEmpty ? '/' : normalizedPath,
    query: null,
    fragment: null,
  );
}

final rosemaryUpdateServiceProvider = Provider<RosemaryUpdateService>((ref) {
  return RosemaryUpdateService();
});
