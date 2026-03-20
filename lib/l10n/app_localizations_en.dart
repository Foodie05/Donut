// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get bookshelf => 'Bookshelf';

  @override
  String get settings => 'Settings';

  @override
  String get reader => 'Reader';

  @override
  String get modelName => 'Model Name';

  @override
  String get apiKey => 'API Key';

  @override
  String get readingDirection => 'Reading Direction';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get followSystem => 'Follow System';

  @override
  String get lightMode => 'Light';

  @override
  String get darkMode => 'Dark';

  @override
  String get horizontal => 'Horizontal';

  @override
  String get vertical => 'Vertical';

  @override
  String get debounceDelay => 'Debounce Delay';

  @override
  String get autoGenerate => 'Auto-Generate Summary';

  @override
  String get autoGenerateSubtitle => 'Automatically analyze page content when reading';

  @override
  String debounceDelaySubtitle(Object seconds) {
    return 'Generate summary after ${seconds}s on new page';
  }

  @override
  String get regenerate => 'Regenerate';

  @override
  String get summary => 'Summary';

  @override
  String get chat => 'Chat';

  @override
  String get pageSummary => 'Page Summary';

  @override
  String get noSummary => 'No summary available';

  @override
  String get closePanel => 'Close Panel';

  @override
  String get regenerateSummary => 'Regenerate Summary';

  @override
  String get errorPrefix => 'Error: ';

  @override
  String get aiSummary => 'AI Summary';

  @override
  String get analyzePrompt => 'Analyze this PDF page content. Provide a concise summary in Markdown.';

  @override
  String get systemPrompt => 'You are a helpful AI assistant in a PDF Reader application. You have access to the current page image and its summary. Answer the user\'s questions based on this context.';

  @override
  String get apiKeyMissing => 'API Key not configured';

  @override
  String get aiRequestFailed => 'AI Request Failed: ';

  @override
  String get enterMessage => 'Enter message...';

  @override
  String pageIndicator(Object current, Object total) {
    return '$current/$total';
  }

  @override
  String get noBooks => 'No books added yet';

  @override
  String get addPdf => 'Add PDF';

  @override
  String get errorAddingBook => 'Error adding book: ';

  @override
  String get aiConfiguration => 'AI Configuration';

  @override
  String get aiCategorySubtitle => 'Configure model, endpoint, API key, and reply length';

  @override
  String get apiBaseUrl => 'API Base URL';

  @override
  String get modelReplyLength => 'Model Reply Length';

  @override
  String get modelReplyLengthSubtitle => 'Set a response cap to save tokens, but the result may be incomplete.';

  @override
  String get modelReplyLengthShort => 'Short';

  @override
  String get modelReplyLengthMedium => 'Medium';

  @override
  String get modelReplyLengthLong => 'Long';

  @override
  String get modelReplyLengthUnlimited => 'Unlimited';

  @override
  String get deleteBook => 'Delete Book';

  @override
  String get resetAiData => 'Reset AI Data';

  @override
  String get deleteBookWarning => 'Deleting will remove this book file, cover, and related AI data. This action cannot be undone.';

  @override
  String get resetAiDataWarning => 'Resetting will clear all summaries and chat records for this book. This action cannot be undone.';

  @override
  String get resetAiDataDone => 'AI data for this book has been reset';

  @override
  String get exportBookFile => 'Export File';

  @override
  String get exportFormatPdfSubtitle => 'Read this book in any PDF software';

  @override
  String get exportFormatDpdfSubtitle => 'Share your AI content and chat history with others';

  @override
  String get exportBookFileSuccess => 'Export completed';

  @override
  String get exportBookFileFailed => 'Export failed. Please check write permission at destination.';

  @override
  String get duplicateBookTitle => 'Duplicate Book';

  @override
  String duplicateBookMessage(Object title) {
    return 'This book appears to be the same as \"$title\" (same file hash). Import again anyway?';
  }

  @override
  String get statistics => 'Statistics';

  @override
  String get day => 'Day';

  @override
  String get week => 'Week';

  @override
  String get month => 'Month';

  @override
  String get year => 'Year';

  @override
  String get all => 'All';

  @override
  String get nav_statistics => 'Statistics';

  @override
  String get readingTime => 'Reading Time';

  @override
  String get readingFrequency => 'Reading Frequency';

  @override
  String get topBooks => 'Top Books';

  @override
  String get noReadingData => 'No reading data yet.';

  @override
  String get startReading => 'Start Reading';

  @override
  String get exploreBookshelf => 'Explore Bookshelf';

  @override
  String get hourShort => 'h';

  @override
  String get minuteShort => 'm';

  @override
  String get goal => 'Goal';

  @override
  String get pseudoKBMode => 'Pseudo-Knowledge Base Mode';

  @override
  String get pseudoKBModeSubtitle => 'Include previous 2 pages for better context';

  @override
  String get smoothSummary => 'Smooth Summary';

  @override
  String get smoothSummarySubtitle => 'When the AI panel is open, pre-generate the next page summary in advance';

  @override
  String get powerSavingMode => 'Power Saving Mode';

  @override
  String get powerSavingModeSubtitle => 'When the AI panel is closed, don\'t start new summary tasks or countdowns';

  @override
  String get summaryProfiles => 'Summary Profiles';

  @override
  String get createProfile => 'Create Profile';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get viewProfile => 'View Profile';

  @override
  String get deleteProfile => 'Delete Profile';

  @override
  String get profileName => 'Profile Name';

  @override
  String get promptTemplate => 'Prompt Template';

  @override
  String get copyPrompt => 'Copy Prompt';

  @override
  String get promptCopied => 'Prompt copied';

  @override
  String get defaultSummaryProfileSubtitle => 'Built-in default prompt, read-only';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get multiPageContext => 'Multi-page Context Active';

  @override
  String get dataAndLegal => 'Data & Legal';

  @override
  String get readerCategorySubtitle => 'Manage summaries, context options, and reading assists';

  @override
  String get appearanceCategorySubtitle => 'Adjust theme and reading direction display';

  @override
  String get dataLegalCategorySubtitle => 'Import/export settings and review legal/open-source docs';

  @override
  String get importSettings => 'Import Settings';

  @override
  String get importSettingsSubtitle => 'Import configurable options from a JSON file';

  @override
  String get exportSettings => 'Export Settings';

  @override
  String get exportSettingsSubtitle => 'Export current settings to a JSON file';

  @override
  String get settingsHistory => 'Settings History';

  @override
  String get settingsHistorySubtitle => 'View recent 10 snapshots and roll back quickly';

  @override
  String get settingsHistoryEmpty => 'No history snapshots yet';

  @override
  String get settingsHistoryRestoreSuccess => 'Settings restored from history';

  @override
  String get settingsHistoryRestoreFailed => 'Restore failed. Please verify the snapshot file.';

  @override
  String get pickSettingsJson => 'Pick settings JSON file';

  @override
  String get saveSettingsJson => 'Save settings JSON file';

  @override
  String get importSettingsSuccess => 'Settings imported successfully';

  @override
  String get importSettingsInvalidJson => 'Import failed: invalid JSON format';

  @override
  String get importSettingsInvalidStructure => 'Import failed: invalid configuration structure';

  @override
  String get importSettingsIoError => 'Import failed: unable to read file';

  @override
  String get exportSettingsSuccess => 'Settings exported successfully';

  @override
  String get exportSettingsIoError => 'Export failed: unable to write file';

  @override
  String get exportDebugLogs => 'Extract Debug Logs';

  @override
  String get exportDebugLogsSubtitle => 'Export file-open/import trace logs for troubleshooting';

  @override
  String get saveDebugLog => 'Save debug log';

  @override
  String get exportDebugLogsSuccess => 'Debug logs exported successfully';

  @override
  String get exportDebugLogsFailed => 'Failed to export debug logs';

  @override
  String get termsOfService => 'Donut Terms of Service';

  @override
  String get termsOfServiceSubtitle => 'View the full Donut Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyPolicySubtitle => 'View the full Donut Privacy Policy';

  @override
  String get openSourceLicenses => 'Open Source Licenses';

  @override
  String get openSourceLicensesSubtitle => 'View third-party open source licenses used by this app';

  @override
  String get welcomeTitle => 'Welcome to Donut!';

  @override
  String get welcomeMessageLine1 => 'Read your PDFs with ease and discover insights and inspiration.';

  @override
  String get welcomeMessageLine2 => 'Chat with models and unlock new ideas.';

  @override
  String get welcomeMessageLine3 => 'Please read and agree to the Terms and Privacy Policy first.';

  @override
  String currentVersionBeta(Object version) {
    return 'Current version: $version beta';
  }

  @override
  String get agreementCheckboxLabel => 'I have read and agree to the Donut Terms of Service and Privacy Policy';

  @override
  String get viewTermsOfService => 'View Terms of Service';

  @override
  String get viewPrivacyPolicy => 'View Privacy Policy';

  @override
  String get agreementRequiredTitle => 'Agreement Required';

  @override
  String get agreementRequiredBody => 'Please review and agree to the Terms and Privacy Policy to continue using Donut.';

  @override
  String get releaseNotesTitle => 'Release Notes';

  @override
  String get noReleaseNotes => 'No release notes available.';

  @override
  String get confirm => 'Confirm';

  @override
  String get restore => 'Restore';
}
