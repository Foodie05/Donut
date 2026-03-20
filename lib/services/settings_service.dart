import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_service.g.dart';

@riverpod
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError(); // Override in main
}

enum ReadingDirection { vertical, horizontal }
enum AppThemeMode { system, light, dark }
enum ModelReplyLength {
  short(1000),
  medium(3500),
  long(6000),
  unlimited(null);

  const ModelReplyLength(this.maxTokens);

  final int? maxTokens;
}

enum SettingsImportError {
  invalidJson,
  invalidStructure,
  io,
}

class SettingsImportResult {
  final bool success;
  final SettingsImportError? error;

  const SettingsImportResult._(this.success, this.error);

  const SettingsImportResult.success() : this._(true, null);

  const SettingsImportResult.failure(SettingsImportError error)
      : this._(false, error);
}

class SettingsBackupEntry {
  final String filePath;
  final String fileName;
  final DateTime modifiedAt;

  const SettingsBackupEntry({
    required this.filePath,
    required this.fileName,
    required this.modifiedAt,
  });
}

const String defaultSummaryProfileId = 'default_summary';
const String defaultSummaryPrompt =
    'Analyze this PDF page content. Provide a concise summary in Markdown.';
const String fullTranslationProfileId = 'full_translation';
const String fullTranslationPrompt = '''
你是“逐字完整翻译器”。将当前 PDF 页面中你能看到的所有内容完整翻译为简体中文。

必须遵守：
1) 不得省略、跳过、合并、总结、改写任何信息。
2) 保持原文顺序与结构（标题、段落、列表、脚注、编号、标点、数字、单位、日期、公式、代码、URL、邮箱、专有名词）。
3) 每一行/每一项都要有对应译文，不得缺项。
4) 无法辨认处请在对应位置标注「[无法辨认]」。
5) 只输出译文本体，不要解释。
''';

const _prefApiKey = 'api_key';
const _prefBaseUrl = 'base_url';
const _prefModelName = 'model_name';
const _prefAutoGenerate = 'auto_generate';
const _prefEnablePseudoKBMode = 'enable_pseudo_kb_mode';
const _prefSmoothSummary = 'smooth_summary';
const _prefPowerSavingMode = 'power_saving_mode';
const _prefDebounceSeconds = 'debounce_seconds';
const _prefReadingDirection = 'reading_direction';
const _prefThemeMode = 'theme_mode';
const _prefModelReplyLength = 'model_reply_length';
const _prefSummaryProfiles = 'summary_profiles';
const _prefSelectedSummaryProfileId = 'selected_summary_profile_id';

const _backupSchemaVersion = 1;
const _settingsBackupFileName = 'settings_backup.json';
const _settingsHistoryDirName = 'settings_history';
const _settingsHistoryLimit = 10;

const Set<String> _supportedSettingsKeys = {
  'apiKey',
  'baseUrl',
  'modelName',
  'autoGenerate',
  'enablePseudoKBMode',
  'smoothSummary',
  'powerSavingMode',
  'debounceSeconds',
  'readingDirection',
  'themeMode',
  'modelReplyLength',
  'summaryProfiles',
  'selectedSummaryProfileId',
};

Future<String?> settingsBackupFilePath() async {
  try {
    final file = await _resolveSettingsBackupFile();
    return file.path;
  } catch (_) {
    return null;
  }
}

Future<void> restoreSettingsFromBackupIfNeeded(SharedPreferences prefs) async {
  if (prefs.getKeys().isNotEmpty) return;

  try {
    final backupFile = await _resolveSettingsBackupFile();
    if (!await backupFile.exists()) return;

    final raw = await backupFile.readAsString();
    final config = _parseSettingsPayload(raw);
    if (config == null) return;
    if (!_isSettingsStructureValid(config)) return;

    _writeConfigToPrefs(prefs, config);
  } catch (_) {
    // Ignore startup restore failures to avoid blocking app launch.
  }
}

Future<File> _resolveSettingsBackupFile() async {
  final supportDir = await getApplicationSupportDirectory();
  await supportDir.create(recursive: true);
  return File(path.join(supportDir.path, _settingsBackupFileName));
}

Future<Directory> _resolveSettingsHistoryDirectory() async {
  final supportDir = await getApplicationSupportDirectory();
  final historyDir = Directory(path.join(supportDir.path, _settingsHistoryDirName));
  await historyDir.create(recursive: true);
  return historyDir;
}

