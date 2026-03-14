import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_service.g.dart';

@riverpod
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError(); // Override in main
}

enum ReadingDirection { vertical, horizontal }

@riverpod
class Settings extends _$Settings {
  @override
  SettingsModel build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final directionIndex = prefs.getInt('reading_direction') ?? 0;
    
    return SettingsModel(
      apiKey: prefs.getString('api_key') ?? '',
      baseUrl: prefs.getString('base_url') ?? '',
      modelName: prefs.getString('model_name') ?? 'gpt-4-vision-preview',
      autoGenerate: prefs.getBool('auto_generate') ?? true,
      enablePseudoKBMode: prefs.getBool('enable_pseudo_kb_mode') ?? false,
      debounceSeconds: prefs.getInt('debounce_seconds') ?? 3,
      readingDirection: ReadingDirection.values[directionIndex],
    );
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

  void setReadingDirection(ReadingDirection direction) {
    ref.read(sharedPreferencesProvider).setInt('reading_direction', direction.index);
    state = state.copyWith(readingDirection: direction);
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
  final int debounceSeconds;
  final ReadingDirection readingDirection;

  SettingsModel({
    required this.apiKey,
    required this.baseUrl,
    required this.modelName,
    required this.autoGenerate,
    required this.enablePseudoKBMode,
    required this.debounceSeconds,
    required this.readingDirection,
  });

  SettingsModel copyWith({
    String? apiKey,
    String? baseUrl,
    String? modelName,
    bool? autoGenerate,
    bool? enablePseudoKBMode,
    int? debounceSeconds,
    ReadingDirection? readingDirection,
  }) {
    return SettingsModel(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      modelName: modelName ?? this.modelName,
      autoGenerate: autoGenerate ?? this.autoGenerate,
      enablePseudoKBMode: enablePseudoKBMode ?? this.enablePseudoKBMode,
      debounceSeconds: debounceSeconds ?? this.debounceSeconds,
      readingDirection: readingDirection ?? this.readingDirection,
    );
  }
}
