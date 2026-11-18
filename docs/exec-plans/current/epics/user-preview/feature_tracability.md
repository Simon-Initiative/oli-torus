# User Preview — Feature traceability

The eight Features in the [User Preview Nov 2026 Handoff](https://docs.google.com/document/d/1XrwiN86AETdRxxyoGanQE2pAvl484RHPM6w0prWKk6c/edit?tab=t.0#heading=h.4opxhmxw54d6) each map to one epic Story. Preview-user management has an additional active Story. Preview-record identification is accepted within the owning user and section Stories; F-011 / MER-6221 remains a closed reference. Shared accessibility and authorization requirements apply to the affected Stories; F-009 / MER-6219 and F-011 / MER-6221 are closed. Technical implementation is migrated once under a primary owner; related Features cross-link that work. The [epic](docs/exec-plans/current/epics/user-preview/epic.md) retains the full requirements and acceptance traceability.

## Handoff features

| Handoff feature | Requirement | Owning Story | Related implementation |
| --- | --- | --- | --- |
| Instructor view to student preview | [R-001] | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) / [MER-6211](https://eliterate.atlassian.net/browse/MER-6211) | [F-002](docs/exec-plans/current/epics/user-preview/tickets/F-002.md), [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) |
| Instructor preview notes | [R-002] | [F-002](docs/exec-plans/current/epics/user-preview/tickets/F-002.md) / [MER-6212](https://eliterate.atlassian.net/browse/MER-6212) | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md), [F-003](docs/exec-plans/current/epics/user-preview/tickets/F-003.md) |
| Gating Instructor View/Student Preview Bypass | [R-003] | [F-003](docs/exec-plans/current/epics/user-preview/tickets/F-003.md) / [MER-6213](https://eliterate.atlassian.net/browse/MER-6213) | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) |
| Update authoring page preview | [R-004] | [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) / [MER-6214](https://eliterate.atlassian.net/browse/MER-6214) | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) |
| Activity bank preview | [R-005] | [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) / [MER-6215](https://eliterate.atlassian.net/browse/MER-6215) | None |
| Inaccurate previews | [R-006] | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) / [MER-6216](https://eliterate.atlassian.net/browse/MER-6216) | [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) |
| Project publication preview | [R-007] | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) / [MER-6217](https://eliterate.atlassian.net/browse/MER-6217) | [T-002](docs/exec-plans/current/epics/user-preview/tickets/T-002.md), [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) |
| Instructor Guidance on Switching Views | [R-009] | [F-008](docs/exec-plans/current/epics/user-preview/tickets/F-008.md) / [MER-6218](https://eliterate.atlassian.net/browse/MER-6218) | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) |

## Shared and added requirements

| Requirement | Owning Story | Primary implementation |
| --- | --- | --- |
| [R-008] | Shared epic expectations; MER-6219 Closed Won’t Do | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md), [F-002](docs/exec-plans/current/epics/user-preview/tickets/F-002.md), [F-003](docs/exec-plans/current/epics/user-preview/tickets/F-003.md), [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md), [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md), [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md), [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md), [F-008](docs/exec-plans/current/epics/user-preview/tickets/F-008.md), [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md), [F-011](docs/exec-plans/current/epics/user-preview/tickets/F-011.md) |
| [R-010] | [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) / [MER-6220](https://eliterate.atlassian.net/browse/MER-6220) | [T-019](docs/exec-plans/current/epics/user-preview/tickets/T-019.md), [T-020](docs/exec-plans/current/epics/user-preview/tickets/T-020.md), [T-004](docs/exec-plans/current/epics/user-preview/tickets/T-004.md), [T-005](docs/exec-plans/current/epics/user-preview/tickets/T-005.md) |
| [R-011] | Shared classification acceptance; [F-011](docs/exec-plans/current/epics/user-preview/tickets/F-011.md) / [MER-6221](https://eliterate.atlassian.net/browse/MER-6221) Closed Won’t Do | [T-014](docs/exec-plans/current/epics/user-preview/tickets/T-014.md), [T-016](docs/exec-plans/current/epics/user-preview/tickets/T-016.md), [T-019](docs/exec-plans/current/epics/user-preview/tickets/T-019.md), [T-004](docs/exec-plans/current/epics/user-preview/tickets/T-004.md), [T-005](docs/exec-plans/current/epics/user-preview/tickets/T-005.md) |

## Project publication preview contributions

- [T-002](docs/exec-plans/current/epics/user-preview/tickets/T-002.md) supplies shared student presentation and the `instructor_view` assign rename.
- [T-014](docs/exec-plans/current/epics/user-preview/tickets/T-014.md), [T-015](docs/exec-plans/current/epics/user-preview/tickets/T-015.md), [T-016](docs/exec-plans/current/epics/user-preview/tickets/T-016.md) supply the marked review section, Publish-driven updates, readiness, and failed-state recovery.
- [T-019](docs/exec-plans/current/epics/user-preview/tickets/T-019.md), [T-020](docs/exec-plans/current/epics/user-preview/tickets/T-020.md) supply the author-linked preview identity and project-preview integration.
- [T-017](docs/exec-plans/current/epics/user-preview/tickets/T-017.md) supplies Publish entry and the complete Full Course Preview shell/exit.
- [T-018](docs/exec-plans/current/epics/user-preview/tickets/T-018.md) supplies the publication-aware Review card.

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

## Replacement feature Stories

Ten Stories and 20 sub-tasks remain active. F-009 / MER-6219 is Closed Won’t Do because it describes shared acceptance conditions already owned by the affected Stories. No separate verification task is planned. The 29 old issues are Closed Won’t Do; the 16 old Stories are removed from the epic’s child list, and their sub-tasks retain their historical parents. Old active S-*.md documents are removed; committed sources and the closed Jira issues retain their history. Repository publishing is on hold.

| Story | Requirement | Primary previous implementation | Jira | Status |
| --- | --- | --- | --- | --- |
| [F-001 — Instructor view to student preview](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | R-001 | S-001, S-002, S-003, S-016 | [MER-6211](https://eliterate.atlassian.net/browse/MER-6211) | Created and verified |
| [F-002 — Instructor preview notes](docs/exec-plans/current/epics/user-preview/tickets/F-002.md) | R-002 | S-005 | [MER-6212](https://eliterate.atlassian.net/browse/MER-6212) | Created and verified |
| [F-003 — Gating Instructor View/Student Preview Bypass](docs/exec-plans/current/epics/user-preview/tickets/F-003.md) | R-003 | S-004 | [MER-6213](https://eliterate.atlassian.net/browse/MER-6213) | Created and verified |
| [F-004 — Update authoring page preview](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) | R-004 | S-007 | [MER-6214](https://eliterate.atlassian.net/browse/MER-6214) | Created and verified |
| [F-005 — Activity bank preview](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) | R-005 | S-010, S-011 | [MER-6215](https://eliterate.atlassian.net/browse/MER-6215) | Created and verified |
| [F-006 — Inaccurate previews](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) | R-006 | S-008, S-009 | [MER-6216](https://eliterate.atlassian.net/browse/MER-6216) | Created and verified |
| [F-007 — Project publication preview](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | R-007 | S-012, S-014, S-013 | [MER-6217](https://eliterate.atlassian.net/browse/MER-6217) | Created and verified |
| [F-008 — Instructor Guidance on Switching Views](docs/exec-plans/current/epics/user-preview/tickets/F-008.md) | R-009 | S-006 | [MER-6218](https://eliterate.atlassian.net/browse/MER-6218) | Created and verified |
| [F-009 — Keep preview controls accessible and authorized](docs/exec-plans/current/epics/user-preview/tickets/F-009.md) | R-008 | Cross-linked primary owners | [MER-6219](https://eliterate.atlassian.net/browse/MER-6219) | Closed Won’t Do |
| [F-010 — Manage and reset the author-linked preview user](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) | R-010 | S-015 | [MER-6220](https://eliterate.atlassian.net/browse/MER-6220) | Created and verified |
| [F-011 — Identify preview users and sections](docs/exec-plans/current/epics/user-preview/tickets/F-011.md) | R-011 | Cross-linked primary owners | [MER-6221](https://eliterate.atlassian.net/browse/MER-6221) | Closed Won’t Do; acceptance in owning Stories |

## Ticket recreation migration

Each previous implementation has one primary destination. A flattened former parent maps to its sibling implementation sub-tasks, which retain its necessary technical context. Single-Story Feature guidance lives in the owning Story. “Migrated” confirms Jira content and relationships were read back; it does not claim implementation is complete. All previous issues remain Closed Won’t Do.

| Previous ID | Previous Jira | Primary new owner | Replacement local ID(s) | New corresponding Jira URL(s) | Migrated |
| --- | --- | --- | --- | --- | --- |
| S-001 | [MER-6182](https://eliterate.atlassian.net/browse/MER-6182) | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | [T-001](docs/exec-plans/current/epics/user-preview/tickets/T-001.md) | [MER-6222](https://eliterate.atlassian.net/browse/MER-6222) | Yes — created and verified |
| S-002 | [MER-6183](https://eliterate.atlassian.net/browse/MER-6183) | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | [T-002](docs/exec-plans/current/epics/user-preview/tickets/T-002.md) | [MER-6223](https://eliterate.atlassian.net/browse/MER-6223) | Yes — created and verified |
| S-003 | [MER-6184](https://eliterate.atlassian.net/browse/MER-6184) | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | [T-003](docs/exec-plans/current/epics/user-preview/tickets/T-003.md) | [MER-6224](https://eliterate.atlassian.net/browse/MER-6224) | Yes — created and verified |
| S-004 | [MER-6185](https://eliterate.atlassian.net/browse/MER-6185) | [F-003](docs/exec-plans/current/epics/user-preview/tickets/F-003.md) | [F-003](docs/exec-plans/current/epics/user-preview/tickets/F-003.md) | [MER-6213](https://eliterate.atlassian.net/browse/MER-6213) | Yes — created and verified |
| S-005 | [MER-6186](https://eliterate.atlassian.net/browse/MER-6186) | [F-002](docs/exec-plans/current/epics/user-preview/tickets/F-002.md) | [F-002](docs/exec-plans/current/epics/user-preview/tickets/F-002.md) | [MER-6212](https://eliterate.atlassian.net/browse/MER-6212) | Yes — created and verified |
| S-006 | [MER-6187](https://eliterate.atlassian.net/browse/MER-6187) | [F-008](docs/exec-plans/current/epics/user-preview/tickets/F-008.md) | [F-008](docs/exec-plans/current/epics/user-preview/tickets/F-008.md) | [MER-6218](https://eliterate.atlassian.net/browse/MER-6218) | Yes — created and verified |
| S-007 | [MER-6188](https://eliterate.atlassian.net/browse/MER-6188) | [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) | [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) | [MER-6214](https://eliterate.atlassian.net/browse/MER-6214) | Yes — created and verified |
| S-007a | [MER-6189](https://eliterate.atlassian.net/browse/MER-6189) | [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) | [T-006](docs/exec-plans/current/epics/user-preview/tickets/T-006.md) | [MER-6227](https://eliterate.atlassian.net/browse/MER-6227) | Yes — created and verified |
| S-007b | [MER-6190](https://eliterate.atlassian.net/browse/MER-6190) | [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) | [T-007](docs/exec-plans/current/epics/user-preview/tickets/T-007.md) | [MER-6228](https://eliterate.atlassian.net/browse/MER-6228) | Yes — created and verified |
| S-008 | [MER-6191](https://eliterate.atlassian.net/browse/MER-6191) | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) | [T-011](docs/exec-plans/current/epics/user-preview/tickets/T-011.md), [T-012](docs/exec-plans/current/epics/user-preview/tickets/T-012.md) | [MER-6232](https://eliterate.atlassian.net/browse/MER-6232), [MER-6233](https://eliterate.atlassian.net/browse/MER-6233) | Yes — created and verified |
| S-008a | [MER-6192](https://eliterate.atlassian.net/browse/MER-6192) | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) | [T-011](docs/exec-plans/current/epics/user-preview/tickets/T-011.md) | [MER-6232](https://eliterate.atlassian.net/browse/MER-6232) | Yes — created and verified |
| S-008b | [MER-6193](https://eliterate.atlassian.net/browse/MER-6193) | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) | [T-012](docs/exec-plans/current/epics/user-preview/tickets/T-012.md) | [MER-6233](https://eliterate.atlassian.net/browse/MER-6233) | Yes — created and verified |
| S-009 | [MER-6194](https://eliterate.atlassian.net/browse/MER-6194) | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) | [T-013](docs/exec-plans/current/epics/user-preview/tickets/T-013.md) | [MER-6234](https://eliterate.atlassian.net/browse/MER-6234) | Yes — created and verified |
| S-010 | [MER-6195](https://eliterate.atlassian.net/browse/MER-6195) | [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) | [T-008](docs/exec-plans/current/epics/user-preview/tickets/T-008.md), [T-009](docs/exec-plans/current/epics/user-preview/tickets/T-009.md) | [MER-6229](https://eliterate.atlassian.net/browse/MER-6229), [MER-6230](https://eliterate.atlassian.net/browse/MER-6230) | Yes — created and verified |
| S-010a | [MER-6196](https://eliterate.atlassian.net/browse/MER-6196) | [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) | [T-008](docs/exec-plans/current/epics/user-preview/tickets/T-008.md) | [MER-6229](https://eliterate.atlassian.net/browse/MER-6229) | Yes — created and verified |
| S-010b | [MER-6197](https://eliterate.atlassian.net/browse/MER-6197) | [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) | [T-009](docs/exec-plans/current/epics/user-preview/tickets/T-009.md) | [MER-6230](https://eliterate.atlassian.net/browse/MER-6230) | Yes — created and verified |
| S-011 | [MER-6198](https://eliterate.atlassian.net/browse/MER-6198) | [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) | [T-010](docs/exec-plans/current/epics/user-preview/tickets/T-010.md) | [MER-6231](https://eliterate.atlassian.net/browse/MER-6231) | Yes — created and verified |
| S-012 | [MER-6199](https://eliterate.atlassian.net/browse/MER-6199) | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | [T-014](docs/exec-plans/current/epics/user-preview/tickets/T-014.md), [T-015](docs/exec-plans/current/epics/user-preview/tickets/T-015.md), [T-016](docs/exec-plans/current/epics/user-preview/tickets/T-016.md) | [MER-6235](https://eliterate.atlassian.net/browse/MER-6235), [MER-6236](https://eliterate.atlassian.net/browse/MER-6236), [MER-6237](https://eliterate.atlassian.net/browse/MER-6237) | Yes — created and verified |
| S-012a | [MER-6200](https://eliterate.atlassian.net/browse/MER-6200) | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | [T-014](docs/exec-plans/current/epics/user-preview/tickets/T-014.md) | [MER-6235](https://eliterate.atlassian.net/browse/MER-6235) | Yes — created and verified |
| S-012b | [MER-6201](https://eliterate.atlassian.net/browse/MER-6201) | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | [T-015](docs/exec-plans/current/epics/user-preview/tickets/T-015.md) | [MER-6236](https://eliterate.atlassian.net/browse/MER-6236) | Yes — created and verified |
| S-012c | [MER-6202](https://eliterate.atlassian.net/browse/MER-6202) | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | [T-016](docs/exec-plans/current/epics/user-preview/tickets/T-016.md) | [MER-6237](https://eliterate.atlassian.net/browse/MER-6237) | Yes — created and verified |
| S-013 | [MER-6210](https://eliterate.atlassian.net/browse/MER-6210) | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | [T-018](docs/exec-plans/current/epics/user-preview/tickets/T-018.md) | [MER-6239](https://eliterate.atlassian.net/browse/MER-6239) | Yes — created and verified |
| S-014 | [MER-6209](https://eliterate.atlassian.net/browse/MER-6209) | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | [T-017](docs/exec-plans/current/epics/user-preview/tickets/T-017.md) | [MER-6238](https://eliterate.atlassian.net/browse/MER-6238) | Yes — created and verified |
| S-015 | [MER-6203](https://eliterate.atlassian.net/browse/MER-6203) | [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) | [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) | [MER-6220](https://eliterate.atlassian.net/browse/MER-6220) | Yes — created and verified |
| S-015a | [MER-6204](https://eliterate.atlassian.net/browse/MER-6204) | [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) | [T-019](docs/exec-plans/current/epics/user-preview/tickets/T-019.md) | [MER-6240](https://eliterate.atlassian.net/browse/MER-6240) | Yes — created and verified |
| S-015b | [MER-6205](https://eliterate.atlassian.net/browse/MER-6205) | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | [T-020](docs/exec-plans/current/epics/user-preview/tickets/T-020.md) | [MER-6241](https://eliterate.atlassian.net/browse/MER-6241) | Yes — created and verified |
| S-016 | [MER-6206](https://eliterate.atlassian.net/browse/MER-6206) | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | [T-004](docs/exec-plans/current/epics/user-preview/tickets/T-004.md), [T-005](docs/exec-plans/current/epics/user-preview/tickets/T-005.md) | [MER-6225](https://eliterate.atlassian.net/browse/MER-6225), [MER-6226](https://eliterate.atlassian.net/browse/MER-6226) | Yes — created and verified |
| S-016a | [MER-6207](https://eliterate.atlassian.net/browse/MER-6207) | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | [T-004](docs/exec-plans/current/epics/user-preview/tickets/T-004.md) | [MER-6225](https://eliterate.atlassian.net/browse/MER-6225) | Yes — created and verified |
| S-016b | [MER-6208](https://eliterate.atlassian.net/browse/MER-6208) | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | [T-005](docs/exec-plans/current/epics/user-preview/tickets/T-005.md) | [MER-6226](https://eliterate.atlassian.net/browse/MER-6226) | Yes — created and verified |

Historical Story sources: [tickets/ at the published pre-replacement commit](https://github.com/Simon-Initiative/oli-torus/tree/7b97d3a4fd0073fa99f94ce139c6df3659f21154/docs/exec-plans/current/epics/user-preview/tickets). The Decision log in the epic records review and migration decisions.

## Replacement technical dependencies

Seven Story-level Blocks links define delivery order; fourteen same-Story sub-task links define implementation order. No dependency crosses Story boundaries through a sub-task. Both graphs are acyclic.

| Prerequisite | Blocks |
| --- | --- |
| [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) / [MER-6211](https://eliterate.atlassian.net/browse/MER-6211) | [F-002](docs/exec-plans/current/epics/user-preview/tickets/F-002.md) / [MER-6212](https://eliterate.atlassian.net/browse/MER-6212) |
| [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) / [MER-6211](https://eliterate.atlassian.net/browse/MER-6211) | [F-003](docs/exec-plans/current/epics/user-preview/tickets/F-003.md) / [MER-6213](https://eliterate.atlassian.net/browse/MER-6213) |
| [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) / [MER-6211](https://eliterate.atlassian.net/browse/MER-6211) | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) / [MER-6217](https://eliterate.atlassian.net/browse/MER-6217) |
| [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) / [MER-6211](https://eliterate.atlassian.net/browse/MER-6211) | [F-008](docs/exec-plans/current/epics/user-preview/tickets/F-008.md) / [MER-6218](https://eliterate.atlassian.net/browse/MER-6218) |
| [F-002](docs/exec-plans/current/epics/user-preview/tickets/F-002.md) / [MER-6212](https://eliterate.atlassian.net/browse/MER-6212) | [F-003](docs/exec-plans/current/epics/user-preview/tickets/F-003.md) / [MER-6213](https://eliterate.atlassian.net/browse/MER-6213) |
| [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) / [MER-6220](https://eliterate.atlassian.net/browse/MER-6220) | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) / [MER-6211](https://eliterate.atlassian.net/browse/MER-6211) |
| [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) / [MER-6220](https://eliterate.atlassian.net/browse/MER-6220) | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) / [MER-6217](https://eliterate.atlassian.net/browse/MER-6217) |
| [T-001](docs/exec-plans/current/epics/user-preview/tickets/T-001.md) / [MER-6222](https://eliterate.atlassian.net/browse/MER-6222) | [T-003](docs/exec-plans/current/epics/user-preview/tickets/T-003.md) / [MER-6224](https://eliterate.atlassian.net/browse/MER-6224) |
| [T-002](docs/exec-plans/current/epics/user-preview/tickets/T-002.md) / [MER-6223](https://eliterate.atlassian.net/browse/MER-6223) | [T-003](docs/exec-plans/current/epics/user-preview/tickets/T-003.md) / [MER-6224](https://eliterate.atlassian.net/browse/MER-6224) |
| [T-003](docs/exec-plans/current/epics/user-preview/tickets/T-003.md) / [MER-6224](https://eliterate.atlassian.net/browse/MER-6224) | [T-005](docs/exec-plans/current/epics/user-preview/tickets/T-005.md) / [MER-6226](https://eliterate.atlassian.net/browse/MER-6226) |
| [T-004](docs/exec-plans/current/epics/user-preview/tickets/T-004.md) / [MER-6225](https://eliterate.atlassian.net/browse/MER-6225) | [T-005](docs/exec-plans/current/epics/user-preview/tickets/T-005.md) / [MER-6226](https://eliterate.atlassian.net/browse/MER-6226) |
| [T-006](docs/exec-plans/current/epics/user-preview/tickets/T-006.md) / [MER-6227](https://eliterate.atlassian.net/browse/MER-6227) | [T-007](docs/exec-plans/current/epics/user-preview/tickets/T-007.md) / [MER-6228](https://eliterate.atlassian.net/browse/MER-6228) |
| [T-008](docs/exec-plans/current/epics/user-preview/tickets/T-008.md) / [MER-6229](https://eliterate.atlassian.net/browse/MER-6229) | [T-009](docs/exec-plans/current/epics/user-preview/tickets/T-009.md) / [MER-6230](https://eliterate.atlassian.net/browse/MER-6230) |
| [T-009](docs/exec-plans/current/epics/user-preview/tickets/T-009.md) / [MER-6230](https://eliterate.atlassian.net/browse/MER-6230) | [T-010](docs/exec-plans/current/epics/user-preview/tickets/T-010.md) / [MER-6231](https://eliterate.atlassian.net/browse/MER-6231) |
| [T-011](docs/exec-plans/current/epics/user-preview/tickets/T-011.md) / [MER-6232](https://eliterate.atlassian.net/browse/MER-6232) | [T-012](docs/exec-plans/current/epics/user-preview/tickets/T-012.md) / [MER-6233](https://eliterate.atlassian.net/browse/MER-6233) |
| [T-012](docs/exec-plans/current/epics/user-preview/tickets/T-012.md) / [MER-6233](https://eliterate.atlassian.net/browse/MER-6233) | [T-013](docs/exec-plans/current/epics/user-preview/tickets/T-013.md) / [MER-6234](https://eliterate.atlassian.net/browse/MER-6234) |
| [T-014](docs/exec-plans/current/epics/user-preview/tickets/T-014.md) / [MER-6235](https://eliterate.atlassian.net/browse/MER-6235) | [T-015](docs/exec-plans/current/epics/user-preview/tickets/T-015.md) / [MER-6236](https://eliterate.atlassian.net/browse/MER-6236) |
| [T-015](docs/exec-plans/current/epics/user-preview/tickets/T-015.md) / [MER-6236](https://eliterate.atlassian.net/browse/MER-6236) | [T-016](docs/exec-plans/current/epics/user-preview/tickets/T-016.md) / [MER-6237](https://eliterate.atlassian.net/browse/MER-6237) |
| [T-016](docs/exec-plans/current/epics/user-preview/tickets/T-016.md) / [MER-6237](https://eliterate.atlassian.net/browse/MER-6237) | [T-020](docs/exec-plans/current/epics/user-preview/tickets/T-020.md) / [MER-6241](https://eliterate.atlassian.net/browse/MER-6241) |
| [T-017](docs/exec-plans/current/epics/user-preview/tickets/T-017.md) / [MER-6238](https://eliterate.atlassian.net/browse/MER-6238) | [T-018](docs/exec-plans/current/epics/user-preview/tickets/T-018.md) / [MER-6239](https://eliterate.atlassian.net/browse/MER-6239) |
| [T-020](docs/exec-plans/current/epics/user-preview/tickets/T-020.md) / [MER-6241](https://eliterate.atlassian.net/browse/MER-6241) | [T-017](docs/exec-plans/current/epics/user-preview/tickets/T-017.md) / [MER-6238](https://eliterate.atlassian.net/browse/MER-6238) |

## Replacement sub-tasks

All items are direct children of their owning Feature/requirement Story. Former intermediate parents are not recreated.

| Sub-task | Full title | Parent | Previous ID | Jira | Status |
| --- | --- | --- | --- | --- | --- |
| [T-001](docs/exec-plans/current/epics/user-preview/tickets/T-001.md) | Move Instructor View to dedicated routes | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | S-001 | [MER-6222](https://eliterate.atlassian.net/browse/MER-6222) | Created and verified |
| [T-002](docs/exec-plans/current/epics/user-preview/tickets/T-002.md) | Use route-based Instructor View and student presentation | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | S-002 | [MER-6223](https://eliterate.atlassian.net/browse/MER-6223) | Created and verified |
| [T-003](docs/exec-plans/current/epics/user-preview/tickets/T-003.md) | Add the view selector and preserve preview navigation | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | S-003 | [MER-6224](https://eliterate.atlassian.net/browse/MER-6224) | Created and verified |
| [T-004](docs/exec-plans/current/epics/user-preview/tickets/T-004.md) | Use the author-linked user for admin section previews | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | S-016a | [MER-6225](https://eliterate.atlassian.net/browse/MER-6225) | Created and verified |
| [T-005](docs/exec-plans/current/epics/user-preview/tickets/T-005.md) | Connect admin preview entry and activity requests | [F-001](docs/exec-plans/current/epics/user-preview/tickets/F-001.md) | S-016b | [MER-6226](https://eliterate.atlassian.net/browse/MER-6226) | Created and verified |
| [T-006](docs/exec-plans/current/epics/user-preview/tickets/T-006.md) | Share delivery page components with author preview | [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) | S-007a | [MER-6227](https://eliterate.atlassian.net/browse/MER-6227) | Created and verified |
| [T-007](docs/exec-plans/current/epics/user-preview/tickets/T-007.md) | Use shared delivery components in author Page Preview | [F-004](docs/exec-plans/current/epics/user-preview/tickets/F-004.md) | S-007b | [MER-6228](https://eliterate.atlassian.net/browse/MER-6228) | Created and verified |
| [T-008](docs/exec-plans/current/epics/user-preview/tickets/T-008.md) | Render one authorized bank question in preview | [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) | S-010a | [MER-6229](https://eliterate.atlassian.net/browse/MER-6229) | Created and verified |
| [T-009](docs/exec-plans/current/epics/user-preview/tickets/T-009.md) | Add bank-question preview launch and return | [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) | S-010b | [MER-6230](https://eliterate.atlassian.net/browse/MER-6230) | Created and verified |
| [T-010](docs/exec-plans/current/epics/user-preview/tickets/T-010.md) | Update bank action controls without changing behavior | [F-005](docs/exec-plans/current/epics/user-preview/tickets/F-005.md) | S-011 | [MER-6231](https://eliterate.atlassian.net/browse/MER-6231) | Created and verified |
| [T-011](docs/exec-plans/current/epics/user-preview/tickets/T-011.md) | Add limitation messages for unavailable page-preview content | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) | S-008a | [MER-6232](https://eliterate.atlassian.net/browse/MER-6232) | Created and verified |
| [T-012](docs/exec-plans/current/epics/user-preview/tickets/T-012.md) | Explain when an embedded activity cannot start in preview | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) | S-008b | [MER-6233](https://eliterate.atlassian.net/browse/MER-6233) | Created and verified |
| [T-013](docs/exec-plans/current/epics/user-preview/tickets/T-013.md) | Explain sample data and limited Page Preview interactions | [F-006](docs/exec-plans/current/epics/user-preview/tickets/F-006.md) | S-009 | [MER-6234](https://eliterate.atlassian.net/browse/MER-6234) | Created and verified |
| [T-014](docs/exec-plans/current/epics/user-preview/tickets/T-014.md) | Create and update the shared project preview section | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | S-012a | [MER-6235](https://eliterate.atlassian.net/browse/MER-6235) | Created and verified |
| [T-015](docs/exec-plans/current/epics/user-preview/tickets/T-015.md) | Show preview readiness and open Learn automatically | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | S-012b | [MER-6236](https://eliterate.atlassian.net/browse/MER-6236) | Created and verified |
| [T-016](docs/exec-plans/current/epics/user-preview/tickets/T-016.md) | Reset a failed project preview section | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | S-012c | [MER-6237](https://eliterate.atlassian.net/browse/MER-6237) | Created and verified |
| [T-017](docs/exec-plans/current/epics/user-preview/tickets/T-017.md) | Launch Full Course Preview from Publish | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | S-014 | [MER-6238](https://eliterate.atlassian.net/browse/MER-6238) | Created and verified |
| [T-018](docs/exec-plans/current/epics/user-preview/tickets/T-018.md) | Add the Full Course Preview card to Review | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | S-013 | [MER-6239](https://eliterate.atlassian.net/browse/MER-6239) | Created and verified |
| [T-019](docs/exec-plans/current/epics/user-preview/tickets/T-019.md) | Create and reset the author-linked preview user | [F-010](docs/exec-plans/current/epics/user-preview/tickets/F-010.md) | S-015a | [MER-6240](https://eliterate.atlassian.net/browse/MER-6240) | Created and verified |
| [T-020](docs/exec-plans/current/epics/user-preview/tickets/T-020.md) | Use the preview user throughout Full Course Preview | [F-007](docs/exec-plans/current/epics/user-preview/tickets/F-007.md) | S-015b | [MER-6241](https://eliterate.atlassian.net/browse/MER-6241) | Created and verified |

## Replacement execution result

- Retired all 16 previous Stories and 13 sub-tasks using Closed Won’t Do; no ticket was deleted.
- Removed the 16 retired Stories from MER-6158. Its child list contains exactly 11 replacement Stories, with 20 sub-tasks below them.
- Removed Technical Approach and its tail from the epic; preserved the preceding five rich-text nodes and recording exactly.
- Preserved all eight verbatim Feature sections, all original Figma URL targets, and 17 original PNG screenshots embedded as attachments.
- Migrated full technical contracts and analysis once under each primary owner; flattened former sub-tasks receive necessary parent context and bounded owned scope.
- Verified all 20 Blocks links, description text/structure/URLs, attachment bytes, and parent relationships. New work items are unassigned and retain project-default status/priority; no labels, components, versions, or estimates were added.
- Retained one active set of ticket documents. Repository changes remain local; pushing is explicitly on hold.

## Ticket description cleanup

Completed and verified: all 31 Jira descriptions match the cleaned F-/T- documents. Preserve requirements, acceptance outcomes, technical constraints, design links, screenshots, parents, sub-tasks, and existing Blocks links. Remove ticket-authoring and migration narrative, source readiness/placeholders, requirement-number references and Requirements analysis, redundant sub-task inventories, and Related implementation lists. The Story descriptions are the requirements; the historical requirement mapping remains local for traceability. Use native Jira relationships for those inventories. Repository publishing remains on hold.

The following 21 Relates links are verified in Linked work items; the current 21 Blocks links follow Story delivery boundaries, and MER-6241 belongs to MER-6217:

| Work item | Related work item |
| --- | --- |
| F-001 / MER-6211 | F-002 / MER-6212 |
| F-001 / MER-6211 | F-007 / MER-6217 |
| F-001 / MER-6211 | F-008 / MER-6218 |
| F-001 / MER-6211 | F-009 / MER-6219 |
| F-001 / MER-6211 | F-010 / MER-6220 |
| F-001 / MER-6211 | F-011 / MER-6221 |
| F-002 / MER-6212 | F-003 / MER-6213 |
| F-002 / MER-6212 | F-009 / MER-6219 |
| F-003 / MER-6213 | F-009 / MER-6219 |
| F-004 / MER-6214 | F-005 / MER-6215 |
| F-004 / MER-6214 | F-006 / MER-6216 |
| F-004 / MER-6214 | F-009 / MER-6219 |
| F-005 / MER-6215 | F-009 / MER-6219 |
| F-006 / MER-6216 | F-009 / MER-6219 |
| F-007 / MER-6217 | F-009 / MER-6219 |
| F-007 / MER-6217 | F-010 / MER-6220 |
| F-007 / MER-6217 | F-011 / MER-6221 |
| F-008 / MER-6218 | F-009 / MER-6219 |
| F-009 / MER-6219 | F-010 / MER-6220 |
| F-009 / MER-6219 | F-011 / MER-6221 |
| F-010 / MER-6220 | F-011 / MER-6221 |

## Story delivery boundaries

MER-6241 / T-020 belongs to F-007 / MER-6217. F-010 / MER-6220 delivers the reusable user resolver, reset and markers independently; F-001 / MER-6211 consumes that capability for admin preview. Project identity integration is owned and accepted by F-007. No admin-preview dependency on T-020 remains. Cross-Story dependencies are exclusively Story-level links.

Bank-management header suppression, local back navigation, and return focus are owned by F-001 / T-003 (MER-6224). F-002 (MER-6212) consumes that completed behavior and owns explanatory notes.

F-002 owns shared Instructor preview note presentation and bank-selection usage. F-003 consumes that presentation and owns gating-specific messages, actions, and state. MER-6212 blocks MER-6213 at Story level; neither Story requires the other’s implementation to be duplicated.
