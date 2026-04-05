import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

class PdfDocumentBlock {
  const PdfDocumentBlock({
    required this.docId,
    required this.docSha256,
    required this.dataBase64,
    this.pageStart,
    this.pageEnd,
  });

  final String docId;
  final String docSha256;
  final String dataBase64;
  final int? pageStart;
  final int? pageEnd;

  Map<String, Object?> toJson() {
    final map = <String, Object?>{
      'type': 'document',
      'mime_type': 'application/pdf',
      'doc_id': docId,
      'doc_sha256': docSha256,
      'data_base64': dataBase64,
    };
    if (pageStart != null && pageEnd != null) {
      map['page_range'] = {
        'start': pageStart,
        'end': pageEnd,
      };
    }
    return map;
  }
}

class EvidenceRef {
  const EvidenceRef({
    required this.evidenceId,
    required this.docId,
    required this.docSha256,
    required this.page,
    required this.spanStart,
    required this.spanEnd,
  });

  final String evidenceId;
  final String docId;
  final String docSha256;
  final int page;
  final int spanStart;
  final int spanEnd;

  Map<String, Object> toJson() {
    return {
      'evidence_id': evidenceId,
      'doc_id': docId,
      'doc_sha256': docSha256,
      'page': page,
      'span_start': spanStart,
      'span_end': spanEnd,
    };
  }
}

class EvidenceIdGenerator {
  const EvidenceIdGenerator({
    this.normalizationVersion = 'v1',
  });

  final String normalizationVersion;

  String generate({
    required String docSha256,
    required int page,
    required String normalizedSpanText,
    required String normalizedBbox,
  }) {
    final payload =
        '$normalizedSpanText|$normalizedBbox|$normalizationVersion';
    final spanHash = sha1.convert(utf8.encode(payload)).toString();
    return 'ev:$docSha256:$page:$spanHash';
  }
}

class EvidenceOrdering {
  const EvidenceOrdering._();

  static List<EvidenceRef> sortDeterministically(List<EvidenceRef> items) {
    final cloned = List<EvidenceRef>.of(items);
    cloned.sort((a, b) {
      final docCompare = a.docId.compareTo(b.docId);
      if (docCompare != 0) return docCompare;

      final pageCompare = a.page.compareTo(b.page);
      if (pageCompare != 0) return pageCompare;

      final spanStartCompare = a.spanStart.compareTo(b.spanStart);
      if (spanStartCompare != 0) return spanStartCompare;

      return a.evidenceId.compareTo(b.evidenceId);
    });
    return cloned;
  }
}

class PrefixSnapshot {
  const PrefixSnapshot({
    required this.systemPrompt,
    required this.systemPromptVersion,
    required this.toolSchemaVersion,
    required this.documents,
    required this.pseudoKbDocuments,
    required this.stableEvidenceIds,
  });

  final String systemPrompt;
  final String systemPromptVersion;
  final String toolSchemaVersion;
  final List<PdfDocumentBlock> documents;
  final List<PdfDocumentBlock> pseudoKbDocuments;
  final List<String> stableEvidenceIds;

  Map<String, Object?> toCanonicalJson() {
    final sortedEvidenceIds = List<String>.of(stableEvidenceIds)..sort();
    return {
      'system_prompt': systemPrompt,
      'system_prompt_version': systemPromptVersion,
      'tool_schema_version': toolSchemaVersion,
      'documents': documents.map((item) => item.toJson()).toList(),
      'pseudo_kb_documents': pseudoKbDocuments
          .map((item) => item.toJson())
          .toList(),
      'stable_evidence_ids': sortedEvidenceIds,
    };
  }
}

class VolatileSuffix {
  const VolatileSuffix({
    required this.latestUserQuery,
    required this.addedEvidenceIds,
    required this.removedEvidenceIds,
    required this.readEvidenceIds,
    this.turnState = const <String, Object?>{},
  });

  final String latestUserQuery;
  final List<String> addedEvidenceIds;
  final List<String> removedEvidenceIds;
  final List<String> readEvidenceIds;
  final Map<String, Object?> turnState;

  Map<String, Object?> toCanonicalJson() {
    final added = List<String>.of(addedEvidenceIds)..sort();
    final removed = List<String>.of(removedEvidenceIds)..sort();
    final read = List<String>.of(readEvidenceIds)..sort();
    return {
      'latest_user_query': latestUserQuery,
      'pool_delta': {
        'added_evidence_ids': added,
        'removed_evidence_ids': removed,
      },
      'read_log_delta': {
        'read_evidence_ids': read,
      },
      'turn_state': turnState,
    };
  }
}

class PromptEnvelopeBuilder {
  const PromptEnvelopeBuilder();

  Map<String, Object?> build({
    required String conversationId,
    required PrefixSnapshot stablePrefix,
    required VolatileSuffix volatileSuffix,
  }) {
    return {
      'conversation_id': conversationId,
      'stable_prefix': stablePrefix.toCanonicalJson(),
      'volatile_suffix': volatileSuffix.toCanonicalJson(),
    };
  }

  /// Canonical serializer for stable-prefix hashing.
  String canonicalStablePrefixJson(PrefixSnapshot stablePrefix) {
    final canonical = _canonicalize(stablePrefix.toCanonicalJson());
    return jsonEncode(canonical);
  }

  String stablePrefixHash(PrefixSnapshot stablePrefix) {
    final encoded = canonicalStablePrefixJson(stablePrefix);
    return sha256.convert(utf8.encode(encoded)).toString();
  }

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in value.entries) {
        sorted[entry.key.toString()] = _canonicalize(entry.value);
      }
      return sorted;
    }
    if (value is List) {
      return value.map(_canonicalize).toList(growable: false);
    }
    return value;
  }
}
