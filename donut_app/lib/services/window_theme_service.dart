import 'package:flutter/services.dart';

import 'settings_service.dart';

class WindowThemeService {
  WindowThemeService._();

  static const MethodChannel _channel = MethodChannel('donut/window_theme');

  static Future<void> applyThemeMode(AppThemeMode mode) async {
    try {
      await _channel.invokeMethod<void>('setThemeMode', mode.name);
    } on MissingPluginException {
      // Non-macOS platforms may not implement this channel.
    } catch (_) {
      // Keep UI resilient even if native sync fails.
    }
  }
}
