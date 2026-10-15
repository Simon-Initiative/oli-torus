# MER-6018 LTI Deep Linking - Product Requirements Document

## 1. Overview

Productionize author-configured LTI activities so a published course can be used by students without each instructor repeating tool selection. Build on the working prototype and preserve independent configuration in every delivery section.

Source: [MER-6018](https://eliterate.atlassian.net/browse/MER-6018). Intake and manual evidence are recorded in `informal.md`; detailed requirements are canonical in `requirements.yml`.

## 2. Background & Problem Statement

The prototype already supports selecting a tool resource in project authoring and carrying it into a directly created section. Manual MyProse testing demonstrated Draft/Review reuse, publication isolation and different configurations in old/new sections. These workflows lacked permanent regression coverage. Existing-section publication application and template inheritance are incomplete, and instructor reconfiguration initially opened an empty modal in the demonstrated embedded-tool flow. During Phase 2 the owner confirmed selector rendering, saved instructor replacement, the next learner launch using it and cancellation preserving the selection. The full compatibility walkthrough remains pending.

## 3. Goals & Non-Goals

### Goals

- Deliver a reliable authoring selection/save experience using established Torus UI patterns.
- Carry published selections through direct creation, publication application, template-based creation and previous-section copying with independent destination ownership.
- Preserve instructor overrides and verify that instructors can actually reconfigure their sections.
- Turn the manual walkthrough into permanent, layered automated coverage.

### Non-Goals

- Deep Linking authoring launches within templates, including new template authoring UI.
- A reset/clear-selection action, general section-copy selection controls or a creation-wizard redesign.
- A new authoring resource type, a separate selection resource, or a context-specific LTI resource-link identity migration.
- Redesigning MyProse, changing its task catalog lifecycle, or guaranteeing portability of tool-side shared content.

## 4. Users & Use Cases

- Authors select a task with the chosen LTI role, save it in the activity and reopen it with Regular.
- Instructors create courses from publications, templates or previous sections and receive inherited selections; they can subsequently change their own section's selection.
- Instructors apply a publication that introduces/configures activities while retaining existing section selections.
- Students launch the selected resource with their own identity and destination course context.
- Administrators retain existing integration registration, status and Deep Linking capability controls.

## 5. UX / UI Requirements

Use familiar authoring controls for role, launch type and explicit actions. Show current selection and use the existing page-editor `Saving...` / `All changes saved` indicator, with coherent local cancellation and failure feedback. Do not add a separate selection-saved confirmation. Explain Regular reuse and distinguish selecting a resource from opening it. Use useful generic metadata fallback when the tool omits a title, without interpreting arbitrary custom parameters.

The wrapper owns dialog size, layout, scroll, keyboard/focus behavior and status announcements. The tool owns its internal selection UI. No Figma source was supplied; use established components and Tailwind conventions. If a design source is later provided, route reconciliation through the repository's UI workflow.

When reopening configuration, Torus sends the current project draft or section selection's string-valued `custom` parameters in the optional Deep Linking custom claim. This makes existing configuration available to compatible tools; whether the tool preselects its UI remains tool-owned. Opening configuration preserves the saved selection.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Recheck authorization and integration capability on the server, validate signed responses and reject stale/replayed save attempts.
- Preserve published revisions, unrelated activity content and destination records on failure; avoid partial section creation or publication application.
- Keep initialization scoped to destination/publication resources and bounded database operations; do not fetch external tools during creation/copy/application transactions.
- Preserve tool-supplied custom values and long metadata without truncation or raw-HTML rendering.
- Preserve keyboard operation, visible focus and accessible progress/error announcements.
- Do not copy learner attempts, submissions or grades as part of selection inheritance.

## 9. Data, Interfaces & Dependencies

Project selections remain optional `content.deepLink` values on ordinary activity revisions. Sections and template blueprints own records in `lti_section_resource_deep_links`. Templates are section blueprints, not a new resource type. Existing launch details, authorization, callback, editor-save and delivery-launch boundaries remain the integration surfaces.

Compatible tools must return one supported resource link and portable URL/custom configuration. MyProse is the manual validation target, not a production dependency to embed in Torus tests or data migrations.

## 10. Repository & Platform Considerations

Respect `ARCHITECTURE.md`, `harness.yml`, `docs/TESTING.md`, `docs/FRONTEND.md`, `docs/BACKEND.md` and `AGENTS.md`. Domain consistency belongs in editing/LTI/delivery contexts; transport and React own their existing responsibilities. Prefer real `Oli.Scenarios` workflows for publication/section integration. The current verification scope excludes tests that require running an external tool; actual cross-service frame targeting remains deferred. Run appropriate tests before implementation commits and keep successful ExUnit output clean.

Issue tracking uses MER-6018. Review must follow `docs/CODEREVIEW.md`, including security/performance and the applicable backend/frontend/requirements lenses. This contract does not change Jira status or publish a PR.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

Use existing integration capability/status controls and normal deployment. Retain and verify the prototype's widening migration and its explicit rollback behavior; no blanket backfill of existing section selections is planned. Additional schema changes require a demonstrated design need and the standard migration generator with explicit `up/0` and `down/0`.

## 12. Telemetry & Success Metrics

N/A — no new telemetry program is in scope. Current verification uses the active acceptance criteria and permanent backend/scenario/frontend evidence. Existing MyProse observations are retained; new cross-service compatibility proof is deferred. Existing diagnostic paths may report bounded errors without JWTs, custom payloads or learner data.

## 13. Risks & Mitigations

- Editor saves can update a revision in place while holding a lock: compare captured server state within the existing editor transaction; do not change the ordinary revision policy.
- Publication application can remove or filter destination resources: initialize after destination membership is finalized and test both major/minor paths.
- Template duplication shares a copy engine with course copying: include current Deep Linking selections in mandatory Content / curriculum for both sources, without changing other copy groups or learner-data policy.
- Tool frames can collide: cover Torus-owned targets and handlers with frontend tests. Actual tool navigation and return delivery remain a documented verification gap until cross-service tests resume.
- Tool-side shared references or regenerated IDs can undermine portability: preserve exact configuration and document observed compatibility, without inventing tool-side cloning.

## 14. Open Questions & Assumptions

### Open Questions

- None block this planning contract. A reset action and wizard source labels remain separate product follow-ups.
- Whether a supplied Figma design or a tool-specific production rollout is needed can be revisited without expanding the current defaults silently.

### Assumptions

- MER-6018's narrower scope takes precedence over the broader prototype overview.
- Template and previous-section inheritance copy current source-owned records, including instructor changes, without fallback to a newer project configuration. Deep Links are part of the existing mandatory Content / curriculum group; no new checkbox is added. Each destination owns independent rows and retains the existing project/template provenance and publication-update behavior.
- The project page editor is the supported authoring configuration host. Other hosts retain ordinary editing/launch compatibility and must not offer an unsupported selection-save action.
- Existing LTI resource-link identity formats remain unchanged in this ticket.

## 15. QA Plan

- Backend unit/controller tests exercise roles, capability/permission enforcement, JWT/correlation validation, save rejection and URL/custom reuse.
- Real scenario workflows exercise publication capture, destination membership, missing-only application, template inheritance, section isolation, idempotency and rollback.
- Frontend tests exercise autosave coordination, active-request lifetime, failed-save recovery and accessible status states.
- Frontend component tests use controlled transport/message responses to exercise modal rendering, distinct regular/configuration/multiple-instance frame targets and return association without running an external service. These tests do not prove actual external navigation or interoperability.
- Browser/E2E tests requiring a real or test tool, tool-service setup and adding Deep Linking support to LTI Example Tool are deferred by the owner's 2026-10-13 instruction. Keep backend signed-response tests, real domain scenarios and frontend tests in scope.
- Preserve the existing manual MyProse observations. A new complete compatibility walkthrough is deferred with tool-dependent verification; it is not a gate for the current test work. Resume it explicitly when tool verification is revisited.

## 16. Definition of Done

- [ ] Active backend/frontend/scenario criteria have linked evidence; deferred cross-service checks are reported separately and never marked verified from component tests alone.
- [ ] Torus-owned instructor modal behavior and section-local persistence are covered; confirmation with an actual tool remains explicitly pending.
- [ ] Required backend/frontend/scenario checks and migration checks pass without an external tool service.
- [ ] Manual compatibility observations and user guidance are recorded without committing local credentials or temporary notes.
- [ ] Repository review findings are resolved and Harness implementation traceability is validated.

## Decision Log

### 2026-10-14 - Send existing selection parameters when reopening configuration
- Change: Include standards-compatible string custom parameters from the current project draft or section-owned selection in Deep Linking requests.
- Reason: The owner requested generic Torus support for tools that can initialize their selector from these parameters, independent of MyProse's current UI limitations.
- Evidence: `lib/oli_web/controllers/lti_controller.ex`, `test/scenarios/lti_external_tool/section_configuration_test.exs` and LTI Deep Linking 2.0 section 4.4.11.
- Impact: Optional tool hints use the existing selector endpoint and signed request correlation. Invalid legacy custom values are omitted from this optional claim without changing stored data or existing Regular launches. No MyProse changes or external-tool automated checks are required.

### 2026-10-13 - Defer verification requiring an external tool service
- Change: Retain backend, real domain scenarios and frontend component tests; defer tool-dependent browser/E2E coverage and new compatibility walkthroughs.
- Reason: The owner explicitly requested this scope after confirming that the locally available LTI Example Tool does not implement Deep Linking.
- Evidence: The current browser fixture covers a Regular launch in `assets/automation/tests/torus/lti_external_tool/lti-external-tool.spec.ts`; `test/scenarios/lti_external_tool/hooks.ex` disables Deep Linking.
- Impact: Product behavior remains in scope. AC-022 and AC-030 retain pending external verification; AC-029 specifies frontend coverage executable without a tool service. Deferred evidence prevents claiming complete cross-service verification.


### 2026-10-14 - Simplify authoring hardening and reuse save feedback
- Change: Use the existing editor transaction, lock, deferred persistence and save indicator. Retain signed validation and captured-state selection merge; remove separate authoring request/cancellation persistence, coordinator and general multi-tab guarantees.
- Reason: The owner requested reducing implementation complexity to the ticket's requirements and explicitly asked to reuse `Saving...` / `All changes saved`.
- Impact: Authoring close/error is local and prevents further submissions from that modal; uncertain save outcomes require reload. The committed instructor/section implementation is unchanged. No new migration or external-tool dependency.


### 2026-10-15 - Include Deep Links in previous-section curriculum copying
- Change: Extend Phase 5 inheritance to previous-section copying as part of mandatory Content / curriculum, alongside template inheritance.
- Reason: The owner confirmed that copying course content should carry its current tool configuration, including instructor changes, without another copy option.
- Evidence: `lib/oli_web/live/new_course/copy_choice_modal.ex`, `lib/oli/delivery/sections/copy_options.ex`, `lib/oli/delivery/sections/section_copy.ex`; FR-008, AC-020 and AC-021.
- Impact: Copy current source-owned selections to independent destination rows; preserve missing/cleared selections, existing publication pins and provenance. Do not copy learner data or redesign the wizard.
