# Google Docs Page Import — PRD

## 1. Overview
Feature Name: Google Docs Page Import

Summary: Enable Torus administrators to create new curriculum pages by importing structured Google Docs Markdown exports, preserving formatting, images, and recognized custom elements. The feature streamlines content ingestion from external authoring workflows into Torus’s native page model while maintaining multi-tenant safety and auditability.

Links: _None yet (spec-only)._

## 2. Background & Problem Statement
Today, curriculum admins must manually copy/paste Google Doc content into Torus, losing formatting, embedded media, and custom activity constructs. The curriculum editor has page creation tools but lacks a bulk import path from external sources. Administrators managing institution-level content need a faster way to seed pages from Google Docs without re-authoring everything.

This gap affects Torus Administrators (both authoring and LMS delivery contexts) who curate large libraries. Manual conversion introduces formatting errors, slows publication timelines, and creates inconsistent experiences. We are tackling it now to unlock backlogs of existing Google Docs and align with upcoming adoption campaigns that rely on migrating institutional content.

## 3. Goals & Non-Goals
- Goals:
  - Allow an admin in the curriculum editor to create a new page from a Google Doc using its FILE_ID via Markdown export.
  - Preserve core structural elements (headings, paragraphs, lists, tables, inline formatting, images) during conversion to the Torus JSON page schema.
  - Interpret designated CustomElement tables for YouTube embeds and MCQ items into Torus-compatible structures.
  - Import embedded base64 images from the Markdown export into the Torus media library and reference the hosted asset in the resulting page.
- Non-Goals:
  - Supporting non-admin roles (authors, instructors, students) for this feature.
  - Bidirectional syncing with Google Docs or live updates after import.
  - Importing arbitrary Google Drive MIME types beyond Docs Markdown export.
  - Expanding CustomElement coverage beyond YouTube and MCQ in this release (additional mappings are future work).

## 4. Users & Use Cases
- Primary Users / Roles:
  - Torus Administrator (authoring context) with curriculum editor access.
  - Torus Administrator (delivery context) managing section-specific overrides.
- Use Cases:
  - Admin opens a project in the curriculum editor, clicks “Import from Google Docs,” enters a FILE_ID, and creates a new page populated with the converted Markdown content for further editing.
  - Admin imports a Google Doc containing a YouTube CustomElement table and verifies the video block appears correctly in Torus.
  - Admin imports a Google Doc with an MCQ CustomElement, reviews the converted choices/feedback, and publishes the page.
  - Admin confirms that images embedded in the Google Doc are automatically uploaded to the Torus media library and referenced by the new page.

## 5. UX / UI Requirements
- Key Screens/States:
  - Curriculum editor page tree view with new “Import from Google Docs” button.
  - Modal/dialog prompting for FILE_ID, validation errors, and progress/loading state.
  - Success toast with link to open the newly created page; error toast with retry guidance.
- Navigation & Entry Points:
  - Button resides in the curriculum editor toolbar within the authoring project context.
- Accessibility:
  - Dialog must be fully keyboard navigable with focus trapping, labeled inputs, and screen-reader announcements for success/failure.
  - Button exposes aria-label describing admin-only action, ensures WCAG 2.1 AA color contrast.
- Internationalization:
  - All labels and messages pulled from gettext; handle RTL layout in modal.
- Screenshots/Mocks:
  - _To be provided separately; no assets yet._

## 6. Functional Requirements
| ID | Description | Priority | Owner |
|---|---|---|---|
| FR-001 | Provide an “Import from Google Docs” control in the curriculum editor restricted to administrators. | P0 | Curriculum Authoring |
| FR-002 | Accept a Google Docs FILE_ID, validate format, and build the export URL (`https://docs.google.com/document/d/<FILE_ID>/export?format=md`). | P0 | Curriculum Authoring |
| FR-003 | Download the Markdown export securely, handling OAuth/service account auth if configured, and surface errors for invalid IDs or permissions. | P0 | Platform Integrations |
| FR-004 | Create a new Page resource/revision in the target project before content conversion, reusing existing page creation pathways. | P0 | Curriculum Authoring |
| FR-005 | Convert Markdown headings, paragraphs, inline formatting (bold, italic, links), lists, tables, and blockquotes into Torus JSON blocks preserving order. | P0 | Curriculum Authoring |
| FR-006 | Detect CustomElement tables (2-column with header row) and map YouTube keys (`src`, `caption`) into Torus media component. | P0 | Curriculum Authoring |
| FR-007 | Detect CustomElement tables for MCQ and map `stem`, `choiceN`, `feedbackN`, `correct` into Torus MCQ activity blocks. | P0 | Curriculum Authoring |
| FR-008 | Extract base64-encoded images from the Markdown export, create corresponding assets in the Torus media library, and update page content to use the hosted asset URLs. | P0 | Platform Integrations |
| FR-009 | Log and expose warnings for unsupported Markdown constructs or failed media uploads while still importing baseline content. | P1 | Curriculum Authoring |
| FR-010 | Persist raw import metadata (FILE_ID, importer user_id, timestamp, conversion warnings) for audit. | P1 | Platform Integrations |
| FR-011 | Emit telemetry events for start, success, failure with duration metrics. | P1 | Observability |


