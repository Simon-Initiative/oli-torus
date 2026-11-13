# User Preview — Feature traceability

This maps the eight features in the [design handoff](https://docs.google.com/document/d/1XrwiN86AETdRxxyoGanQE2pAvl484RHPM6w0prWKk6c/edit?tab=t.0#heading=h.4opxhmxw54d6) to the agreed requirements and contributing Stories. A Story can contribute to multiple features. The [epic requirements and acceptance traceability](docs/exec-plans/current/epics/user-preview/epic.md#requirements-traceability-analysis-rta) and linked ticket documents retain the detailed scope, criteria, prerequisites, and Jira keys.

## Handoff features

| Handoff feature | Primary requirement | Relationship | Stories |
| --- | --- | --- | --- |
| Instructor view to student preview | [R-001] — Switch instructor perspectives | Direct | [S-001], [S-002], [S-003], [S-005], [S-016] |
| Instructor preview notes | [R-002] — Explain instructor preview content | Direct; gating notes also fall under [R-003] | [S-005]; [S-004] for gating notes |
| Gating Instructor View/Student Preview Bypass | [R-003] — Inspect restricted content | Direct | [S-004] |
| Update authoring page preview | [R-004] — Preview a working authoring page | Direct | [S-007] |
| Activity bank preview | [R-005] — Preview a bank question in isolation | Direct | [S-010], [S-011] |
| Inaccurate previews | [R-006] — Explain verified preview limitations | Direct, with reviewed messaging refinements | [S-008], [S-009] |
| Project publication preview | [R-007] — Preview the latest published course | Direct, including section/identity foundations and shared student presentation | [S-002], [S-012], [S-013], [S-014], [S-015] |
| Instructor guidance on switching views | [R-009] — Guide first-time instructors | Direct | [S-006] |

## Shared and added requirements

| Requirement | Source | Stories |
| --- | --- | --- |
| [R-008] — Accessible and authorized preview controls | Shared handoff requirements | All Stories: [S-001]–[S-016] |
| [R-010] — Manage/reset the author-linked preview user | Added during operator review | [S-015], [S-016] |
| [R-011] — Identify preview users and sections | Added during operator review | [S-012], [S-015], [S-016] |

## Project publication preview contributions

R-007 spans several Stories:

- [S-002] supplies shared student presentation, including the `instructor_view` assign rename.
- [S-012] supplies the review section, Publish-driven updates, launch readiness, and failed-state recovery.
- [S-015] supplies the author-linked preview identity and its project-preview integration.
- [S-014] adds the Publish entry and the complete Full Course Preview shell and exit.
- [S-013] adds the publication-aware Review card.

[R-001]: docs/exec-plans/current/epics/user-preview/epic.md#r-001-switch-instructor-perspectives-without-losing-context
[R-002]: docs/exec-plans/current/epics/user-preview/epic.md#r-002-explain-instructor-preview-content
[R-003]: docs/exec-plans/current/epics/user-preview/epic.md#r-003-inspect-restricted-content-without-changing-access
[R-004]: docs/exec-plans/current/epics/user-preview/epic.md#r-004-preview-a-working-authoring-page
[R-005]: docs/exec-plans/current/epics/user-preview/epic.md#r-005-preview-a-bank-question-in-isolation
[R-006]: docs/exec-plans/current/epics/user-preview/epic.md#r-006-explain-verified-page-preview-limitations
[R-007]: docs/exec-plans/current/epics/user-preview/epic.md#r-007-preview-the-latest-published-course
[R-008]: docs/exec-plans/current/epics/user-preview/epic.md#r-008-keep-preview-controls-accessible-and-authorized
[R-009]: docs/exec-plans/current/epics/user-preview/epic.md#r-009-guide-first-time-instructors-to-the-view-switcher
[R-010]: docs/exec-plans/current/epics/user-preview/epic.md#r-010-manage-and-reset-the-author-linked-preview-user
[R-011]: docs/exec-plans/current/epics/user-preview/epic.md#r-011-identify-preview-users-and-sections

[S-001]: docs/exec-plans/current/epics/user-preview/tickets/S-001.md
[S-002]: docs/exec-plans/current/epics/user-preview/tickets/S-002.md
[S-003]: docs/exec-plans/current/epics/user-preview/tickets/S-003.md
[S-004]: docs/exec-plans/current/epics/user-preview/tickets/S-004.md
[S-005]: docs/exec-plans/current/epics/user-preview/tickets/S-005.md
[S-006]: docs/exec-plans/current/epics/user-preview/tickets/S-006.md
[S-007]: docs/exec-plans/current/epics/user-preview/tickets/S-007.md
[S-008]: docs/exec-plans/current/epics/user-preview/tickets/S-008.md
[S-009]: docs/exec-plans/current/epics/user-preview/tickets/S-009.md
[S-010]: docs/exec-plans/current/epics/user-preview/tickets/S-010.md
[S-011]: docs/exec-plans/current/epics/user-preview/tickets/S-011.md
[S-012]: docs/exec-plans/current/epics/user-preview/tickets/S-012.md
[S-013]: docs/exec-plans/current/epics/user-preview/tickets/S-013.md
[S-014]: docs/exec-plans/current/epics/user-preview/tickets/S-014.md
[S-015]: docs/exec-plans/current/epics/user-preview/tickets/S-015.md
[S-016]: docs/exec-plans/current/epics/user-preview/tickets/S-016.md

## Replacement feature Stories

The replacement batch is approved. Jira denied the first deletion because the configured account lacks Delete Issues permission in MER; no Jira changes have been made. Existing Jira children remain live until deletion access is resolved and the approved replacement completes. The 16 original Story documents remain as migration sources until verified cutover; the replacement work items are the F-/T- documents in the same tickets/ folder. After cutover, remove the old active Story documents; their committed history remains available.

| Replacement Story | Requirement | Primary legacy implementation | New Jira URL | Status |
| --- | --- | --- | --- | --- |
| [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) — Instructor view to student preview | R-001 | S-001, S-002, S-003, S-016 | Pending creation | Approved and pending creation |
| [F-002](docs/exec-plans/current/epics/user-preview/tickets/F-002.md) — Instructor preview notes | R-002 | S-005 | Pending creation | Approved and pending creation |
| [F-003](docs/exec-plans/current/epics/user-preview/tickets/F-003.md) — Gating Instructor View/Student Preview Bypass | R-003 | S-004 | Pending creation | Approved and pending creation |
| [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) — Update authoring page preview | R-004 | S-007 | Pending creation | Approved and pending creation |
| [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) — Activity bank preview | R-005 | S-010, S-011 | Pending creation | Approved and pending creation |
| [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) — Inaccurate previews | R-006 | S-008, S-009 | Pending creation | Approved and pending creation |
| [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) — Project publication preview | R-007 | S-012, S-014, S-013 | Pending creation | Approved and pending creation |
| [F-008](docs/exec-plans/current/epics/user-preview/tickets/F-008.md) — Instructor Guidance on Switching Views | R-009 | S-006 | Pending creation | Approved and pending creation |
| [F-009](docs/exec-plans/current/epics/user-preview/tickets/F-009.md) — Keep preview controls accessible and authorized | R-008 | Cross-linked primary implementation | Pending creation | Approved and pending creation |
| [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) — Manage and reset the author-linked preview user | R-010 | S-015 | Pending creation | Approved and pending creation |
| [F-011](docs/exec-plans/current/epics/user-preview/tickets/F-011.md) — Identify preview users and sections | R-011 | Cross-linked primary implementation | Pending creation | Approved and pending creation |

## Ticket recreation migration

Each old implementation is migrated once. Old parents flattened into sibling sub-tasks map to all of those sub-tasks. Single-Story feature guidance maps to its new owning Story; its existing sub-tasks have their own rows below. “Migrated” becomes Yes only after the new Jira content and relationships are read back and verified.

| Previous ID | Previous Jira key | Primary new owner | Replacement local ID(s) | New corresponding Jira URL(s) | Migrated |
| --- | --- | --- | --- | --- | --- |
| S-001 | MER-6182 | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | [T-001](docs/exec-plans/current/epics/user-preview/tickets/T-001.md) | Pending creation | No — approved; awaiting deletion permission |
| S-002 | MER-6183 | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | [T-002](docs/exec-plans/current/epics/user-preview/tickets/T-002.md) | Pending creation | No — approved; awaiting deletion permission |
| S-003 | MER-6184 | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | [T-003](docs/exec-plans/current/epics/user-preview/tickets/T-003.md) | Pending creation | No — approved; awaiting deletion permission |
| S-004 | MER-6185 | [F-003](docs/exec-plans/current/epics/user-preview/tickets/F-003.md) | [F-003](docs/exec-plans/current/epics/user-preview/tickets/F-003.md) | Pending creation | No — approved; awaiting deletion permission |
| S-005 | MER-6186 | [F-002](docs/exec-plans/current/epics/user-preview/tickets/F-002.md) | [F-002](docs/exec-plans/current/epics/user-preview/tickets/F-002.md) | Pending creation | No — approved; awaiting deletion permission |
| S-006 | MER-6187 | [F-008](docs/exec-plans/current/epics/user-preview/tickets/F-008.md) | [F-008](docs/exec-plans/current/epics/user-preview/tickets/F-008.md) | Pending creation | No — approved; awaiting deletion permission |
| S-007 | MER-6188 | [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) | [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) | Pending creation | No — approved; awaiting deletion permission |
| S-007a | MER-6189 | [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) | [T-006](docs/exec-plans/current/epics/user-preview/tickets/T-006.md) | Pending creation | No — approved; awaiting deletion permission |
| S-007b | MER-6190 | [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) | [T-007](docs/exec-plans/current/epics/user-preview/tickets/T-007.md) | Pending creation | No — approved; awaiting deletion permission |
| S-008 | MER-6191 | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) | [T-011](docs/exec-plans/current/epics/user-preview/tickets/T-011.md), [T-012](docs/exec-plans/current/epics/user-preview/tickets/T-012.md) | Pending creation | No — approved; awaiting deletion permission |
| S-008a | MER-6192 | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) | [T-011](docs/exec-plans/current/epics/user-preview/tickets/T-011.md) | Pending creation | No — approved; awaiting deletion permission |
| S-008b | MER-6193 | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) | [T-012](docs/exec-plans/current/epics/user-preview/tickets/T-012.md) | Pending creation | No — approved; awaiting deletion permission |
| S-009 | MER-6194 | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) | [T-013](docs/exec-plans/current/epics/user-preview/tickets/T-013.md) | Pending creation | No — approved; awaiting deletion permission |
| S-010 | MER-6195 | [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) | [T-008](docs/exec-plans/current/epics/user-preview/tickets/T-008.md), [T-009](docs/exec-plans/current/epics/user-preview/tickets/T-009.md) | Pending creation | No — approved; awaiting deletion permission |
| S-010a | MER-6196 | [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) | [T-008](docs/exec-plans/current/epics/user-preview/tickets/T-008.md) | Pending creation | No — approved; awaiting deletion permission |
| S-010b | MER-6197 | [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) | [T-009](docs/exec-plans/current/epics/user-preview/tickets/T-009.md) | Pending creation | No — approved; awaiting deletion permission |
| S-011 | MER-6198 | [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) | [T-010](docs/exec-plans/current/epics/user-preview/tickets/T-010.md) | Pending creation | No — approved; awaiting deletion permission |
| S-012 | MER-6199 | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | [T-014](docs/exec-plans/current/epics/user-preview/tickets/T-014.md), [T-015](docs/exec-plans/current/epics/user-preview/tickets/T-015.md), [T-016](docs/exec-plans/current/epics/user-preview/tickets/T-016.md) | Pending creation | No — approved; awaiting deletion permission |
| S-012a | MER-6200 | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | [T-014](docs/exec-plans/current/epics/user-preview/tickets/T-014.md) | Pending creation | No — approved; awaiting deletion permission |
| S-012b | MER-6201 | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | [T-015](docs/exec-plans/current/epics/user-preview/tickets/T-015.md) | Pending creation | No — approved; awaiting deletion permission |
| S-012c | MER-6202 | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | [T-016](docs/exec-plans/current/epics/user-preview/tickets/T-016.md) | Pending creation | No — approved; awaiting deletion permission |
| S-013 | MER-6210 | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | [T-018](docs/exec-plans/current/epics/user-preview/tickets/T-018.md) | Pending creation | No — approved; awaiting deletion permission |
| S-014 | MER-6209 | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | [T-017](docs/exec-plans/current/epics/user-preview/tickets/T-017.md) | Pending creation | No — approved; awaiting deletion permission |
| S-015 | MER-6203 | [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) | [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) | Pending creation | No — approved; awaiting deletion permission |
| S-015a | MER-6204 | [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) | [T-019](docs/exec-plans/current/epics/user-preview/tickets/T-019.md) | Pending creation | No — approved; awaiting deletion permission |
| S-015b | MER-6205 | [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) | [T-020](docs/exec-plans/current/epics/user-preview/tickets/T-020.md) | Pending creation | No — approved; awaiting deletion permission |
| S-016 | MER-6206 | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | [T-004](docs/exec-plans/current/epics/user-preview/tickets/T-004.md), [T-005](docs/exec-plans/current/epics/user-preview/tickets/T-005.md) | Pending creation | No — approved; awaiting deletion permission |
| S-016a | MER-6207 | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | [T-004](docs/exec-plans/current/epics/user-preview/tickets/T-004.md) | Pending creation | No — approved; awaiting deletion permission |
| S-016b | MER-6208 | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | [T-005](docs/exec-plans/current/epics/user-preview/tickets/T-005.md) | Pending creation | No — approved; awaiting deletion permission |

