# Phase 5 Execution Record

Work item: `docs/exec-plans/current/secure-assessment`
Phase: 5 — delivery shells, review and dependency adapters

Status: **Complete for the confirmed native-activity scope; G5 passed.** This is not production rollout approval.

## Scope and Decisions

- Support traditional basic, one-at-a-time and adaptive assessments, including secure and ordinary eligible finalized review.
- Embedded LTI activities and superactivities are explicitly excluded by the user. Moodle LTI assessment admission and LMS grade passback remain in scope and unchanged. This supersedes the earlier external-provider blocker.
- Retain adaptive review write guards and feedback filtering.
- Preserve effective assessment policy: existing adaptive settings normalize feedback to `:allow`; this feature does not introduce adaptive delayed-feedback settings. The presentation/filtering layer respects supplied effective settings, including withheld feedback, without changing that normalization.
- Keep session-only confinement and ordinary-session independence. No browser-close detection or account lock was added.

## Implementation Blocks

- [x] Basic, legacy and adaptive secure shells and current-token-only Exit.
- [x] Server-selected finalized review and filtered attempt projections.
- [x] Attempt-owned adaptive state, pinned models and native media/upload boundaries.
- [x] Excluded embedded LTI/superactivity routes remain closed to secure sessions.

One shell owns each secure document. Adaptive content configured with application chrome uses the native chromeless renderer in secure sessions, avoiding nested shells/iframes. The shell preserves lesson script/loading/offline hooks, a keyboard skip target, visible focus and CSRF-protected POST Exit. Secure review navigation is in flow and wraps rather than overlapping Exit.

Both adaptive renderers use a shared server-derived projection to remove course/back/debug URLs, privileged controls and idle logout. Protected ordinary adaptive review does not mount the course assistant, which otherwise tries to redirect from a denied child LiveView.

Finalized scoped/protected attempts reject saves, submissions, activity/part retries and raw dependency writes/reads. Eligible filtered attempt reads remain available. Review previous/next navigation uses the already-projected local state instead of fetching the prohibited raw page-state endpoint; client evaluation/persistence callbacks also no-op in review.

Shared inputs are selected from pinned assessment content and snapshotted onto the owned attempt, not written to learner-global state. Storage I/O occurs outside row locks; installation rechecks lifecycle. Snapshot writes merge namespaces and generic attempt-state updates preserve the reserved snapshot. Missing blobs are distinguished from storage outages. Models require actual parent-attempt membership and pinned revisions; read batches are capped at 100.

Native upload authorization resolves part → activity → assessment ownership and lifecycle before storage. Existing artifact/media URLs are public assets (`lib/oli/delivery/attempts/artifact.ex` uses `:public_read`); there is no existing private signed-download adapter to implement. This feature adds no new public-data exemption and does not retrofit confidentiality onto already-public URLs.

## Test Blocks and Evidence

- [x] Renderer/review/dependency backend regression matrix.
- [x] Adaptive navigation, review effects, shared routes and batching Jest coverage.
- [x] Formatting, scoped lint, compilation and work-item validation.
- [x] Browser shell keyboard/focus and narrow-screen checks.

Backend command:

Final result: **292 tests, 0 failures (39 existing exclusions)**.

```sh
mix test test/oli_web/live/delivery/student/lesson_live_test.exs test/oli_web/live/delivery/student/review_live_test.exs test/oli_web/live/delivery/student/prologue_live_test.exs test/oli_web/secure_assessment_authorization_test.exs test/oli/delivery/secure_assessment_dependencies_test.exs test/oli_web/controllers/api/attempt_controller_test.exs test/oli_web/controllers/api/resource_attempt_state_controller_test.exs test/oli_web/controllers/api/page_lifecycle_controller_test.exs test/oli_web/controllers/page_delivery_controller_test.exs
```

Coverage combines existing content/attempt regression tests with new secure-shell/session tests; empty-content renderer fixtures are not claimed as full authored-assessment browser workflows. New cases cover ordinary/secure review, both adaptive chrome settings, effective feedback normalization, protected upload parent/lifecycle checks, excluded superactivities and finalized retry denial. Dependency tests cover both storage providers, nonempty snapshots, outages, namespace isolation, pinned membership and withheld-feedback projection.

Frontend command, from `assets/`:

Final result: **9 suites, 34 tests passed**.

```sh
node node_modules/jest/bin/jest.js --runInBand test/delivery/secureDelivery_test.ts test/delivery/review_mode_navigation_test.tsx test/delivery/deck_layout_header_test.tsx test/delivery/deck_layout_view_test.tsx test/delivery/load_initial_page_state_test.ts test/delivery/activity_renderer_test.ts test/delivery/activity_feedback_visibility_test.ts test/delivery/adaptive_delivery_test.tsx test/delivery/delivery_lesson_finished_dialog_test.ts
```

The review-navigation test runs real Redux navigation thunks in both directions and asserts no HTTP calls. Header tests cover withheld-score DOM and omitted course navigation in both themes.

Local headless Chrome loaded the actual server-rendered shell with freshly compiled Tailwind CSS at **320, 768 and 1280px**. Passed keyboard skip-link focus/activation, Exit focus-visible outline, exactly one main landmark and no horizontal overflow. This is a shell-level browser check, not an end-to-end SEB pilot.

TypeScript validation uses `tsc --noEmit --skipLibCheck`. Plain `tsc --noEmit` encounters installed dependency/generated declaration errors (duplicate React declarations and Gleam declarations), with no source/test diagnostics. Scoped ESLint and formatting pass. Existing startup/background SQL-sandbox warnings are separate from test assertions.

## Review Loop

Required delegated reviews completed: security, performance, Elixir, UI, TypeScript and requirements.

Resolved findings include initial feedback projection, missed adaptive flags, duplicate shell ownership, adaptive course-chrome iframe duplication, narrow-screen review-toolbar positioning, callback shared-state context, namespace merging and I/O under row locks. Navigation interaction coverage also found and fixed the finalized raw-state fetch. Focused UI/TypeScript rechecks reported no remaining findings; security/Elixir found no blocking issues.

Nonblocking performance follow-up: shared-state operations reconstruct the manifest from distinct pinned content. Work is outside locks and bounded by the assessment, but cache/version it if representative large-assessment measurements justify it before rollout.

## Traceability and Remaining Gates

Partial implementation evidence for AC-010–013, AC-024, AC-026–036 is recorded here; `requirements.yml` remains at `verified_plan` until the final feature validation stage. No unrun acceptance proof is promoted.

Phase 6 still owns full independent-session/publish/resume/isolation scenarios and broader backend verification. Phase 7 owns real Moodle/SEB configuration, cross-node/pilot evidence and deployment/downgrade rehearsal. Capability remains disabled for rollout. No full S3 integration, full assessment browser workflow, screen-reader audit or SEB pilot is claimed by these checks.

## Done Definition

- [x] Phase tasks complete for the confirmed native scope.
- [x] Targeted tests and verification pass.
- [x] Required reviews and focused fix rechecks complete.
- [x] Postflight work-item validation passes.
