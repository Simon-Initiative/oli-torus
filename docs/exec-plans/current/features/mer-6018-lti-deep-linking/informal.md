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

These are manual observations, not automated proof. The prototype plan reports temporary smoke checks; permanent tests of the new workflows remain to be written.

## Additional agreed work

Convert the successful manual lifecycle checks into permanent coverage and repair/verify instructor selection changes, including frame targeting and isolation from project/sibling selections. Keep UI work focused on the Torus wrapper; MyProse owns its internal selector UI.

## Follow-ups outside the current contract

No reset/clear-selection action, creation-wizard redesign, general section-copy checkbox, template Deep Linking authoring UI, LTI resource-link identity migration, or changes to MyProse are included without an explicit scope decision.

The local MyProse catalog regenerates public task IDs at startup. Existing demo task references were restored from their saved tool payload for the manual walkthrough. This demonstrates a tool-side lifecycle limitation; it is not a Torus implementation requirement or evidence that every external tool supports portable configuration.

## Harness entry status

Repository Harness contract already exists in `harness.yml` and `docs/README.md`. This work item supplies the missing production PRD, canonical requirements, FDD and delivery plan without overwriting the prototype documents.

After fetching `origin/master` on 2026-10-12, the prototype base was 29 commits behind and 2 commits ahead. Base integration and regression checks are the first execution phase; no merge/rebase was performed while preparing this contract.
