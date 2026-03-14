import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdfrx/pdfrx.dart'; // Import pdfrx for initialization
import 'data/database.dart';
import 'providers.dart';
import 'ui/screens/home_screen.dart';
import 'services/settings_service.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize pdfrx
  // Required when using engine APIs (like PdfDocument.openFile) before widgets are built.
  pdfrxFlutterInitialize();
  
  final objectBox = await ObjectBox.create();
  final prefs = await SharedPreferences.getInstance();

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      theme: ThemeData(
        useMaterial3: true,
        // Humanist Color Scheme
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF8C3B3B), // Deep Academy Red
          onPrimary: Colors.white,
          secondary: Color(0xFF5D6D7E), // Slate Blue
          onSecondary: Colors.white,
          error: Color(0xFFBA1A1A),
          onError: Colors.white,
          surface: Color(0xFFFDFCF8), // Parchment White
          onSurface: Color(0xFF1C1B1F),
        ),
        // Serif Typography
        fontFamily: 'Noto Serif SC', // Assuming system font or asset font. 
        // Ideally should add google_fonts package and use GoogleFonts.notoSerifSc()
        // But prompt said "configure fontFamily in ThemeData".
        // Let's use GoogleFonts if available, or just string if user has it.
        // We added google_fonts package earlier.
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
      ),
      home: const HomeScreen(),
    );
  }
}
