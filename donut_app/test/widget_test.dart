import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_reader/l10n/app_localizations.dart';
import 'package:pdf_reader/services/settings_service.dart';
import 'package:pdf_reader/ui/screens/settings_screen.dart';

void main() {
  testWidgets('Settings screen groups settings into sub menus', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingsScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('AI Configuration'), findsOneWidget);
    expect(find.text('Reader'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Data & Legal'), findsOneWidget);

    await tester.tap(find.text('AI Configuration'));
    await tester.pumpAndSettle();

    expect(find.text('Model Reply Length'), findsOneWidget);
    expect(find.text('Unlimited'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    expect(find.text('Theme Mode'), findsOneWidget);
    expect(find.text('Reading Direction'), findsOneWidget);
  });
}
