import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_service.g.dart';

@riverpod
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError(); // Override in main
}

enum ReadingDirection { vertical, horizontal }
enum AppThemeMode { system, light, dark }

const String defaultSummaryProfileId = 'default_summary';
const String defaultSummaryPrompt = 'Analyze this PDF page content. Provide a concise summary in Markdown.';

class SummaryProfile {
  final String id;
  final String name;
  final String prompt;
  final bool isBuiltIn;

  const SummaryProfile({
    required this.id,
    required this.name,
    required this.prompt,
    this.isBuiltIn = false,
  });

  static const defaultProfile = SummaryProfile(
    id: defaultSummaryProfileId,
    name: '默认摘要',
    prompt: defaultSummaryPrompt,
    isBuiltIn: true,
  );

  factory SummaryProfile.fromJson(Map<String, dynamic> json) {
    return SummaryProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      prompt: json['prompt'] as String,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'prompt': prompt,
      'isBuiltIn': isBuiltIn,
    };
  }

  SummaryProfile copyWith({
    String? id,
    String? name,
    String? prompt,
    bool? isBuiltIn,
  }) {
    return SummaryProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      prompt: prompt ?? this.prompt,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }
}

@riverpod
class Settings extends _$Settings {
  @override
  SettingsModel build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final directionIndex = prefs.getInt('reading_direction') ?? 0;
    final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
    final customProfiles = _loadCustomProfiles(prefs);
    final summaryProfiles = [SummaryProfile.defaultProfile, ...customProfiles];
    final selectedSummaryProfileId =
        prefs.getString('selected_summary_profile_id') ?? defaultSummaryProfileId;
    final resolvedSummaryProfileId = summaryProfiles.any((profile) => profile.id == selectedSummaryProfileId)
        ? selectedSummaryProfileId
        : defaultSummaryProfileId;
    
    return SettingsModel(
      apiKey: prefs.getString('api_key') ?? '',
      baseUrl: prefs.getString('base_url') ?? '',
      modelName: prefs.getString('model_name') ?? 'gpt-4-vision-preview',
      autoGenerate: prefs.getBool('auto_generate') ?? true,
      enablePseudoKBMode: prefs.getBool('enable_pseudo_kb_mode') ?? false,
      smoothSummary: prefs.getBool('smooth_summary') ?? true,
      powerSavingMode: prefs.getBool('power_saving_mode') ?? true,
      debounceSeconds: prefs.getInt('debounce_seconds') ?? 3,
      readingDirection: ReadingDirection.values[directionIndex],
      themeMode: AppThemeMode.values[themeModeIndex],
      summaryProfiles: summaryProfiles,
      selectedSummaryProfileId: resolvedSummaryProfileId,
    );
  }

  List<SummaryProfile> _loadCustomProfiles(SharedPreferences prefs) {
    final raw = prefs.getString('summary_profiles');
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => SummaryProfile.fromJson(item as Map<String, dynamic>))
          .where((profile) => profile.id != defaultSummaryProfileId)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  void _persistCustomProfiles(List<SummaryProfile> profiles) {
    final customProfiles = profiles.where((profile) => !profile.isBuiltIn).toList();
    final encoded = jsonEncode(customProfiles.map((profile) => profile.toJson()).toList());
    ref.read(sharedPreferencesProvider).setString('summary_profiles', encoded);
  }

  void setApiKey(String value) {
    ref.read(sharedPreferencesProvider).setString('api_key', value);
    state = state.copyWith(apiKey: value);
  }

  void setBaseUrl(String value) {
    ref.read(sharedPreferencesProvider).setString('base_url', value);
    state = state.copyWith(baseUrl: value);
  }

  void setModelName(String value) {
    ref.read(sharedPreferencesProvider).setString('model_name', value);
    state = state.copyWith(modelName: value);
  }
  
  void setAutoGenerate(bool value) {
    ref.read(sharedPreferencesProvider).setBool('auto_generate', value);
    state = state.copyWith(autoGenerate: value);
  }

  void setEnablePseudoKBMode(bool value) {
    ref.read(sharedPreferencesProvider).setBool('enable_pseudo_kb_mode', value);
    state = state.copyWith(enablePseudoKBMode: value);
  }

  void setSmoothSummary(bool value) {
    ref.read(sharedPreferencesProvider).setBool('smooth_summary', value);
    state = state.copyWith(smoothSummary: value);
  }

  void setPowerSavingMode(bool value) {
    ref.read(sharedPreferencesProvider).setBool('power_saving_mode', value);
    state = state.copyWith(powerSavingMode: value);
  }

  void setReadingDirection(ReadingDirection direction) {
    ref.read(sharedPreferencesProvider).setInt('reading_direction', direction.index);
    state = state.copyWith(readingDirection: direction);
  }

  void setThemeMode(AppThemeMode mode) {
    ref.read(sharedPreferencesProvider).setInt('theme_mode', mode.index);
    state = state.copyWith(themeMode: mode);
  }

  void setSelectedSummaryProfile(String profileId) {
    ref.read(sharedPreferencesProvider).setString('selected_summary_profile_id', profileId);
    state = state.copyWith(selectedSummaryProfileId: profileId);
  }

  void addSummaryProfile({
    required String name,
    required String prompt,
  }) {
    final profile = SummaryProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      prompt: prompt,
    );
    final profiles = [...state.summaryProfiles, profile];
    _persistCustomProfiles(profiles);
    ref.read(sharedPreferencesProvider).setString('selected_summary_profile_id', profile.id);
    state = state.copyWith(
      summaryProfiles: profiles,
      selectedSummaryProfileId: profile.id,
    );
  }

  void updateSummaryProfile(SummaryProfile profile) {
    if (profile.isBuiltIn || profile.id == defaultSummaryProfileId) return;

    final profiles = [
      for (final item in state.summaryProfiles)
        if (item.id == profile.id) profile else item,
    ];
    _persistCustomProfiles(profiles);
    state = state.copyWith(summaryProfiles: profiles);
  }

  void deleteSummaryProfile(String profileId) {
    if (profileId == defaultSummaryProfileId) return;

    final profiles = state.summaryProfiles.where((profile) => profile.id != profileId).toList();
    _persistCustomProfiles(profiles);

    final selectedSummaryProfileId = state.selectedSummaryProfileId == profileId
        ? defaultSummaryProfileId
        : state.selectedSummaryProfileId;
    ref.read(sharedPreferencesProvider).setString('selected_summary_profile_id', selectedSummaryProfileId);

    state = state.copyWith(
      summaryProfiles: profiles,
      selectedSummaryProfileId: selectedSummaryProfileId,
    );
  }

  void setDebounceSeconds(int value) {
    ref.read(sharedPreferencesProvider).setInt('debounce_seconds', value);
    state = state.copyWith(debounceSeconds: value);
  }
}

