# Instructor Customization of Assessments - Epic Overview

Last updated: 2026-05-12

This document provides a brief overview of the Instructor Customization of Assessments epic (`MER-5613`) and its lane-level implementation scope.

## Epic Summary

Instructor Customization of Assessments lets instructors, authors, and admins review course content from an instructor-facing view and tailor assessment/practice questions for a specific section or template without changing authored source content.

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

## Related Documents

- `docs/exec-plans/current/epics/instructor_customizations/core/informal.md`
- `docs/exec-plans/current/epics/instructor_customizations/plan.md`

## Development Lanes

1. Core-Impl
2. Core-UI
3. Page-UI
4. Selection-UI

Full lane descriptions and dependency-ordered execution plan are documented in `docs/exec-plans/current/epics/instructor_customizations/plan.md`.
