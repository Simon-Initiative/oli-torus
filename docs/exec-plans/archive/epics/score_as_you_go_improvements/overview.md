# Score-as-you-go Improvements - Epic Overview

This document provides a brief overview of the Score-as-you-go Improvements epic (`MER-5616`) and its roadmap context (`RMAP-125`).

## Epic Summary

Score-as-you-go Improvements clarifies the student and instructor experience around Score as You Go (SAYG) and Score at the End (SATE) assessment behavior. The epic focuses on reducing confusion around attempts, setting changes, unsupported adaptive-page configurations, Assignment Terms language, reset flows, saved-work messaging, and SAYG indicators across delivery surfaces.

The work is intentionally smaller than a full-team sprint epic. `RMAP-125` frames it as a lightweight package that could be handled by roughly one developer in one sprint or less, though the current `MER-5616` child list contains several UI and setting-safety stories that may need lane-level slicing.

## Jira Scope

- Roadmap: `RMAP-125` Score-as-you-go improvements
- Delivery epic: `MER-5616` Score-as-you-go improvements
- Related triage epic: `TRIAGE-2168` Score-as-you-go improvements

Implementation stories currently under `MER-5616`:

- `MER-5627` Assignment terms page updates
- `MER-5628` SAYG assignment updates
- `MER-5629` SAYG reset modal updates
- `MER-5630` Instructor scoring mode change warning
- `MER-5631` Student interface SAYG icons
- `MER-5632` Navigating away from SAYG assignment
- `MER-5633` Presentation "one at a time" mode updates
- `MER-5634` Assessment settings bulk apply (missing settings)

Related triage and implementation context:

- `TRIAGE-2130` Scored pages must fully adapt to score as you go
- `TRIAGE-1920` Score as you go showing submit button
- `TRIAGE-1861` Assessment settings should not apply to adaptive pages
- `TRIAGE-1691` inconsistencies between one at a time with score as you go vs score at the end
- `MER-5608` Assessment settings should not apply to adaptive pages

## Feature Shape

The epic has three broad concerns:

1. Student comprehension
   - Assignment Terms should explain schedule, attempts, scoring mode, scoring strategy, replacement behavior, and past attempts in plain language.
   - SAYG surfaces should make clear that students work through question attempts, not ordinary page attempts.
   - Leaving a SAYG assignment should communicate saved progress without implying final submission.

2. Instructor setting safety
   - Instructors should see when scoring mode is risky or constrained because students have already started.
   - Changing SATE/SAYG after attempts exist should either be prevented or explicitly confirmed as future-attempt-only behavior.
   - Bulk Apply should support missing assessment settings while respecting the same safety rules as single-setting edits.

3. Delivery UI consistency
   - SAYG score state should remain visible without obstructing assignment content.
   - One-at-a-time presentation should avoid nested scrolling and confusing submit controls.
   - SAYG labels and icons should appear consistently across Assignments, course home, and schedule surfaces.

## Success Signals

- Students understand whether an assignment uses page attempts or per-question attempts.
- Students do not see controls or copy that imply additional SAYG page attempts after completion.
- Students can leave and return to SAYG work with clear saved-progress messaging.
- Instructors understand when scoring mode or adaptive-page settings cannot be changed and why.
- Existing scores and completed attempts are not changed by later setting updates.

## Related Documents

- `docs/exec-plans/current/epics/score_as_you_go_improvements/informal.md`
- `docs/exec-plans/current/epics/score_as_you_go_improvements/plan.md`

## Development Lanes

1. Terms-and-Language
2. Setting-Safety
3. SAYG-Student-Workflow
4. Presentation-and-Surfaces

Full lane descriptions and dependency-ordered execution plan are documented in `docs/exec-plans/current/epics/score_as_you_go_improvements/plan.md`.
