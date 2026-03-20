import 'dart:async';

import 'package:flutter/services.dart';
import 'debug_log_service.dart';

class ExternalFileOpenService {
  ExternalFileOpenService._();

  static const MethodChannel _channel = MethodChannel('donut/file_open');
  static final StreamController<String> _pathsController =
      StreamController<String>.broadcast(onListen: _flushPendingPaths);
  static String? _lastDeliveredPath;
  static DateTime? _lastDeliveredAt;
  static final List<String> _pendingPaths = <String>[];
  static bool _initialized = false;

  static Stream<String> get paths => _pathsController.stream;

  static Future<void> initialize(List<String> startupArgs) async {
    if (_initialized) return;
    _initialized = true;
    await DebugLogService.log(
      'ExternalFileOpenService.initialize startupArgs=${startupArgs.length}',
      tag: 'EXT',
    );

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openFile' && call.arguments is String) {
        await DebugLogService.log(
          'MethodChannel openFile: ${call.arguments}',
          tag: 'EXT',
        );
        _emitIfSupported(call.arguments as String);
      } else if (call.method == 'debugLog' && call.arguments is String) {
        await DebugLogService.log(call.arguments as String, tag: 'MAC');
      }
    });

    for (final arg in startupArgs) {
      await DebugLogService.log('Startup arg seen: $arg', tag: 'EXT');
      _emitIfSupported(arg);
    }

    try {
      final initialPath = await _channel.invokeMethod<String>(
        'consumeInitialFile',
      );
      if (initialPath != null) {
        await DebugLogService.log(
          'consumeInitialFile => $initialPath',
          tag: 'EXT',
        );
        _emitIfSupported(initialPath);
      } else {
        await DebugLogService.log('consumeInitialFile => null', tag: 'EXT');
      }
      await _channel.invokeMethod<void>('setDartReadyForFileOpenEvents');
      await DebugLogService.log(
        'setDartReadyForFileOpenEvents sent',
        tag: 'EXT',
      );
    } on MissingPluginException {
      // Some platforms only provide startup args and no method channel bridge.
      await DebugLogService.log('MethodChannel missing plugin', tag: 'EXT');
    } catch (e) {
      // Ignore bridge errors and keep app startup resilient.
      await DebugLogService.log('MethodChannel init error: $e', tag: 'EXT');
    }
  }

  static void _emitIfSupported(String rawPath) {
    final path = _normalizePath(rawPath);
    if (path == null || !_isSupportedBookPath(path)) return;
    final now = DateTime.now();
    final isLikelyDuplicateEvent =
        _lastDeliveredPath == path &&
        _lastDeliveredAt != null &&
        now.difference(_lastDeliveredAt!) < const Duration(seconds: 1);
    if (isLikelyDuplicateEvent) {
      unawaited(
        DebugLogService.log('Deduped repeated event path=$path', tag: 'EXT'),
      );
      return;
    }

    _lastDeliveredPath = path;
    _lastDeliveredAt = now;
    if (_pathsController.hasListener) {
      unawaited(
        DebugLogService.log('Emit path to listeners: $path', tag: 'EXT'),
      );
      _pathsController.add(path);
    } else {
      unawaited(
        DebugLogService.log('Queue path pending listener: $path', tag: 'EXT'),
      );
      _pendingPaths.add(path);
    }
  }

  static void _flushPendingPaths() {
    if (_pendingPaths.isEmpty) return;
    final pathsToEmit = List<String>.from(_pendingPaths);
    _pendingPaths.clear();
    for (final path in pathsToEmit) {
      _pathsController.add(path);
    }
  }

  static String? _normalizePath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('file://')) {
      try {
        return Uri.parse(trimmed).toFilePath();
      } catch (_) {
        return null;
      }
    }
    return trimmed;
  }

  static bool _isSupportedBookPath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.pdf') || lower.endsWith('.dpdf');
  }
}