Map<String, dynamic>? _parseSettingsPayload(String raw) {
  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;

  final settingsNode = decoded['settings'];
  if (settingsNode is Map<String, dynamic>) return settingsNode;

  // Backward compatibility: support a direct settings object as root.
  return decoded;
}

String _stringValue(dynamic value, String fallback) {
  if (value is String) return value;
  return fallback;
}

bool _boolValue(dynamic value, bool fallback) {
  if (value is bool) return value;
  return fallback;
}

int _intValue(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

bool _isEnumName<T extends Enum>(dynamic value, List<T> values) {
  if (value is! String) return false;
  return values.any((item) => item.name == value);
}

bool _hasRecognizedSettingKey(Map<String, dynamic> config) {
  for (final key in config.keys) {
    if (_supportedSettingsKeys.contains(key)) return true;
  }
  return false;
}

bool _isSettingsStructureValid(Map<String, dynamic> config) {
  if (!_hasRecognizedSettingKey(config)) return false;

  final apiKey = config['apiKey'];
  if (apiKey != null && apiKey is! String) return false;
  final baseUrl = config['baseUrl'];
  if (baseUrl != null && baseUrl is! String) return false;
  final modelName = config['modelName'];
  if (modelName != null && modelName is! String) return false;

  final autoGenerate = config['autoGenerate'];
  if (autoGenerate != null && autoGenerate is! bool) return false;
  final enablePseudoKBMode = config['enablePseudoKBMode'];
  if (enablePseudoKBMode != null && enablePseudoKBMode is! bool) return false;
  final smoothSummary = config['smoothSummary'];
  if (smoothSummary != null && smoothSummary is! bool) return false;
  final powerSavingMode = config['powerSavingMode'];
  if (powerSavingMode != null && powerSavingMode is! bool) return false;

  final debounceSeconds = config['debounceSeconds'];
  if (debounceSeconds != null && debounceSeconds is! num) return false;

  final readingDirection = config['readingDirection'];
  if (readingDirection != null &&
      !_isEnumName(readingDirection, ReadingDirection.values)) {
    return false;
  }
  final themeMode = config['themeMode'];
  if (themeMode != null && !_isEnumName(themeMode, AppThemeMode.values)) {
    return false;
  }
  final modelReplyLength = config['modelReplyLength'];
  if (modelReplyLength != null &&
      !_isEnumName(modelReplyLength, ModelReplyLength.values)) {
    return false;
  }

  final selectedSummaryProfileId = config['selectedSummaryProfileId'];
  if (selectedSummaryProfileId != null && selectedSummaryProfileId is! String) {
    return false;
  }

  final summaryProfiles = config['summaryProfiles'];
  if (summaryProfiles != null) {
    if (summaryProfiles is! List) return false;
    for (final item in summaryProfiles) {
      if (item is! Map) return false;
      final profileMap = Map<String, dynamic>.from(item);

      final id = profileMap['id'];
      if (id != null && id is! String) return false;
      final name = profileMap['name'];
      if (name != null && name is! String) return false;
      final prompt = profileMap['prompt'];
      if (prompt != null && prompt is! String) return false;
      final isBuiltIn = profileMap['isBuiltIn'];
      if (isBuiltIn != null && isBuiltIn is! bool) return false;
    }
  }

  return true;
}

T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final item in values) {
    if (item.name == name) return item;
  }
  return fallback;
}

List<SummaryProfile> _parseCustomProfiles(dynamic value) {
  if (value is! List) return const [];
  final profiles = <SummaryProfile>[];
  for (final item in value) {
    if (item is! Map) continue;
    final id = item['id']?.toString().trim() ?? '';
    final name = item['name']?.toString().trim() ?? '';
    final prompt = item['prompt']?.toString() ?? '';
    if (id.isEmpty || name.isEmpty || prompt.trim().isEmpty) continue;
    if (id == defaultSummaryProfileId || id == fullTranslationProfileId) {
      continue;
    }
    profiles.add(
      SummaryProfile(
        id: id,
        name: name,
        prompt: prompt,
        isBuiltIn: false,
      ),
    );
  }
  return profiles;
}

