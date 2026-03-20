import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdfrx/pdfrx.dart'; // Import pdfrx for initialization
import 'data/database.dart';
import 'data/repositories/book_repository.dart';
import 'providers.dart';
import 'services/debug_log_service.dart';
import 'services/external_file_open_service.dart';
import 'services/window_theme_service.dart';
import 'ui/screens/home_screen.dart';
import 'services/settings_service.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize pdfrx
  // Required when using engine APIs (like PdfDocument.openFile) before widgets are built.
  pdfrxFlutterInitialize();

  final objectBox = await ObjectBox.create();
  final prefs = await SharedPreferences.getInstance();
  await DebugLogService.initialize();
  await DebugLogService.log('App start args: ${args.join(' | ')}', tag: 'BOOT');
  await restoreSettingsFromBackupIfNeeded(prefs);
  await ExternalFileOpenService.initialize(args);
  await BookRepository(objectBox.store).migrateLegacyBooksToDpdf();

  runApp(
    ProviderScope(
      overrides: [
        objectBoxProvider.overrideWithValue(objectBox),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  AppThemeMode? _lastSyncedThemeMode;

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? const Color(0xFFE0AFA0) : const Color(0xFF8C3B3B),
      onPrimary: isDark ? const Color(0xFF40211E) : Colors.white,
      secondary: isDark ? const Color(0xFFB8C4D4) : const Color(0xFF5D6D7E),
      onSecondary: isDark ? const Color(0xFF203040) : Colors.white,
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: isDark ? const Color(0xFF181614) : const Color(0xFFFDFCF8),
      onSurface: isDark ? const Color(0xFFF4EFE8) : const Color(0xFF1C1B1F),
      surfaceContainerLowest: isDark
          ? const Color(0xFF141210)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: isDark
          ? const Color(0xFF1E1B19)
          : const Color(0xFFF7F3EE),
      surfaceContainer: isDark
          ? const Color(0xFF24211E)
          : const Color(0xFFF1ECE4),
      surfaceContainerHigh: isDark
          ? const Color(0xFF2D2926)
          : const Color(0xFFEAE2D7),
      surfaceContainerHighest: isDark
          ? const Color(0xFF38332F)
          : const Color(0xFFE2D8CA),
      outline: isDark ? const Color(0xFF958D84) : const Color(0xFF7A6F66),
      outlineVariant: isDark
          ? const Color(0xFF4F4943)
          : const Color(0xFFD2C5B8),
      onSurfaceVariant: isDark
          ? const Color(0xFFD9CFC5)
          : const Color(0xFF4C4540),
      primaryContainer: isDark
          ? const Color(0xFF5C302C)
          : const Color(0xFFF7DCD5),
      onPrimaryContainer: isDark
          ? const Color(0xFFFFDAD2)
          : const Color(0xFF3C1210),
      secondaryContainer: isDark
          ? const Color(0xFF384250)
          : const Color(0xFFDAE2F0),
      onSecondaryContainer: isDark
          ? const Color(0xFFDDE8F8)
          : const Color(0xFF16212C),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Noto Serif SC',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Noto Serif SC'),
        displayMedium: TextStyle(fontFamily: 'Noto Serif SC'),
        displaySmall: TextStyle(fontFamily: 'Noto Serif SC'),
        headlineLarge: TextStyle(fontFamily: 'Noto Serif SC'),
        headlineMedium: TextStyle(fontFamily: 'Noto Serif SC'),
        headlineSmall: TextStyle(fontFamily: 'Noto Serif SC'),
        titleLarge: TextStyle(fontFamily: 'Noto Serif SC'),
        titleMedium: TextStyle(fontFamily: 'Noto Serif SC'),
        titleSmall: TextStyle(fontFamily: 'Noto Serif SC'),
        bodyLarge: TextStyle(fontFamily: 'Noto Serif SC'),
        bodyMedium: TextStyle(fontFamily: 'Noto Serif SC'),
        bodySmall: TextStyle(fontFamily: 'Noto Serif SC'),
        labelLarge: TextStyle(fontFamily: 'Noto Serif SC'),
        labelMedium: TextStyle(fontFamily: 'Noto Serif SC'),
        labelSmall: TextStyle(fontFamily: 'Noto Serif SC'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    if (_lastSyncedThemeMode != settings.themeMode) {
      _lastSyncedThemeMode = settings.themeMode;
      unawaited(WindowThemeService.applyThemeMode(settings.themeMode));
    }

    final themeMode = switch (settings.themeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

    return MaterialApp(
      title: 'Vision PDF Reader',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('zh'), // Chinese
      ],
      themeMode: themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
