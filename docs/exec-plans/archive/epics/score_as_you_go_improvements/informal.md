# Score-as-you-go Improvements - Informal Source Context

Last updated: 2026-05-29

This document captures initial Jira context for the Score-as-you-go Improvements epic. It is intentionally informal source material for later PRD/FDD/plan work.

## Source Tickets

- Roadmap: `RMAP-125` Score-as-you-go improvements
  - Type: Minor Epic
  - Status: Hand Off
  - Priority: Medium
  - Assignee: Jess Fortunato
  - Reporter: Amanda Buddemeyer
  - Created: 2026-02-10
  - Updated: 2026-05-06
- Delivery epic: `MER-5616` Score-as-you-go improvements
  - Type: Epic
  - Status: Analyzing
  - Priority: Medium
  - Reporter: Jess Fortunato
  - Created: 2026-05-06
  - Updated: 2026-05-06
- Related triage epic: `TRIAGE-2168` Score-as-you-go improvements
  - Status: Backlog
  - Linked to `RMAP-125`

## Roadmap Goals

`RMAP-125` frames this as a lightweight epic. The roadmap goal is to remove confusion around Score at the End (SATE) versus Score as You Go (SAYG) behavior, especially when assessment settings change after students have started work.

Key goals from the roadmap:

- Avoid confusing student experiences when an assessment changes scoring mode between SATE and SAYG.
- Clarify or constrain instructor setting changes after students have started attempts.
- Prevent adaptive pages from being configured with SAYG because that combination does not function correctly.
- Include related adaptive-page setting restrictions where appropriate: retake mode, presentation, scoring mode, replacement, view feedback, and view answers.
- Review Assignment Terms page language for clarity using the Norman-provided spec: https://simon-oli.notion.site/Assessment-Settings-and-Terms-Page-1362cca102ce80cea250c3cf06eef61a?pvs=74

Roadmap success signals:

- Students are no longer confused about what an attempt means in SATE versus SAYG.
- Students understand whether they are working through page attempts or question attempts.
- Instructors understand when settings cannot be changed and why.
- Instructors understand why SAYG is unavailable for adaptive pages.

## Related Triage Context

`RMAP-125` says it exists to resolve issues attached to the related triage epic. Jira currently shows these relevant triage children or linked implementation issues:

- `TRIAGE-2130` Scored pages must fully adapt to score as you go
  - Issue: SAYG pages with multiple attempts can still present page-attempt language after submission, causing users to expect additional page attempts even though SAYG attempts are per question.
  - Comment: closed because it will be handled in V34 SAYG improvements.
- `TRIAGE-1920` Score as you go showing submit button
  - Issue: L&P lab assignments believed to be SAYG displayed a submit button, leading at least one student to submit and become locked out.
  - Important clarification: authored assessment setting changes do not propagate into live sections; section settings must be changed in the instructor interface.
  - Product concern: setting changes should probably propagate only when no students have started, and should be constrained once attempts exist.
- `TRIAGE-1861` Assessment settings should not apply to adaptive pages
  - Issue: settings intended for basic pages can affect adaptive pages; SAYG in particular can prevent additional adaptive-page attempts.
  - Related implementation: `MER-5608` Assessment settings should not apply to adaptive pages, status Done.
- `TRIAGE-1691` inconsistencies between one at a time with score as you go vs score at the end
  - Issue: one-at-a-time question presentation can show confusing submit controls across SATE and SAYG.
  - Comment: no design justification was found for a generic submit response button in score-at-the-end assessments; removing it may reduce confusion while preserving activity-specific submit controls.

## MER-5616 Child Stories

- `MER-5627` Assignment terms page updates
  - Redesign Assignment Terms into grouped summary cards for schedule, time limit, scoring, and attempts.
  - Remove the Assignment Required tag and date information below the page title.
  - Explain SAYG as individually submitted/scored questions with per-question attempts and scoring-strategy behavior.
  - Include dynamic replacement language when relevant.
  - Update primary CTA labels for begin, resume, and later attempts.
  - Show past attempts and preserve review behavior.
  - Comments note open copy/configuration questions around grace period, retake mode, and "start" versus "Begin".
- `MER-5628` SAYG assignment updates
  - Update the overall page score component to approved Figma designs.
  - Keep score visible as a sticky header during scrolling without covering content, inputs, feedback, or navigation.
  - Use `Text/text-accent-green` for question-level point tracking: light `#218358`, dark `#39E581`.
- `MER-5629` SAYG reset modal updates
  - Add a warning modal before resetting a SAYG question.
  - Explain score impact based on scoring strategy, current or best score, attempts taken, attempts remaining, and replacement behavior.
  - Reset only after explicit confirmation.
- `MER-5630` Instructor scoring mode change warning
  - Show a lock icon near scoring mode when students have started attempts on a scored page.
  - When changing scoring mode after attempts exist, show a confirmation modal.
  - Confirmed changes apply only to future attempts and do not affect existing scores.
  - Assignment Terms UI should update after confirmed scoring mode changes.
- `MER-5631` Student interface SAYG icons
  - Display SAYG icon and label in Assignments, course home, and schedule surfaces.
  - Avoid showing SAYG indicators for non-SAYG assignments.
- `MER-5632` Navigating away from SAYG assignment
  - Show a dismissible saved-work toast or banner when a student exits or navigates away from a SAYG assignment.
  - Include due-date or read-by-date copy only when relevant.
  - Avoid implying submission when work was only saved.
- `MER-5633` Presentation "one at a time" mode updates
  - Update one-at-a-time assignment UI to approved Figma designs.
  - Remove point-part breakdown information and container borders.
  - Avoid nested horizontal or vertical scrolling.
  - Comment requests a mobile version.
- `MER-5634` Assessment settings bulk apply (missing settings)
  - Ensure existing Bulk Apply works for Scoring Mode, Replacement, and Allow Hints.
  - Avoid regressing other bulk apply settings or unintentionally changing unsupported settings.

## Figma References Found In Jira

Primary design file:

- https://www.figma.com/design/z9gZStNwSgJk2rh9ntXj9c/Score-as-you-go-designs

Referenced nodes:

- Assignment Terms mobile: `679-4403`
- Assignment Terms SATE scenarios: `530-3466`, `607-10846`, `530-3578`, `530-3703`
- Assignment Terms SAYG scenarios: `530-3894`, `602-10707`, `530-4007`, `602-10574`
- SAYG assignment mobile/header: `693-2806`
- Traditional/presentation start and feedback states: `530-4398`, `530-4148`, `537-3084`, `530-4261`
- SAYG logic: `530-5198`
- Reset modal: `530-4869`
- Instructor scoring mode lock icon: `530-8016`
- Instructor scoring mode modals: `530-9042`
- Student interface indicators: `530-3234`, `530-3171`, `530-3108`
- Navigating away saved-work message: `530-5485`

## Open Questions

- Should scoring mode become fully disabled once any student starts an assessment, or should the system allow confirmed changes that apply only to future attempts?
- Which adaptive-page restrictions remain in scope after `MER-5608`?
- How should grace periods and retake mode be represented on the updated Assignment Terms page?
- Should CTA copy standardize on "Begin" rather than "Start"?
- Which one-at-a-time submit controls are generic presentation chrome versus activity-specific controls that must remain?
- Should Bulk Apply respect the same started-attempt and adaptive-page restrictions as single-assessment setting changes?