## Replacement technical dependencies

These implementation milestones preserve prior prerequisite handoffs and ordered sub-tasks. Shared feature acceptance uses related-work links; no whole-feature cycle is introduced.

| Prerequisite | Blocks |
| --- | --- |
| [T-001](docs/exec-plans/current/epics/user-preview/tickets/T-001.md) | [T-003](docs/exec-plans/current/epics/user-preview/tickets/T-003.md) |
| [T-002](docs/exec-plans/current/epics/user-preview/tickets/T-002.md) | [T-003](docs/exec-plans/current/epics/user-preview/tickets/T-003.md) |
| [T-002](docs/exec-plans/current/epics/user-preview/tickets/T-002.md) | [T-017](docs/exec-plans/current/epics/user-preview/tickets/T-017.md) |
| [T-003](docs/exec-plans/current/epics/user-preview/tickets/T-003.md) | [F-003](docs/exec-plans/current/epics/user-preview/tickets/F-003.md) |
| [T-003](docs/exec-plans/current/epics/user-preview/tickets/T-003.md) | [F-002](docs/exec-plans/current/epics/user-preview/tickets/F-002.md) |
| [T-003](docs/exec-plans/current/epics/user-preview/tickets/T-003.md) | [F-008](docs/exec-plans/current/epics/user-preview/tickets/F-008.md) |
| [T-003](docs/exec-plans/current/epics/user-preview/tickets/T-003.md) | [T-005](docs/exec-plans/current/epics/user-preview/tickets/T-005.md) |
| [T-006](docs/exec-plans/current/epics/user-preview/tickets/T-006.md) | [T-007](docs/exec-plans/current/epics/user-preview/tickets/T-007.md) |
| [T-011](docs/exec-plans/current/epics/user-preview/tickets/T-011.md) | [T-012](docs/exec-plans/current/epics/user-preview/tickets/T-012.md) |
| [T-012](docs/exec-plans/current/epics/user-preview/tickets/T-012.md) | [T-013](docs/exec-plans/current/epics/user-preview/tickets/T-013.md) |
| [T-008](docs/exec-plans/current/epics/user-preview/tickets/T-008.md) | [T-009](docs/exec-plans/current/epics/user-preview/tickets/T-009.md) |
| [T-009](docs/exec-plans/current/epics/user-preview/tickets/T-009.md) | [T-010](docs/exec-plans/current/epics/user-preview/tickets/T-010.md) |
| [T-014](docs/exec-plans/current/epics/user-preview/tickets/T-014.md) | [T-015](docs/exec-plans/current/epics/user-preview/tickets/T-015.md) |
| [T-015](docs/exec-plans/current/epics/user-preview/tickets/T-015.md) | [T-016](docs/exec-plans/current/epics/user-preview/tickets/T-016.md) |
| [T-016](docs/exec-plans/current/epics/user-preview/tickets/T-016.md) | [T-020](docs/exec-plans/current/epics/user-preview/tickets/T-020.md) |
| [T-019](docs/exec-plans/current/epics/user-preview/tickets/T-019.md) | [T-020](docs/exec-plans/current/epics/user-preview/tickets/T-020.md) |
| [T-019](docs/exec-plans/current/epics/user-preview/tickets/T-019.md) | [T-004](docs/exec-plans/current/epics/user-preview/tickets/T-004.md) |
| [T-020](docs/exec-plans/current/epics/user-preview/tickets/T-020.md) | [T-017](docs/exec-plans/current/epics/user-preview/tickets/T-017.md) |
| [T-020](docs/exec-plans/current/epics/user-preview/tickets/T-020.md) | [T-005](docs/exec-plans/current/epics/user-preview/tickets/T-005.md) |
| [T-004](docs/exec-plans/current/epics/user-preview/tickets/T-004.md) | [T-005](docs/exec-plans/current/epics/user-preview/tickets/T-005.md) |
| [T-017](docs/exec-plans/current/epics/user-preview/tickets/T-017.md) | [T-018](docs/exec-plans/current/epics/user-preview/tickets/T-018.md) |

