# PDF Native Document Input + Context Cache Design (Donut)

## 1. Goals and non-goals

### Primary goals (in order)
1. PDF input strategy: use only native PDF document blocks (`application/pdf`) as the normal path.
2. Prompt cache optimization: maximize stable prefix reuse and minimize volatile suffix changes.

### Non-goals
- No model selection strategy here.
- No image-url/page-screenshot/OCR fallback in the normal path.
- No model-compat fallback; assume selected model supports native PDF input.

### Deployment preference
- App-first composition: PDF validation, stable-prefix assembly, evidence-pool delta calculation should run on client/app whenever possible.
- Backend should stay lightweight: authentication, rate limits/quota checks, request forwarding, and optional observability only.

## 2. Core domain split

The request context MUST separate the following three layers:

1. Document injection layer
- Purpose: inject source-of-truth PDF bytes into model context.
- Format: document block with `mime_type=application/pdf` and base64 payload.
- Granularity: full PDF or deterministic page-batches.

2. Evidence citation layer
- Purpose: reference key evidence for the current answer.
- Format: stable evidence IDs and locations (doc/page/span), not repeated free-text reshaping.

3. Read evidence log layer
- Purpose: track what evidence has been consumed in conversation.
- Format: append-only evidence IDs with minimal state.

## 3. PDF input contract

## 3.1 Document block shape

```json
{
  "type": "document",
  "mime_type": "application/pdf",
  "data_base64": "<base64 PDF bytes>",
  "doc_id": "doc_20260401_abc",
  "doc_sha256": "...",
  "page_range": {"start": 1, "end": 20}
}
```

Rules:
- `mime_type` must be exactly `application/pdf`.
- `doc_id` and `doc_sha256` are immutable for the same physical PDF.
- `page_range` is required when sending partial chunks.
- Same chunking strategy must be reused across turns.

## 3.2 PDF pre-injection validation

Before creating document blocks, run `PDFValidityChecker`:

Hard-fail conditions:
- invalid PDF header/xref/trailer structure
- encrypted/password-protected and cannot decrypt
- unreadable/corrupted page objects (above threshold)

Soft-fail signals:
- severe garbled text/object decoding anomaly ratio
- parser warnings above threshold

Decision:
- valid => continue native PDF injection.
- invalid => enter explicit exception path (`fallback_mode=screenshot`), with user-visible reason.

Important:
- screenshot fallback is **exception-only**, not part of normal architecture.

## 4. Context model for cache friendliness

## 4.1 Request split

Every request must be structured into:

1. Stable prefix (cache-first)
- system prompt (versioned, stable wording)
- tool definitions (versioned)
- document metadata (stable)
- long-lived evidence references (stable IDs, stable order)
- pseudo-knowledge-base context (also injected as PDF document blocks)

2. Volatile suffix (per-turn)
- latest user question
- newly added evidence IDs in current turn
- temporary turn state

## 4.2 Strict cache hygiene

Do not place into stable prefix:
- timestamps
- dynamic counters/statistics
- transient UI states
- temporary hints
- per-turn ranking snapshots

Do not change across turns when semantic content is same:
- field order
- serialization style
- evidence order
- whitespace/formatting patterns if serialized as literal prompt text

## 5. Evidence pool + incremental update

## 5.1 Evidence ID stability

Evidence ID generation:

`evidence_id = ev:{doc_sha256}:{page}:{span_hash}`

Where:
- `span_hash = sha1(normalized_span_text + normalized_bbox + parser_version)`
- normalized text and bbox rules must be deterministic.

Same evidence must always produce same ID.

## 5.2 Deterministic evidence ordering

Sort key (global and fixed):
1. `doc_id` ascending
2. `page` ascending
3. `span_start` ascending
4. `evidence_id` ascending

Never re-order identical evidence sets.

## 5.3 Pool protocol

Server maintains `EvidencePool` per conversation:

- `pool_version`: monotonic integer
- `evidence_map`: `evidence_id -> evidence metadata`
- `active_evidence_ids`: deterministic ordered list

Each turn sends only:
- `added_evidence_ids`
- `removed_evidence_ids`

