import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DebugLogService {
  DebugLogService._();

  static File? _logFile;
  static bool _initialized = false;
  static final List<String> _pendingLines = <String>[];
  static Future<void> _writeQueue = Future<void>.value();

  static Future<void> initialize() async {
    if (_initialized) return;
    final appSupportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appSupportDir.path, 'logs'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _logFile = File(p.join(dir.path, 'donut_debug.log'));
    _initialized = true;
    if (_pendingLines.isNotEmpty) {
      final lines = List<String>.from(_pendingLines);
      _pendingLines.clear();
      await _enqueueWrite('${lines.join('\n')}\n');
    }
  }

  static Future<String> getLogFilePath() async {
    if (!_initialized) {
      await initialize();
    }
    return _logFile!.path;
  }

  static Future<void> log(String message, {String tag = 'APP'}) async {
    final ts = DateTime.now().toIso8601String();
    final safeMessage = message.replaceAll('\n', r'\n');
    final line = '[$ts][$tag] $safeMessage';
    if (!_initialized || _logFile == null) {
      _pendingLines.add(line);
      return;
    }
    await _enqueueWrite('$line\n');
  }

  static Future<void> _enqueueWrite(String text) {
    _writeQueue = _writeQueue.then((_) => _appendRaw(text));
    return _writeQueue;
  }

  static Future<void> _appendRaw(String text) async {
    try {
      await _logFile!.writeAsString(text, mode: FileMode.append, flush: true);
    } catch (_) {
      // Keep logging best-effort and never crash app flow.
    }
  }
}
