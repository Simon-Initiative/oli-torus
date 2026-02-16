# Google Docs Import Media Ingestion Slice — Detailed Design

Source Specs:
- PRD: `docs/epics/content-ingestion/docs_import/prd.md`
- FDD: `docs/epics/content-ingestion/docs_import/fdd.md`

## 1. Slice Summary
- Objective: Convert embedded base64 images in imported markdown into Torus media assets and replace references in the resulting page model.
- In scope: decoding, hash-based dedupe lookup, upload fallback behavior, warning aggregation.
- Out of scope: background cleanup of orphaned media and image transformation pipeline changes.

## 2. AC Coverage
- AC-006 (FR-008, FR-009): Media is uploaded and page references hosted URLs; non-blocking warnings are emitted for failures.

## 3. Responsibilities & Boundaries
- `Oli.GoogleDocs.MediaIngestor` owns base64 extraction, decode, hash, dedupe lookup, and upload orchestration.
- `Oli.GoogleDocs.Import` consumes media results and merges warnings into final import response.
- Existing media library contexts remain source of truth for persistence.

## 4. Interfaces & Signatures
- `Oli.GoogleDocs.MediaIngestor.ingest(images, project, user) :: {:ok, replacements, warnings} | {:error, reason, warnings}`
- `replacements`: map of source token to hosted asset URL.
- Upload failures return warnings and preserve import flow; hard failures only occur on unrecoverable payload parsing.

## 5. Data Flow & Edge Cases
- Main flow:
  1. Parse markdown image nodes and collect base64 payloads.
  2. Decode payload and compute SHA256 hash.
  3. Reuse existing asset when hash exists; otherwise upload via media context.
  4. Return replacement map to importer for content substitution.
- Edge cases:
  - Invalid base64 payload -> warning, preserve original reference.
  - Payload over configured size budget -> warning, skip upload.
  - Upload timeout -> warning, continue import.

## 6. Test Plan
- Unit tests: decode success/failure, hash dedupe reuse, oversize handling.
- Integration tests: import with mixed successful and failed uploads.
- Negative tests: malformed payload, media API failure, duplicate payloads in one document.

## 7. Risks & Open Questions
- Risks:
  - Excessive media payload size can degrade import latency -> enforce size guardrails.
  - Duplicate uploads can inflate storage -> hash-based dedupe plus telemetry.
- Open questions:
  - Should dedupe be scoped globally or per institution/project?

## 8. Definition of Done
- [x] AC mapping is explicit
- [x] Signature and failure behavior are concrete
- [x] Test plan includes edge paths
- [x] Source content aligns with docs/epics/content-ingestion/docs_import spec pack
