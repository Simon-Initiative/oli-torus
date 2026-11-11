# Payment Codes — Epic Overview

Status: Proposed technical and delivery plan · Updated: 2026-11-10

Make payment-code batches persistent, then deliver template management improvements before exposing the same capabilities globally. Codes remain deferred `payments`; this epic adds a parent batch and a separate code-availability attribute, without replacing the payment system.

## Documents

- UX requirements: `docs/exec-plans/current/epics/payment-codes/handoff.md` (preserved as supplied).
- Central technical design: `docs/exec-plans/current/epics/payment-codes/edd.md`.
- **Epic Plan and story definitions:** `docs/exec-plans/current/epics/payment-codes/plan.md`.

The EDD owns technical decisions; the plan owns deployable scope, acceptance criteria, and dependencies. No subsystem plans or per-story design documents are needed. Story identifiers below are local planning labels, not created Jira issues. The handoff identifies roadmap epic RMAP-110; its live Jira state has not been verified.

## Delivery scope

| Story | Production increment |
| --- | --- |
| PC-01 | Batch schema, historical backfill, and batch-backed creation through existing interfaces; no UI changes |
| PC-02 | Template batch list, batch detail, named creation, and batch downloads using reusable UI components |
| PC-03 | Template batch/code search and query-preserving drill-down |
| PC-04 | Template date, creator, and code-status filters |
| PC-05 | Template code deactivation/reactivation with safe redemption enforcement |
| PC-06 | Complete global management using the components and services already delivered |
| PC-07 | Independent companion: payment details on a student's section profile |

PC-01 through PC-06 are the core sequence. PC-07 covers the separate profile feature in the handoff and can ship independently, preferably before PC-06 so global management remains the final delivery. Enrollment reporting is excluded.

## Decisions that refine the UX handoff

- “Legacy Codes” is a real historical batch per template, created in the schema migration. It is not a synthetic UI grouping of unassigned codes. Historical grouping does not reconstruct original generation requests.
- Template components and their query/export contracts are shared from PC-02 onward. Global management adds scope, navigation, and a template selector; it does not introduce a second payment-code implementation.
- Deactivation is distinct from the existing invalidation of an applied payment. It does not revoke a student's paid access.
- The initial batch deployment preserves existing UI and API contracts. The named modal and 2,500-code UI arrive in PC-02.
- Global management does not mean globally applicable codes or generation without a template. Creation remains template-specific.

## Complexity and decisions to verify

The core model is small. The meaningful risks are data compatibility and payment correctness: historical payments may have had their section changed by an enrollment transfer; existing template transfers must move batch ownership coherently; and redemption must be serialized against deactivation. PC-01 includes historical-data preflight and deployment rehearsal, rather than postponing these concerns to a final hardening story.

The EDD proposes a short coordinated pause of code generation and payment-ownership transfers for PC-01's deployment. Continuous delivery does not require uninterrupted writes, but this assumption must be checked against production deployment capabilities before implementation. If uninterrupted generation is mandatory, a compatibility mechanism and revised deployment design are needed.

Proposed product decisions needing confirmation during story refinement: retain a separate “Invalidated” status for existing invalidated code payments; show current template cost in batch rows and original code value in exports; and keep existing non-code payment auditing accessible alongside the new template batch interface. These are explicit defaults, not claims that UX has already approved them.

## Candidate story descriptions

Each directory contains a self-contained Jira candidate with implementation boundaries, acceptance criteria, verification/recovery guidance, and applicable UX images/design links. These are ticket descriptions, not separate architectural designs; the EDD remains the centralized design.

| Story | Description path |
| --- | --- |
| PC-01 | `docs/exec-plans/current/epics/payment-codes/batch-infrastructure/description.md` |
| PC-02 | `docs/exec-plans/current/epics/payment-codes/template-batches/description.md` |
| PC-03 | `docs/exec-plans/current/epics/payment-codes/batch-search/description.md` |
| PC-04 | `docs/exec-plans/current/epics/payment-codes/batch-filters/description.md` |
| PC-05 | `docs/exec-plans/current/epics/payment-codes/code-activation/description.md` |
| PC-06 | `docs/exec-plans/current/epics/payment-codes/global-management/description.md` |
| PC-07 | `docs/exec-plans/current/epics/payment-codes/student-payment-details/description.md` |

Shared screenshots extracted from the original handoff are in `docs/exec-plans/current/epics/payment-codes/design-assets/`; their source mapping is recorded in that directory's `README.md`.