## Replacement sub-tasks

Each item below is a direct child of its feature Story. A flattened former parent is retained only as inherited technical context, not recreated as an intermediate ticket.

| New sub-task | Full title | Parent | Previous ID | Status |
| --- | --- | --- | --- | --- |
| [T-001](docs/exec-plans/current/epics/user-preview/tickets/T-001.md) | Move Instructor View to its dedicated routes | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | S-001 | Approved and pending creation |
| [T-002](docs/exec-plans/current/epics/user-preview/tickets/T-002.md) | Apply route-derived student presentation to delivery | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | S-002 | Approved and pending creation |
| [T-003](docs/exec-plans/current/epics/user-preview/tickets/T-003.md) | Add the instructor perspective selector and return flow | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | S-003 | Approved and pending creation |
| [T-004](docs/exec-plans/current/epics/user-preview/tickets/T-004.md) | Admin preview identity and instructor enrollment | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | S-016a | Approved and pending creation |
| [T-005](docs/exec-plans/current/epics/user-preview/tickets/T-005.md) | Section and legacy admin preview integration | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | S-016b | Approved and pending creation |
| [T-006](docs/exec-plans/current/epics/user-preview/tickets/T-006.md) | Shared delivery presentation boundary | [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) | S-007a | Approved and pending creation |
| [T-007](docs/exec-plans/current/epics/user-preview/tickets/T-007.md) | Integrate basic and advanced author preview | [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) | S-007b | Approved and pending creation |
| [T-008](docs/exec-plans/current/epics/user-preview/tickets/T-008.md) | Authorized single-question rendering | [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) | S-010a | Approved and pending creation |
| [T-009](docs/exec-plans/current/epics/user-preview/tickets/T-009.md) | Bank launch, banner, and return | [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) | S-010b | Approved and pending creation |
| [T-010](docs/exec-plans/current/epics/user-preview/tickets/T-010.md) | Align bank question action controls | [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) | S-011 | Approved and pending creation |
| [T-011](docs/exec-plans/current/epics/user-preview/tickets/T-011.md) | Accessible limitation presentation and static cases | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) | S-008a | Approved and pending creation |
| [T-012](docs/exec-plans/current/epics/user-preview/tickets/T-012.md) | Conditional embedded preview message | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) | S-008b | Approved and pending creation |
| [T-013](docs/exec-plans/current/epics/user-preview/tickets/T-013.md) | Explain limited and sample behavior in page preview | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) | S-009 | Approved and pending creation |
| [T-014](docs/exec-plans/current/epics/user-preview/tickets/T-014.md) | Review-section association and Publish-driven updates | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | S-012a | Approved and pending creation |
| [T-015](docs/exec-plans/current/epics/user-preview/tickets/T-015.md) | Authorized launch, readiness, and session contract | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | S-012b | Approved and pending creation |
| [T-016](docs/exec-plans/current/epics/user-preview/tickets/T-016.md) | Failed-state Reset Preview recovery | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | S-012c | Approved and pending creation |
| [T-017](docs/exec-plans/current/epics/user-preview/tickets/T-017.md) | Launch Full Course Preview from Publish with a complete preview shell | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | S-014 | Approved and pending creation |
| [T-018](docs/exec-plans/current/epics/user-preview/tickets/T-018.md) | Add a publication-aware Full Course Preview card to Review | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | S-013 | Approved and pending creation |
| [T-019](docs/exec-plans/current/epics/user-preview/tickets/T-019.md) | Preview-user ownership, markers, and reset | [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) | S-015a | Approved and pending creation |
| [T-020](docs/exec-plans/current/epics/user-preview/tickets/T-020.md) | Full Course Preview identity integration | [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) | S-015b | Approved and pending creation |

