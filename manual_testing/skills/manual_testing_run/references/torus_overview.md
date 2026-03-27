# Torus Overview

Torus is a learning platform with three major operating surfaces:

- `authoring`: where course teams create, organize, edit, and publish learning content
- `delivery`: where instructors and learners access a course section and interact with published content
- `admin`: where system-support users with elevated authoring or platform administration access manage operational settings and support other users

## Core Product Shape
- A `project` is the authoring workspace for course content.
- A `publication` is an immutable published snapshot of project content.
- A `section` is a delivery instance that points learners and instructors at published content.
- A `page` is a navigable content unit inside a project or section.
- An `activity` is an interactive learning component embedded in or referenced from page content.
- The `activity bank` stores reusable activity content that authors can reference from pages.
- `learning objectives` are course-level instructional goals that can be attached to pages and, more importantly, to specific activities.

## High-Level Mental Model
- Authoring users work on draft content, page hierarchy, and publishing tasks.
- Delivery users work inside sections, not raw authoring projects.
- Admin users work in a separate support-oriented interface to manage system behavior and help other users.
- The same learning material can appear in both authoring and delivery, but the UI intent differs:
  - authoring emphasizes editability and content management
  - delivery emphasizes navigation, learner access, and progress
  - admin emphasizes support operations, system control, and user assistance

## Course Project Content Model

### Page Types
- `basic` pages are standard authored content pages.
- `adaptive` pages participate in adaptive learning flows and may behave differently from standard linear pages.

### Evaluation Modes
- `graded` pages contribute evaluative or scored work.
- `practice` pages emphasize rehearsal and learning without the same grading intent.

### Activities On Pages
- Pages can contain one or more activities.
- Common activity types include multiple choice, check-all-that-apply, short answer, and other interactive assessment types supported by the platform.
- A page may include inline configured activities or reference activities from the activity bank rather than defining all activity content directly on the page.

### Learning Objectives
- Course projects define learning objectives at the project level.
- Objectives can be attached to pages to indicate page-level instructional coverage.
- Objectives can also be attached directly to activities, which is often the more important linkage during authoring and assessment workflows.
- When testing authoring flows, objective attachment and visibility may matter at both the page and activity levels.

## Common Runtime Risks During Browser Testing
- Landing in the wrong surface because the environment contains authoring, delivery, and admin routes
- Seeing role-dependent navigation that hides actions expected by the case
- Looking at unpublished draft content when the case expects learner-visible published content
- Confusing project-level pages with section-level pages
- Confusing page-type or grading-mode expectations when the case depends on adaptive, graded, or practice behavior
- Confusing inline activities with bank-referenced activities when validating page content

## Browser-Agent Guidance
- First identify whether the case is authoring, delivery, or admin.
- Confirm the URL and visible navigation match that surface before executing deeper steps.
- Use page headings, left navigation, publish-related controls, learner navigation chrome, and admin controls as the primary cues.
- When a case involves page content, note whether the page appears to be basic or adaptive, and whether the visible flow suggests graded or practice behavior.
- When a case involves activities or objectives, distinguish between page-level metadata and activity-level metadata before deciding whether the expected result is satisfied.