No full recompose unless explicit rebuild is requested.

## 6. Proposed wire protocol

## 6.1 Prefix snapshot creation (or update)

```json
{
  "conversation_id": "conv_42",
  "prefix_snapshot": {
    "prefix_version": 7,
    "system_prompt_version": "sys_v3",
    "tool_schema_version": "tools_v5",
    "documents": [
      {
        "type": "document",
        "mime_type": "application/pdf",
        "doc_id": "doc_main",
        "doc_sha256": "...",
        "data_base64": "...",
        "page_range": {"start": 1, "end": 50}
      }
    ],
    "stable_evidence_ids": ["ev:...", "ev:..."],
    "pseudo_kb_documents": [
      {
        "type": "document",
        "mime_type": "application/pdf",
        "doc_id": "kb_policy_2026",
        "doc_sha256": "...",
        "data_base64": "...",
        "page_range": {"start": 1, "end": 12}
      }
    ]
  }
}
```

## 6.2 Per-turn inference request

```json
{
  "conversation_id": "conv_42",
  "prefix_ref": {
    "prefix_version": 7,
    "prefix_hash": "..."
  },
  "pool_delta": {
    "base_pool_version": 18,
    "added_evidence_ids": ["ev:doc_main:12:abc"],
    "removed_evidence_ids": []
  },
  "read_log_delta": {
    "read_evidence_ids": ["ev:doc_main:11:def"]
  },
  "turn_state": {
    "focus_pages": [11, 12],
    "question_intent": "consistency_check"
  },
  "latest_user_query": "这段结论与实验设置是否冲突？"
}
```

## 7. Backend modules (engineering)

Add the following backend modules:

1. `PDFValidityChecker`
- `validate(bytes) -> PDFValidationResult`
- output includes: `isValid`, `isEncrypted`, `isCorrupted`, `garbleScore`, `reasonCode`

2. `DocumentChunkPlanner`
- deterministic full/chunk paging strategy
- same input => same chunk sequence

3. `EvidenceIdGenerator`
- stable ID generation
- versioned normalization

4. `EvidencePoolStore`
- conversation-scoped pool + `pool_version`
- incremental mutation only

5. `PrefixSnapshotStore`
- stores canonical stable prefix blobs
- returns `prefix_hash`

6. `PromptEnvelopeBuilder`
- composes stable prefix + volatile suffix
- enforces sorting and serialization invariants

## 8. Product behavior requirements

1. User-facing source traceability
- each cited answer item shows PDF source page and evidence ID.

2. Exception-path transparency
- if PDF fails validation and enters screenshot fallback, show explicit reason and mode switch badge.

3. Session continuity
- when evidence already read, avoid re-highlighting as new evidence unless user asks to revisit.

## 9. Metrics and acceptance criteria

Primary metrics:
- prompt-cache hit rate (prefix-level)
- stable-prefix byte stability ratio
- average volatile suffix tokens
- evidence reorder rate (should approach 0)
- invalid-PDF exception rate

Acceptance gates:
1. Same conversation + same evidence set across 20 turns => identical stable prefix hash.
2. Repeated turns with only new user query => stable prefix unchanged.
3. Re-adding existing evidence => no ID drift.
4. Invalid encrypted PDF => native path rejected with explicit reason code; exception fallback path activated.

## 10. Rollout plan

Phase 1: protocol and storage foundation
- implement PrefixSnapshotStore + EvidencePoolStore + deterministic sort/ID.

Phase 2: PDF validity gate
- enforce pre-injection validation and explicit reason codes.

Phase 3: client integration
- adopt prefix_ref + pool_delta request mode.

Phase 4: observability and tuning
- cache hit dashboards and failure forensics.

## 11. Guardrails summary

Mandatory:
- normal mode uses only `application/pdf` document blocks.
- pseudo-KB context must also be PDF document blocks.
- evidence IDs and order must be stable.
- request composition must separate stable prefix and volatile suffix.

Forbidden in normal mode:
- image-url/page screenshot/OCR fallback.
- full-text flattening of PDF as default QA input.
- per-turn full evidence reshuffle.
