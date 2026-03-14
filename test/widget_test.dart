import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_reader/l10n/app_localizations.dart';
import 'package:pdf_reader/services/settings_service.dart';
import 'package:pdf_reader/ui/screens/settings_screen.dart';

void main() {
  testWidgets('Settings screen shows theme and summary options', (WidgetTester tester) async {
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
    expect(find.text('Reader'), findsOneWidget);
    expect(find.text('Summary Profiles'), findsOneWidget);
    expect(find.text('Smooth Summary'), findsOneWidget);
    expect(find.text('Power Saving Mode'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Theme Mode'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Theme Mode'), findsOneWidget);
    expect(find.text('Reading Direction'), findsOneWidget);
  });
}