SettingsModel _settingsFromConfig(Map<String, dynamic> config) {
  final customProfiles = _parseCustomProfiles(config['summaryProfiles']);
  final profiles = [
    SummaryProfile.defaultProfile,
    SummaryProfile.fullTranslationProfile,
    ...customProfiles,
  ];

  final selectedId = config['selectedSummaryProfileId'] is String
      ? (config['selectedSummaryProfileId'] as String).trim()
      : null;
  final resolvedSelectedId = profiles.any((item) => item.id == selectedId)
      ? selectedId!
      : defaultSummaryProfileId;

  return SettingsModel(
    apiKey: _stringValue(config['apiKey'], ''),
    baseUrl: _stringValue(config['baseUrl'], ''),
    modelName: _stringValue(config['modelName'], 'gpt-4-vision-preview'),
    autoGenerate: _boolValue(config['autoGenerate'], true),
    enablePseudoKBMode: _boolValue(config['enablePseudoKBMode'], false),
    smoothSummary: _boolValue(config['smoothSummary'], true),
    powerSavingMode: _boolValue(config['powerSavingMode'], true),
    debounceSeconds: _intValue(config['debounceSeconds'], 3),
    readingDirection: _enumFromName(
      ReadingDirection.values,
      config['readingDirection'] is String ? config['readingDirection'] as String : null,
      ReadingDirection.vertical,
    ),
    themeMode: _enumFromName(
      AppThemeMode.values,
      config['themeMode'] is String ? config['themeMode'] as String : null,
      AppThemeMode.system,
    ),
    modelReplyLength: _enumFromName(
      ModelReplyLength.values,
      config['modelReplyLength'] is String ? config['modelReplyLength'] as String : null,
      ModelReplyLength.unlimited,
    ),
    summaryProfiles: profiles,
    selectedSummaryProfileId: resolvedSelectedId,
  );
}

Map<String, dynamic> _settingsToConfig(SettingsModel model) {
  final customProfiles =
      model.summaryProfiles.where((profile) => !profile.isBuiltIn).toList();
  return {
    'apiKey': model.apiKey,
    'baseUrl': model.baseUrl,
    'modelName': model.modelName,
    'autoGenerate': model.autoGenerate,
    'enablePseudoKBMode': model.enablePseudoKBMode,
    'smoothSummary': model.smoothSummary,
    'powerSavingMode': model.powerSavingMode,
    'debounceSeconds': model.debounceSeconds,
    'readingDirection': model.readingDirection.name,
    'themeMode': model.themeMode.name,
    'modelReplyLength': model.modelReplyLength.name,
    'summaryProfiles':
        customProfiles.map((profile) => profile.toJson()).toList(),
    'selectedSummaryProfileId': model.selectedSummaryProfileId,
  };
}

SettingsModel _settingsFromPrefs(SharedPreferences prefs) {
  final rawProfiles = prefs.getString(_prefSummaryProfiles);
  List<SummaryProfile> customProfiles = const [];
  if (rawProfiles != null && rawProfiles.isNotEmpty) {
    try {
      final decoded = jsonDecode(rawProfiles);
      customProfiles = _parseCustomProfiles(decoded);
    } catch (_) {
      customProfiles = const [];
    }
  }

  final config = <String, dynamic>{
    'apiKey': prefs.getString(_prefApiKey) ?? '',
    'baseUrl': prefs.getString(_prefBaseUrl) ?? '',
    'modelName': prefs.getString(_prefModelName) ?? 'gpt-4-vision-preview',
    'autoGenerate': prefs.getBool(_prefAutoGenerate) ?? true,
    'enablePseudoKBMode': prefs.getBool(_prefEnablePseudoKBMode) ?? false,
    'smoothSummary': prefs.getBool(_prefSmoothSummary) ?? true,
    'powerSavingMode': prefs.getBool(_prefPowerSavingMode) ?? true,
    'debounceSeconds': prefs.getInt(_prefDebounceSeconds) ?? 3,
    'readingDirection':
        ReadingDirection.values[prefs.getInt(_prefReadingDirection) ?? 0].name,
    'themeMode': AppThemeMode.values[prefs.getInt(_prefThemeMode) ?? 0].name,
    'modelReplyLength':
        ModelReplyLength.values[
          prefs.getInt(_prefModelReplyLength) ??
              ModelReplyLength.unlimited.index
        ].name,
    'summaryProfiles': customProfiles.map((item) => item.toJson()).toList(),
    'selectedSummaryProfileId':
        prefs.getString(_prefSelectedSummaryProfileId) ??
        defaultSummaryProfileId,
  };
  return _settingsFromConfig(config);
}