## 7. Acceptance Criteria
- AC-001 (FR-001, FR-002) — Given an admin in the curriculum editor, when they click “Import from Google Docs,” then a modal appears requesting FILE_ID with admin-only visibility.
- AC-002 (FR-002, FR-003) — Given the admin enters an invalid FILE_ID, when the import is attempted, then the dialog shows a descriptive error without creating a page resource.
- AC-003 (FR-004, FR-005) — Given a valid FILE_ID with headings, paragraphs, lists, and tables, when the import completes, then a new page resource is created and the rendered page reflects equivalent structure and inline formatting.
- AC-004 (FR-006) — Given the Markdown contains a CustomElement table marking YouTube, when imported, then the resulting page shows a Torus YouTube component using `src` and `caption`.
- AC-005 (FR-007) — Given the Markdown contains a CustomElement table marking MCQ with choices, feedbacks, and correct answer, when imported, then the resulting page renders an MCQ activity with mapped data and validation ensures `correct` references an existing choice.
- AC-006 (FR-008, FR-009) — Given the Markdown contains embedded images encoded as base64, when imported, then the images are stored in the Torus media library and the page references the new media URLs; any failures emit non-blocking warnings.

## 8. Non-Functional Requirements
- Reliability: Retry Markdown fetch once with exponential backoff on transient 5xx responses; fail fast on 4xx. Maintain ≤1% error rate across rolling 30-day window.
- Security & Privacy: Require authenticated Torus admin session and ensure LTI tenant scoping; store FILE_ID and raw Markdown only in memory during conversion; redact PII from logs.
- Compliance: WCAG 2.1 AA for modal, audit logging for admin actions, respect institution data retention policies.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - None
  - No changes to existing page schema; reuse `Oli.Resources` page creation.
- Context Boundaries:
  - `Oli.Authoring.Course` for page resource creation.
  - `Oli.Utils.GoogleDocsImport` (new module) for Markdown download and conversion.
- APIs / Contracts:
  - LiveView event `:import_google_doc` triggered from curriculum editor.
  - Service function `GoogleDocsImport.import(project, file_id, user)` returning `{:ok, resource}` or `{:error, reason, warnings}`.
  - Conversion pipeline returns Torus page JSON (existing schema in `Oli.PageContent`).
- Permissions Matrix:

| Role | Start Import | View Created Page | Audit Log Access |
| --- | --- | --- | --- |
| Admin (authoring) | ✓ | ✓ | ✓ |
| Admin (delivery) | ✓ (for section override contexts scoped to project) | ✓ | ✓ |
| Author | ✗ | ✓ (if granted page edit rights) | ✗ |
| Instructor | ✗ | ✓ (if section access) | ✗ |
| Student | ✗ | ✗ | ✗ |

## 10. Integrations & Platform Considerations
- LTI 1.3: Ensure imports respect institution context derived from admin session; no changes to LTI launch flows.
- Google Docs Access: No OAuth handling needed - this only supports publicly available, shared Docs via URL
- Media Handling: Imported images are uploaded to the Torus media library using existing media APIs; ensure de-duplication logic avoids duplicate assets when hashes match.
- Caching/Perf: Avoid caching raw Markdown; rely on existing SectionResourceDepot after page publish.
- GenAI: No direct integration in this release; ensure import metadata does not trigger GenAI pipelines.

## 11. Feature Flagging, Rollout & Migration
- None, this is an experimental feature


## 13. Risks & Mitigations
- Markdown variability leads to conversion failures → Maintain robust fallback that strips unsupported syntax but preserves text; document warning codes.
- Large documents degrade performance → Enforce file size guardrails (e.g., 10 MB limit) and provide user feedback.
- CustomElement misuse (unexpected keys) → Validate schema and surface warnings; default to plain table rendering if mapping fails.

## 14. Open Questions & Assumptions
- Assumptions:
  - Admins have rights to access the referenced Google Docs via shared service account.
  - Only YouTube and MCQ CustomElements need first-release support; others render as plain tables.
  - Curriculum editor already exposes project context needed for resource creation.
- Open Questions:
  - Do we need to support deduplication of imported images across separate imports (e.g., hash-based reuse) in the initial release or can that arrive later?
  - Are there additional CustomElements (e.g., objectives, formative) that should be prioritized for day-one support? No
