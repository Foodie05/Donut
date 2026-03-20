import 'dart:convert';

import 'package:flutter/services.dart';

class ReleaseNote {
  final int versionCode;
  final String versionName;
  final String zhMarkdown;
  final String enMarkdown;

  const ReleaseNote({
    required this.versionCode,
    required this.versionName,
    required this.zhMarkdown,
    required this.enMarkdown,
  });

  factory ReleaseNote.fromJson(Map<String, dynamic> json) {
    return ReleaseNote(
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
      versionName: (json['versionName'] as String?) ?? '',
      zhMarkdown: (json['zhMarkdown'] as String?) ?? '',
      enMarkdown: (json['enMarkdown'] as String?) ?? '',
    );
  }
}

const _releaseNotesAssetPath = 'assets/release_notes.json';

List<ReleaseNote>? _notesCache;

Future<List<ReleaseNote>> _loadReleaseNotes() async {
  if (_notesCache != null) return _notesCache!;

  try {
    final raw = await rootBundle.loadString(_releaseNotesAssetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      _notesCache = const [];
      return _notesCache!;
    }

    final notesNode = decoded['notes'];
    if (notesNode is! List) {
      _notesCache = const [];
      return _notesCache!;
    }

    final notes = notesNode
        .whereType<Map>()
        .map((item) => ReleaseNote.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.versionCode > 0 && item.versionName.isNotEmpty)
        .toList()
      ..sort((a, b) => a.versionCode.compareTo(b.versionCode));

    _notesCache = notes;
    return notes;
  } catch (_) {
    _notesCache = const [];
    return _notesCache!;
  }
}

Future<List<ReleaseNote>> notesBetweenVersions(
  int fromExclusive,
  int toInclusive,
) async {
  final all = await _loadReleaseNotes();
  return all
      .where((item) => item.versionCode > fromExclusive && item.versionCode <= toInclusive)
      .toList()
    ..sort((a, b) => a.versionCode.compareTo(b.versionCode));
}