void _writeConfigToPrefs(SharedPreferences prefs, Map<String, dynamic> config) {
  final model = _settingsFromConfig(config);
  _writeModelToPrefs(prefs, model);
}

void _writeModelToPrefs(SharedPreferences prefs, SettingsModel model) {
  prefs.setString(_prefApiKey, model.apiKey);
  prefs.setString(_prefBaseUrl, model.baseUrl);
  prefs.setString(_prefModelName, model.modelName);
  prefs.setBool(_prefAutoGenerate, model.autoGenerate);
  prefs.setBool(_prefEnablePseudoKBMode, model.enablePseudoKBMode);
  prefs.setBool(_prefSmoothSummary, model.smoothSummary);
  prefs.setBool(_prefPowerSavingMode, model.powerSavingMode);
  prefs.setInt(_prefDebounceSeconds, model.debounceSeconds);
  prefs.setInt(_prefReadingDirection, model.readingDirection.index);
  prefs.setInt(_prefThemeMode, model.themeMode.index);
  prefs.setInt(_prefModelReplyLength, model.modelReplyLength.index);
  prefs.setString(_prefSelectedSummaryProfileId, model.selectedSummaryProfileId);

  final customProfiles =
      model.summaryProfiles.where((profile) => !profile.isBuiltIn).toList();
  prefs.setString(
    _prefSummaryProfiles,
    jsonEncode(customProfiles.map((item) => item.toJson()).toList()),
  );
}