## Replacement execution proposal

The proposed batch deletes the 16 existing Stories and their 13 sub-tasks below, removes the generated Technical Approach section and all following content from MER-6158, creates the 11 replacement Stories and 20 sub-tasks above, uploads and embeds the 17 original PNG screenshots in their owning feature descriptions, and creates the 21 listed implementation-level Blocks links. All original Figma hyperlink targets are retained. Source Feature text is verbatim; the operator selected handoff Title Case button guidance and the handoff’s generic alternatives notice over the superseded technical copy rules.

The epic edit retains its first 5 rich-text nodes exactly: the existing handoff/Figma/prototype references, introductory view text, embedded recording, and spacing above Technical Approach. It adds no replacement summary, questions, or workflow section to the epic. The complete technical content moves into the feature/implementation work items and remains in the repository epic.

| Existing Story to delete | Title | Associated sub-tasks to delete |
| --- | --- | --- |
| MER-6210 | Add a publication-aware Full Course Preview card to Review | None |
| MER-6209 | Launch Full Course Preview from Publish with a complete preview shell | None |
| MER-6206 | Reuse author-linked preview users for admin section previews | MER-6207, MER-6208 |
| MER-6203 | Manage and reset the author-linked preview user | MER-6204, MER-6205 |
| MER-6199 | Prepare a project review section and published-course launch | MER-6200, MER-6201, MER-6202 |
| MER-6198 | Align bank question action controls | None |
| MER-6195 | Preview one bank question without changing it | MER-6196, MER-6197 |
| MER-6194 | Explain limited and sample behavior in page preview | None |
| MER-6191 | Explain unavailable interactions in page preview | MER-6192, MER-6193 |
| MER-6188 | Reuse delivery layouts and views for authoring page preview | MER-6189, MER-6190 |
| MER-6187 | Guide instructors to the perspective selector once | None |
| MER-6186 | Explain bank examples and simplify selection management | None |
| MER-6185 | Inspect restricted content without changing student access | None |
| MER-6184 | Add the instructor perspective selector and return flow | None |
| MER-6183 | Apply route-derived student presentation to delivery | None |
| MER-6182 | Move Instructor View to its dedicated routes | None |