class SettingsModel {
  final String apiKey;
  final String baseUrl;
  final String modelName;
  final bool autoGenerate;
  final bool enablePseudoKBMode;
  final bool smoothSummary;
  final bool powerSavingMode;
  final int debounceSeconds;
  final ReadingDirection readingDirection;
  final AppThemeMode themeMode;
  final List<SummaryProfile> summaryProfiles;
  final String selectedSummaryProfileId;

  SettingsModel({
    required this.apiKey,
    required this.baseUrl,
    required this.modelName,
    required this.autoGenerate,
    required this.enablePseudoKBMode,
    required this.smoothSummary,
    required this.powerSavingMode,
    required this.debounceSeconds,
    required this.readingDirection,
    required this.themeMode,
    required this.summaryProfiles,
    required this.selectedSummaryProfileId,
  });

  SummaryProfile get selectedSummaryProfile {
    return summaryProfiles.firstWhere(
      (profile) => profile.id == selectedSummaryProfileId,
      orElse: () => SummaryProfile.defaultProfile,
    );
  }

  SummaryProfile profileById(String profileId) {
    return summaryProfiles.firstWhere(
      (profile) => profile.id == profileId,
      orElse: () => SummaryProfile.defaultProfile,
    );
  }

  SettingsModel copyWith({
    String? apiKey,
    String? baseUrl,
    String? modelName,
    bool? autoGenerate,
    bool? enablePseudoKBMode,
    bool? smoothSummary,
    bool? powerSavingMode,
    int? debounceSeconds,
    ReadingDirection? readingDirection,
    AppThemeMode? themeMode,
    List<SummaryProfile>? summaryProfiles,
    String? selectedSummaryProfileId,
  }) {
    return SettingsModel(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      modelName: modelName ?? this.modelName,
      autoGenerate: autoGenerate ?? this.autoGenerate,
      enablePseudoKBMode: enablePseudoKBMode ?? this.enablePseudoKBMode,
      smoothSummary: smoothSummary ?? this.smoothSummary,
      powerSavingMode: powerSavingMode ?? this.powerSavingMode,
      debounceSeconds: debounceSeconds ?? this.debounceSeconds,
      readingDirection: readingDirection ?? this.readingDirection,
      themeMode: themeMode ?? this.themeMode,
      summaryProfiles: summaryProfiles ?? this.summaryProfiles,
      selectedSummaryProfileId: selectedSummaryProfileId ?? this.selectedSummaryProfileId,
    );
  }
}