String _encodeSettingsPayload(SettingsModel model, {required bool pretty}) {
  final payload = {
    'schemaVersion': _backupSchemaVersion,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'settings': _settingsToConfig(model),
  };
  if (pretty) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
  return jsonEncode(payload);
}

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

  static const fullTranslationProfile = SummaryProfile(
    id: fullTranslationProfileId,
    name: '逐字翻译',
    prompt: fullTranslationPrompt,
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
    final model = _settingsFromPrefs(prefs);
    unawaited(_writeBackupModel(model));
    return model;
  }

  Future<File> _writeBackupModel(SettingsModel model) async {
    final content = _encodeSettingsPayload(model, pretty: true);
    final file = await _resolveSettingsBackupFile();
    await file.writeAsString(content);

    final historyDir = await _resolveSettingsHistoryDirectory();
    final snapshotName =
        'settings_${DateTime.now().toUtc().microsecondsSinceEpoch}.json';
    final snapshotFile = File(path.join(historyDir.path, snapshotName));
    await snapshotFile.writeAsString(content);

    final files = historyDir
        .listSync()
        .whereType<File>()
        .where((item) => item.path.toLowerCase().endsWith('.json'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    if (files.length > _settingsHistoryLimit) {
      for (final stale in files.skip(_settingsHistoryLimit)) {
        try {
          await stale.delete();
        } catch (_) {
          // Ignore best-effort cleanup failures.
        }
      }
    }

    return file;
  }

  void _saveAndSet(SettingsModel model) {
    final prefs = ref.read(sharedPreferencesProvider);
    _writeModelToPrefs(prefs, model);
    state = model;
    unawaited(_writeBackupModel(model));
  }

  String exportSettingsAsJson({bool pretty = true}) {
    return _encodeSettingsPayload(state, pretty: pretty);
  }

  Future<String> exportSettingsToBackupFile() async {
    final file = await _writeBackupModel(state);
    return file.path;
  }

  Future<String> exportSettingsToFile(String filePath) async {
    final file = File(filePath);
    await file.writeAsString(exportSettingsAsJson(pretty: true));
    await _writeBackupModel(state);
    return file.path;
  }

  Future<SettingsImportResult> importSettingsFromJsonString(String raw) async {
    Map<String, dynamic>? config;
    try {
      config = _parseSettingsPayload(raw);
    } catch (_) {
      return const SettingsImportResult.failure(SettingsImportError.invalidJson);
    }
    if (config == null) {
      return const SettingsImportResult.failure(
        SettingsImportError.invalidStructure,
      );
    }
    if (!_isSettingsStructureValid(config)) {
      return const SettingsImportResult.failure(
        SettingsImportError.invalidStructure,
      );
    }

    final model = _settingsFromConfig(config);
    _saveAndSet(model);
    return const SettingsImportResult.success();
  }

  Future<SettingsImportResult> importSettingsFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const SettingsImportResult.failure(SettingsImportError.io);
      }
      final raw = await file.readAsString();
      return importSettingsFromJsonString(raw);
    } on FormatException {
      return const SettingsImportResult.failure(SettingsImportError.invalidJson);
    } catch (_) {
      return const SettingsImportResult.failure(SettingsImportError.io);
    }
  }

  Future<List<SettingsBackupEntry>> listSettingsHistory({
    int limit = _settingsHistoryLimit,
  }) async {
    try {
      final historyDir = await _resolveSettingsHistoryDirectory();
      final files = historyDir
          .listSync()
          .whereType<File>()
          .where((item) => item.path.toLowerCase().endsWith('.json'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      return files.take(limit).map((file) {
        return SettingsBackupEntry(
          filePath: file.path,
          fileName: path.basename(file.path),
          modifiedAt: file.lastModifiedSync(),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<SettingsImportResult> restoreFromHistory(String filePath) {
    return importSettingsFromFile(filePath);
  }

  void setApiKey(String value) {
    _saveAndSet(state.copyWith(apiKey: value));
  }

  void setBaseUrl(String value) {
    _saveAndSet(state.copyWith(baseUrl: value));
  }

  void setModelName(String value) {
    _saveAndSet(state.copyWith(modelName: value));
  }

  void setAutoGenerate(bool value) {
    _saveAndSet(state.copyWith(autoGenerate: value));
  }

  void setEnablePseudoKBMode(bool value) {
    _saveAndSet(state.copyWith(enablePseudoKBMode: value));
  }

  void setSmoothSummary(bool value) {
    _saveAndSet(state.copyWith(smoothSummary: value));
  }

  void setPowerSavingMode(bool value) {
    _saveAndSet(state.copyWith(powerSavingMode: value));
  }

  void setReadingDirection(ReadingDirection direction) {
    _saveAndSet(state.copyWith(readingDirection: direction));
  }

  void setThemeMode(AppThemeMode mode) {
    _saveAndSet(state.copyWith(themeMode: mode));
  }

  void setModelReplyLength(ModelReplyLength value) {
    _saveAndSet(state.copyWith(modelReplyLength: value));
  }

  void setSelectedSummaryProfile(String profileId) {
    _saveAndSet(state.copyWith(selectedSummaryProfileId: profileId));
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
    _saveAndSet(
      state.copyWith(
        summaryProfiles: profiles,
        selectedSummaryProfileId: profile.id,
      ),
    );
  }

  void updateSummaryProfile(SummaryProfile profile) {
    if (profile.isBuiltIn || profile.id == defaultSummaryProfileId) return;

    final profiles = [
      for (final item in state.summaryProfiles)
        if (item.id == profile.id) profile else item,
    ];
    _saveAndSet(state.copyWith(summaryProfiles: profiles));
  }

  void deleteSummaryProfile(String profileId) {
    final profile = state.summaryProfiles.firstWhere(
      (item) => item.id == profileId,
      orElse: () => SummaryProfile.defaultProfile,
    );
    if (profile.isBuiltIn) return;

    final profiles =
        state.summaryProfiles.where((item) => item.id != profileId).toList();
    final selectedSummaryProfileId = state.selectedSummaryProfileId == profileId
        ? defaultSummaryProfileId
        : state.selectedSummaryProfileId;
    _saveAndSet(
      state.copyWith(
        summaryProfiles: profiles,
        selectedSummaryProfileId: selectedSummaryProfileId,
      ),
    );
  }

  void setDebounceSeconds(int value) {
    _saveAndSet(state.copyWith(debounceSeconds: value));
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
  final ModelReplyLength modelReplyLength;
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
    required this.modelReplyLength,
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
    ModelReplyLength? modelReplyLength,
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
      modelReplyLength: modelReplyLength ?? this.modelReplyLength,
      summaryProfiles: summaryProfiles ?? this.summaryProfiles,
      selectedSummaryProfileId:
          selectedSummaryProfileId ?? this.selectedSummaryProfileId,
    );
  }
}
