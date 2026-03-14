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
  String get apiBaseUrl => 'API Base URL';

  @override
  String get deleteBook => 'Delete Book';

  @override
  String get resetAiData => 'Reset AI Data';

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
}
