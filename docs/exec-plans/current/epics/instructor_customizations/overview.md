# Instructor Customization of Assessments - Epic Overview

This document provides a brief overview of the Instructor Customization of Assessments epic (`MER-5613`) and its lane-level implementation scope.

## Epic Summary

Instructor Customization of Assessments lets instructors, authors, and admins review course content from an instructor-facing view and tailor (essentially just enable / disable) assessment/practice questions for a specific section or template without changing authored source content.

The epic combines a core delivery implementation with updated Instructor View UI, new entry points, page-level remove/restore controls, learning objective and points summaries, jump navigation, and activity bank selection question management.

## Jira Scope

- Epic: `MER-5613`
- Linked roadmap context: `RMAP-95`
- Prototype reference: `https://torusux.vercel.app/`
- Figma is the styling and design-system source of truth for UI implementation.

Implementation stories:

- `MER-5639` Instructor activity customization, core implementation and scenario testing
- `MER-5617` Update Instructor View
- `MER-5618` Update Instructor View Question UI
- `MER-5619` New Entry Points to Instructor View
- `MER-5620` Activity Bank Selection & Embedded Question Remove/Restore
- `MER-5625` Learning Objective & Overall Points Available Counters
- `MER-5626` Jump to Section
- `MER-5622` Manage Questions in Activity Bank Selection
- `MER-5623` Multi-Select Questions within Activity Bank Selection
- `MER-5624` Filter Questions within Activity Bank Selection

## Feature Shape

The core implementation stores instructor customization state outside authored resources and section resources. It applies page-specific section customization when new attempts are created, while preserving historical attempts and avoiding changes to published source content.

The UI work updates Instructor View into the main workspace for reviewing and customizing page content. Instructors can enter from supported workflows, inspect simplified question displays, remove and restore embedded questions and activity bank selections, manage activity bank candidates, and see dynamic consequences such as available points and learning objective coverage.

## Epic-Wide Instructor View Contracts

Instructor View is the shared workspace for the UI stories in this epic. Shell-level primitives introduced by `MER-5617` should be reusable by later stories instead of being local to one LiveView.

The Instructor View header is an epic-wide shell primitive. It should render when a surface is in Instructor View / preview mode and should receive an explicit return context from the owning route or LiveView. Preview mode answers whether the shell is in Instructor View; return context answers where the user exits back to.

Return context should carry a safe internal destination and label derived from the originating workflow, such as Customize Content, Assessment Settings, Overview, or a template-level workflow. Later entry-point work in `MER-5619` can expand the set of origin tokens without changing the header component API.

Secondary Instructor View workflows, such as the Activity Bank Selection management view introduced by `MER-5622`, should preserve the same global exit context while owning their own local back behavior. For example, a bank-selection manager back button can return to the original preview page and anchor, while the persistent Instructor View header still returns to the workflow that launched Instructor View.

This epic initially targets basic pages for the LiveView shell migration. Adaptive and advanced page preview remain on their existing controller-owned preview routes unless a later ticket explicitly expands that scope.

## Related Documents

- `docs/exec-plans/current/epics/instructor_customizations/core/informal.md`
- `docs/exec-plans/current/epics/instructor_customizations/preview_components/informal.md`
- `docs/exec-plans/current/epics/instructor_customizations/preview_customization_wiring.md`
- `docs/exec-plans/current/epics/instructor_customizations/instructor_view_shell/prd.md`
- `docs/exec-plans/current/epics/instructor_customizations/plan.md`

## Development Lanes

1. Core-Impl
2. Core-UI
3. Page-UI
4. Selection-UI

Full lane descriptions and dependency-ordered execution plan are documented in `docs/exec-plans/current/epics/instructor_customizations/plan.md`.

## Decision Log

### 2026-05-29 - Instructor View Header Contract
- Change: Added epic-wide Instructor View shell contracts and corrected related document references.
- Reason: Review of `MER-5619`, `MER-5622`, and related epic tickets showed that the persistent Instructor View header and return-to-origin behavior must be reusable across multiple surfaces, not only the `MER-5617` basic-page LiveView.
- Evidence: Jira `MER-5613`, `MER-5617`, `MER-5619`, and `MER-5622`; existing docs under `docs/exec-plans/current/epics/instructor_customizations`.
- Impact: Later ticket docs and implementations should preserve the separation between preview mode, global return context, and local back navigation.