All captured tickets are in Analyzing status, with no comments, attachments, or issue links outside the deletion set. Existing keys are historical migration identifiers; returned keys will be recorded immediately and the New corresponding Jira URL(s)/Migrated columns updated only after read-back verification. Stories remain unassigned and use project-default priority/workflow status; no new labels, components, versions, or point estimates are introduced. Source/design links and embedded images are explicitly part of this replacement format. At filing, replace local F-/T- Markdown links with the returned Jira URLs, replace image paths with uploaded Jira attachments embedded in the description, and resolve repository code/evidence links to the committed GitHub paths so no Jira hyperlink depends on a local file. These are mechanical transport changes; the approved text remains unchanged.

Deletion is limited to the listed live hierarchy. Recheck its parents, sub-task membership, and descriptions before execution and stop affected deletion if the snapshot has changed. After all replacements are verified, remove the old active S-*.md documents, retain their Git history, point historical source references at that committed history, and synchronize the repository epic/index/RTA with the F-/T- hierarchy. Commit and publish the completed migration records. Do not leave duplicate active ticket sets or create a separate jira/ payload folder.

**Approval:** The operator approved this exact deletion, epic edit, recreation, image upload/embedding, and relationship batch on 2026-11-13. Jira rejected the first deletion (MER-6210) with 403 Forbidden because eknebel@andrew.cmu.edu lacks Delete Issues permission in MER. No deletion succeeded and no replacement was created. Execution is blocked on that permission or administrator deletion of the approved old hierarchy; renewed batch approval is not required.
