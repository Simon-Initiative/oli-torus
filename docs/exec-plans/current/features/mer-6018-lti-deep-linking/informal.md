# MER-6018 — Productionize author-focused LTI Deep Linking

Source: [MER-6018](https://eliterate.atlassian.net/browse/MER-6018), read on 2026-10-12.
Starting branch: `authoring-launches-prototype`, commit `db1e2b09bc9`.
Implementation branch: `MER-6018-productionize-lti-deep-linking`.

## Requested outcome

An author configures an LTI activity once in a project. Publication carries that selection into delivery, including direct section creation, application of a publication to an existing section, and project → template → section creation. Instructors retain independent section configuration.

MER-6018 explicitly requests authoring UI and save-state hardening, initialization of missing section selections during publication application, template initialization/inheritance, and permanent unit/integration coverage. Deep Linking launches from template authoring UI are deferred.

## Existing prototype

The project page editor supports independent Developer/Instructor and Regular/Deep Link choices. A tool response is validated on the server and returned to the editor, which saves `content.deepLink` through activity editing. Regular authoring launches reuse its URL/custom object. Direct publication-based section creation initializes section-owned selection records transactionally. A migration widens selection URL/title/text columns to PostgreSQL `text`.

Prototype references: `docs/exec-plans/current/features/lti-authoring-launch/overview.md` and `docs/exec-plans/current/features/lti-authoring-launch/plan.md`. The overview describes a broader vision; its section-copy controls and resource-link identity migration are not automatically part of this ticket.

## Manual evidence gathered with the owner

- Authoring selection of Cover Letter + Draft saved successfully and Regular reopened that selection.
- A student in a section created from the publication launched Draft without instructor configuration.
- An unpublished change to Cover Letter + Review affected authoring Regular launches while the existing section retained Draft.
- Publishing Review left the existing section in Draft; a new section from the latest publication launched Review as a student.
- Instructor Change Selection opened an empty modal. Closing it reloaded the regular Review activity. The selection remained unchanged.
- Code inspection found the regular frame and configuration modal deriving the same iframe name. This is a concrete collision to reproduce in a browser; the root cause is not yet confirmed by an automated regression.
- Tool responses can omit `title`; selection status should remain understandable without inventing or interpreting tool-specific custom keys.

These are intake observations, not automated proof. The prototype plan reports temporary smoke checks; Phases 1–5 subsequently added permanent workflow coverage.

## Subsequent owner observations

- During Phase 2, the instructor selector rendered inside the modal, a replacement selection saved and the next learner launch used it. The owner confirmed the requested save/isolation/cancellation checks. Refreshing a practice-page activity used the new course selection without Reset answers.
- During Phase 4, applying a publication preserved the course's original tool selection and initialized the newly added tool from the applied publication.
- During final UI review, the owner selected the original React Button's primary/md variant, requested removing custom focus restoration and approved matching selection labels in authoring and instructor delivery. The latter is committed as `16505e69f8` with four frontend fallback cases.

These observations supplement signed-response/domain/component coverage. They do not constitute a new complete MyProse walkthrough across all role/type combinations, template creation and overrides. AC-022's automated external-navigation proof and AC-030's complete compatibility walkthrough remain deferred under the owner's no-tool-service verification scope. The frame-target correction is tested in Torus; no automated root-cause claim about the original empty MyProse modal is made.

## Additional agreed work

Convert the successful manual lifecycle checks into permanent coverage and repair/verify instructor selection changes, including frame targeting and isolation from project/sibling selections. Keep UI work focused on the Torus wrapper; MyProse owns its internal selector UI.

## Follow-ups outside the current contract

No reset/clear-selection action, creation-wizard redesign, general section-copy checkbox, template Deep Linking authoring UI, LTI resource-link identity migration, or changes to MyProse are included without an explicit scope decision.

Darren approved inheriting Deep Links when adding project/template content through remix / Add Materials into a course or template. This was implemented in Phase 5a after extending FR-012 / AC-032–AC-034. Project sources use the chosen publication; template sources use their current selections, without fallback when absent. Existing destination selections are preserved. Guidance is available in `guides/lti/deep-linking.md`.

The local MyProse catalog regenerates public task IDs at startup. Existing demo task references were restored from their saved tool payload for the manual walkthrough. This demonstrates a tool-side lifecycle limitation; it is not a Torus implementation requirement or evidence that every external tool supports portable configuration.

## Harness entry status

Repository Harness contract already exists in `harness.yml` and `docs/README.md`. This work item supplies the missing production PRD, canonical requirements, FDD and delivery plan without overwriting the prototype documents.

After fetching `origin/master` on 2026-10-12, the prototype base was 29 commits behind and 2 commits ahead. Base integration and regression checks are the first execution phase; no merge/rebase was performed while preparing this contract.

## Decision Log

### 2026-10-16 - Reconcile observations and approved remix scope
- Change: Append the owner's instructor/publication/UI observations, link durable guidance and record the approved and implemented remix addition.
- Reason: Phase 6 consolidates existing evidence without claiming a complete new compatibility walkthrough.
- Evidence: Owner confirmations recorded above, committed workflow/component coverage and `guides/lti/deep-linking.md`.
- Impact: Keep intake history, defer AC-022 external proof and AC-030, and retain approved remix inheritance in this PR.
