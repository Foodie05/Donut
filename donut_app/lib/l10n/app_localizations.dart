import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @bookshelf.
  ///
  /// In en, this message translates to:
  /// **'Bookshelf'**
  String get bookshelf;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @reader.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get reader;

  /// No description provided for @modelName.
  ///
  /// In en, this message translates to:
  /// **'Model Name'**
  String get modelName;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKey;

  /// No description provided for @readingDirection.
  ///
  /// In en, this message translates to:
  /// **'Reading Direction'**
  String get readingDirection;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get followSystem;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkMode;

  /// No description provided for @horizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get horizontal;

  /// No description provided for @vertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get vertical;

  /// No description provided for @debounceDelay.
  ///
  /// In en, this message translates to:
  /// **'Debounce Delay'**
  String get debounceDelay;

  /// No description provided for @autoGenerate.
  ///
  /// In en, this message translates to:
  /// **'Auto-Generate Summary'**
  String get autoGenerate;

  /// No description provided for @autoGenerateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically analyze page content when reading'**
  String get autoGenerateSubtitle;

  /// No description provided for @debounceDelaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate summary after {seconds}s on new page'**
  String debounceDelaySubtitle(Object seconds);

  /// No description provided for @regenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get regenerate;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @pageSummary.
  ///
  /// In en, this message translates to:
  /// **'Page Summary'**
  String get pageSummary;

  /// No description provided for @noSummary.
  ///
  /// In en, this message translates to:
  /// **'No summary available'**
  String get noSummary;

  /// No description provided for @closePanel.
  ///
  /// In en, this message translates to:
  /// **'Close Panel'**
  String get closePanel;

  /// No description provided for @regenerateSummary.
  ///
  /// In en, this message translates to:
  /// **'Regenerate Summary'**
  String get regenerateSummary;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: '**
  String get errorPrefix;

  /// No description provided for @aiSummary.
  ///
  /// In en, this message translates to:
  /// **'AI Summary'**
  String get aiSummary;

  /// No description provided for @analyzePrompt.
  ///
  /// In en, this message translates to:
  /// **'Analyze this PDF page content. Provide a concise summary in Markdown.'**
  String get analyzePrompt;

  /// No description provided for @systemPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are a helpful AI assistant in a PDF Reader application. You have access to the current page image and its summary. Answer the user\'s questions based on this context.'**
  String get systemPrompt;

  /// No description provided for @apiKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'API Key not configured'**
  String get apiKeyMissing;

  /// No description provided for @aiRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'AI Request Failed: '**
  String get aiRequestFailed;

  /// No description provided for @enterMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter message...'**
  String get enterMessage;

  /// No description provided for @pageIndicator.
  ///
  /// In en, this message translates to:
  /// **'{current}/{total}'**
  String pageIndicator(Object current, Object total);

  /// No description provided for @noBooks.
  ///
  /// In en, this message translates to:
  /// **'No books added yet'**
  String get noBooks;

  /// No description provided for @addPdf.
  ///
  /// In en, this message translates to:
  /// **'Add PDF'**
  String get addPdf;

  /// No description provided for @errorAddingBook.
  ///
  /// In en, this message translates to:
  /// **'Error adding book: '**
  String get errorAddingBook;

  /// No description provided for @aiConfiguration.
  ///
  /// In en, this message translates to:
  /// **'AI Configuration'**
  String get aiConfiguration;

  /// No description provided for @aiCategorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure model, endpoint, API key, and reply length'**
  String get aiCategorySubtitle;

  /// No description provided for @apiBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'API Base URL'**
  String get apiBaseUrl;

  /// No description provided for @modelReplyLength.
  ///
  /// In en, this message translates to:
  /// **'Model Reply Length'**
  String get modelReplyLength;

  /// No description provided for @modelReplyLengthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set a response cap to save tokens, but the result may be incomplete.'**
  String get modelReplyLengthSubtitle;

  /// No description provided for @modelReplyLengthShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get modelReplyLengthShort;

  /// No description provided for @modelReplyLengthMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get modelReplyLengthMedium;

  /// No description provided for @modelReplyLengthLong.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get modelReplyLengthLong;

  /// No description provided for @modelReplyLengthUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get modelReplyLengthUnlimited;

  /// No description provided for @deleteBook.
  ///
  /// In en, this message translates to:
  /// **'Delete Book'**
  String get deleteBook;

  /// No description provided for @resetAiData.
  ///
  /// In en, this message translates to:
  /// **'Reset AI Data'**
  String get resetAiData;

  /// No description provided for @deleteBookWarning.
  ///
  /// In en, this message translates to:
  /// **'Deleting will remove this book file, cover, and related AI data. This action cannot be undone.'**
  String get deleteBookWarning;

  /// No description provided for @resetAiDataWarning.
  ///
  /// In en, this message translates to:
  /// **'Resetting will clear all summaries and chat records for this book. This action cannot be undone.'**
  String get resetAiDataWarning;

  /// No description provided for @resetAiDataDone.
  ///
  /// In en, this message translates to:
  /// **'AI data for this book has been reset'**
  String get resetAiDataDone;

  /// No description provided for @exportBookFile.
  ///
  /// In en, this message translates to:
  /// **'Export File'**
  String get exportBookFile;

  /// No description provided for @exportFormatPdfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read this book in any PDF software'**
  String get exportFormatPdfSubtitle;

  /// No description provided for @exportFormatDpdfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share your AI content and chat history with others'**
  String get exportFormatDpdfSubtitle;

  /// No description provided for @exportBookFileSuccess.
  ///
  /// In en, this message translates to:
  /// **'Export completed'**
  String get exportBookFileSuccess;

  /// No description provided for @exportBookFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed. Please check write permission at destination.'**
  String get exportBookFileFailed;

  /// No description provided for @duplicateBookTitle.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Book'**
  String get duplicateBookTitle;

  /// No description provided for @duplicateBookMessage.
  ///
  /// In en, this message translates to:
  /// **'This book appears to be the same as \"{title}\" (same file hash). Import again anyway?'**
  String duplicateBookMessage(Object title);

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @nav_statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get nav_statistics;

  /// No description provided for @readingTime.
  ///
  /// In en, this message translates to:
  /// **'Reading Time'**
  String get readingTime;

  /// No description provided for @readingFrequency.
  ///
  /// In en, this message translates to:
  /// **'Reading Frequency'**
  String get readingFrequency;

  /// No description provided for @topBooks.
  ///
  /// In en, this message translates to:
  /// **'Top Books'**
  String get topBooks;

  /// No description provided for @noReadingData.
  ///
  /// In en, this message translates to:
  /// **'No reading data yet.'**
  String get noReadingData;

  /// No description provided for @startReading.
  ///
  /// In en, this message translates to:
  /// **'Start Reading'**
  String get startReading;

  /// No description provided for @exploreBookshelf.
  ///
  /// In en, this message translates to:
  /// **'Explore Bookshelf'**
  String get exploreBookshelf;

  /// No description provided for @hourShort.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get hourShort;

  /// No description provided for @minuteShort.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get minuteShort;

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goal;

  /// No description provided for @pseudoKBMode.
  ///
  /// In en, this message translates to:
  /// **'Pseudo-Knowledge Base Mode'**
  String get pseudoKBMode;

  /// No description provided for @pseudoKBModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Include previous 2 pages for better context'**
  String get pseudoKBModeSubtitle;

  /// No description provided for @smoothSummary.
  ///
  /// In en, this message translates to:
  /// **'Smooth Summary'**
  String get smoothSummary;

  /// No description provided for @smoothSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'When the AI panel is open, pre-generate the next page summary in advance'**
  String get smoothSummarySubtitle;

  /// No description provided for @powerSavingMode.
  ///
  /// In en, this message translates to:
  /// **'Power Saving Mode'**
  String get powerSavingMode;

  /// No description provided for @powerSavingModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When the AI panel is closed, don\'t start new summary tasks or countdowns'**
  String get powerSavingModeSubtitle;

  /// No description provided for @summaryProfiles.
  ///
  /// In en, this message translates to:
  /// **'Summary Profiles'**
  String get summaryProfiles;

  /// No description provided for @createProfile.
  ///
  /// In en, this message translates to:
  /// **'Create Profile'**
  String get createProfile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get viewProfile;

  /// No description provided for @deleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Delete Profile'**
  String get deleteProfile;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Profile Name'**
  String get profileName;

  /// No description provided for @promptTemplate.
  ///
  /// In en, this message translates to:
  /// **'Prompt Template'**
  String get promptTemplate;

  /// No description provided for @copyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Copy Prompt'**
  String get copyPrompt;

  /// No description provided for @promptCopied.
  ///
  /// In en, this message translates to:
  /// **'Prompt copied'**
  String get promptCopied;

  /// No description provided for @defaultSummaryProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Built-in default prompt, read-only'**
  String get defaultSummaryProfileSubtitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @multiPageContext.
  ///
  /// In en, this message translates to:
  /// **'Multi-page Context Active'**
  String get multiPageContext;

  /// No description provided for @dataAndLegal.
  ///
  /// In en, this message translates to:
  /// **'Data & Legal'**
  String get dataAndLegal;

  /// No description provided for @readerCategorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage summaries, context options, and reading assists'**
  String get readerCategorySubtitle;

  /// No description provided for @appearanceCategorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust theme and reading direction display'**
  String get appearanceCategorySubtitle;

  /// No description provided for @dataLegalCategorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import/export settings and review legal/open-source docs'**
  String get dataLegalCategorySubtitle;

  /// No description provided for @importSettings.
  ///
  /// In en, this message translates to:
  /// **'Import Settings'**
  String get importSettings;

  /// No description provided for @importSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import configurable options from a JSON file'**
  String get importSettingsSubtitle;

  /// No description provided for @exportSettings.
  ///
  /// In en, this message translates to:
  /// **'Export Settings'**
  String get exportSettings;

  /// No description provided for @exportSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export current settings to a JSON file'**
  String get exportSettingsSubtitle;

  /// No description provided for @settingsHistory.
  ///
  /// In en, this message translates to:
  /// **'Settings History'**
  String get settingsHistory;

  /// No description provided for @settingsHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'View recent 10 snapshots and roll back quickly'**
  String get settingsHistorySubtitle;

  /// No description provided for @settingsHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No history snapshots yet'**
  String get settingsHistoryEmpty;

  /// No description provided for @settingsHistoryRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Settings restored from history'**
  String get settingsHistoryRestoreSuccess;

  /// No description provided for @settingsHistoryRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed. Please verify the snapshot file.'**
  String get settingsHistoryRestoreFailed;

  /// No description provided for @pickSettingsJson.
  ///
  /// In en, this message translates to:
  /// **'Pick settings JSON file'**
  String get pickSettingsJson;

  /// No description provided for @saveSettingsJson.
  ///
  /// In en, this message translates to:
  /// **'Save settings JSON file'**
  String get saveSettingsJson;

  /// No description provided for @importSettingsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Settings imported successfully'**
  String get importSettingsSuccess;

  /// No description provided for @importSettingsInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'Import failed: invalid JSON format'**
  String get importSettingsInvalidJson;

  /// No description provided for @importSettingsInvalidStructure.
  ///
  /// In en, this message translates to:
  /// **'Import failed: invalid configuration structure'**
  String get importSettingsInvalidStructure;

  /// No description provided for @importSettingsIoError.
  ///
  /// In en, this message translates to:
  /// **'Import failed: unable to read file'**
  String get importSettingsIoError;

  /// No description provided for @exportSettingsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Settings exported successfully'**
  String get exportSettingsSuccess;

  /// No description provided for @exportSettingsIoError.
  ///
  /// In en, this message translates to:
  /// **'Export failed: unable to write file'**
  String get exportSettingsIoError;

  /// No description provided for @exportDebugLogs.
  ///
  /// In en, this message translates to:
  /// **'Extract Debug Logs'**
  String get exportDebugLogs;

  /// No description provided for @exportDebugLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export file-open/import trace logs for troubleshooting'**
  String get exportDebugLogsSubtitle;

  /// No description provided for @saveDebugLog.
  ///
  /// In en, this message translates to:
  /// **'Save debug log'**
  String get saveDebugLog;

  /// No description provided for @exportDebugLogsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Debug logs exported successfully'**
  String get exportDebugLogsSuccess;

  /// No description provided for @exportDebugLogsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export debug logs'**
  String get exportDebugLogsFailed;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Donut Terms of Service'**
  String get termsOfService;

  /// No description provided for @termsOfServiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View the full Donut Terms of Service'**
  String get termsOfServiceSubtitle;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'View the full Donut Privacy Policy'**
  String get privacyPolicySubtitle;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get openSourceLicenses;

  /// No description provided for @openSourceLicensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View third-party open source licenses used by this app'**
  String get openSourceLicensesSubtitle;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Donut!'**
  String get welcomeTitle;

  /// No description provided for @welcomeMessageLine1.
  ///
  /// In en, this message translates to:
  /// **'Read your PDFs with ease and discover insights and inspiration.'**
  String get welcomeMessageLine1;

  /// No description provided for @welcomeMessageLine2.
  ///
  /// In en, this message translates to:
  /// **'Chat with models and unlock new ideas.'**
  String get welcomeMessageLine2;

  /// No description provided for @welcomeMessageLine3.
  ///
  /// In en, this message translates to:
  /// **'Please read and agree to the Terms and Privacy Policy first.'**
  String get welcomeMessageLine3;

  /// No description provided for @currentVersionBeta.
  ///
  /// In en, this message translates to:
  /// **'Current version: {version} beta'**
  String currentVersionBeta(Object version);

  /// No description provided for @agreementCheckboxLabel.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the Donut Terms of Service and Privacy Policy'**
  String get agreementCheckboxLabel;

  /// No description provided for @viewTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'View Terms of Service'**
  String get viewTermsOfService;

  /// No description provided for @viewPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'View Privacy Policy'**
  String get viewPrivacyPolicy;

  /// No description provided for @agreementRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Agreement Required'**
  String get agreementRequiredTitle;

  /// No description provided for @agreementRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Please review and agree to the Terms and Privacy Policy to continue using Donut.'**
  String get agreementRequiredBody;

  /// No description provided for @releaseNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Release Notes'**
  String get releaseNotesTitle;

  /// No description provided for @noReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'No release notes available.'**
  String get noReleaseNotes;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
