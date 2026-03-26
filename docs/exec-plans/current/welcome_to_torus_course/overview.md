# Welcome to Torus Course Outline

Last updated: 2026-03-26

This document is the Phase 1 artifact for the `Welcome to Torus` course project. It captures the initial research pass across docs, routing, activity support, and platform concepts, then turns that research into a first-pass course outline that can be expanded in later phases.

## Purpose

The course should teach a new user how to use Torus across three major product domains:

- Authoring
- Delivery
- Administration

The course should feel like a practical product walkthrough, not abstract documentation. Each module should end with a scored assessment. Pages should include formative activities where those activities reinforce a concrete workflow or decision.

## Research Basis

This outline is grounded in the following repository references:

- `docs/PRODUCT_SENSE.md`
  - Confirms the core user roles and product split across authoring, delivery, and administration.
- `ARCHITECTURE.md`
  - Establishes the system map and the boundary between authoring and delivery.
- `docs/design-docs/publication-model.md`
  - Confirms the central publish-to-section workflow and why publication must be taught explicitly.
- `docs/FRONTEND.md`
  - Confirms the main frontend surfaces for authoring and delivery.
- `docs/BACKEND.md`
  - Confirms the major backend contexts and operational boundaries.
- `lib/oli_web/router.ex`
  - Confirms concrete routes and live surfaces for authoring, sections, admin, institutions, registrations, publishers, and ingest.
- `assets/src/components/activities/*/manifest.json`
  - Confirms built-in formative and assessment activity types available for course design.

## Working Assumptions

- The audience is a first-time Torus user who may act as an author, instructor, or administrator.
- The course is product training, so examples should use realistic workflows and UI terminology from Torus.
- The course should teach the publication boundary clearly:
  - authors edit projects
  - instructors teach sections backed by publications
  - administrators configure the environment that makes both workflows possible
- Images and videos may be useful, but they are not required to complete Phase 1.
- Media should be inserted later with explicit placeholders rather than invented now.

## Supported Activity Palette

These activity types are clearly present in the codebase and should be the default palette for this course:

- `oli_multiple_choice`
- `oli_check_all_that_apply`
- `oli_ordering`
- `oli_short_answer`

Use these activity types in two ways:

- Formative checks inside content pages
- Scored module assessments at the end of each module

## Course Shape

- 3 units
- 9 modules total
- 3 modules per unit
- 3 to 4 instructional pages per module
- 1 scored assessment page per module

This produces a course that is large enough to feel complete, but still small enough to build iteratively.

## Unit Outline

### Unit 1: Authoring

#### Module 1.1: Getting Started in Authoring

Goal: help a new author understand the project model, authoring workspace, and the difference between projects, pages, and activities.

Pages:

- Page 1: What Torus Authoring Is
  - Introduces the author role, project-based authoring, and revision-aware content work.
  - Formative activity: `oli_multiple_choice`
  - Media placeholder: `[Screenshot placeholder: authoring project landing page]`
- Page 2: Navigating the Authoring Workspace
  - Covers projects list, curriculum, pages, activities, preview, review, and publish entry points.
  - Formative activity: `oli_check_all_that_apply`
  - Media placeholder: `[Screenshot placeholder: authoring navigation and workspace areas]`
- Page 3: Understanding Resources, Revisions, and Publications
  - Explains why authors can keep editing without disrupting live delivery.
  - Formative activity: `oli_ordering`
  - Media placeholder: `[Diagram placeholder: resource -> revision -> publication -> section]`
- Page 4: Collaborating Safely
  - Covers collaborators, locks, and basic workflow discipline.
  - Formative activity: `oli_short_answer`

Scored assessment:

- Module 1.1 Assessment: Authoring Foundations Check
  - Mix of multiple choice, check-all-that-apply, and ordering
  - Measures understanding of core authoring concepts and navigation

#### Module 1.2: Building Course Structure

Goal: teach authors how to organize a project into units, modules, and pages.

Pages:

- Page 1: Designing a Course Hierarchy
  - Covers units, modules, and page placement.
  - Formative activity: `oli_ordering`
- Page 2: Creating and Organizing Curriculum Containers
  - Covers curriculum editing and structure maintenance.
  - Formative activity: `oli_check_all_that_apply`
  - Media placeholder: `[Screenshot placeholder: curriculum editor]`
- Page 3: Creating Pages for Learning Flow
  - Covers page purpose, page sequence, and page naming conventions.
  - Formative activity: `oli_short_answer`
- Page 4: Planning Assessments in the Structure
  - Shows where formative practice belongs and where scored module checks belong.
  - Formative activity: `oli_multiple_choice`

Scored assessment:

- Module 1.2 Assessment: Structure a Course Module
  - Scenario-based questions on hierarchy, page placement, and assessment placement

#### Module 1.3: Authoring Content, Activities, and Publishing

Goal: teach authors how to create instruction, embed activities, preview, review, and publish.

Pages:

- Page 1: Building Effective Instructional Pages
  - Covers concise explanatory pages, practice opportunities, and media placeholders.
  - Formative activity: `oli_check_all_that_apply`
- Page 2: Adding Formative Activities
  - Covers multiple choice, ordering, short answer, and check-all-that-apply as practical instructional tools.
  - Formative activity: `oli_multiple_choice`
  - Media placeholder: `[Screenshot placeholder: activity creation flow]`
- Page 3: Previewing and Reviewing a Project
  - Covers preview, review, and QA mindset before publish.
  - Formative activity: `oli_short_answer`
- Page 4: Publishing and Updating Content
  - Covers publish workflow and the impact on downstream sections.
  - Formative activity: `oli_ordering`
  - Media placeholder: `[Screenshot placeholder: publish workflow]`

Scored assessment:

- Module 1.3 Assessment: Publish with Confidence
  - Scenario-based scored questions on when to preview, review, and publish

### Unit 2: Delivery

#### Module 2.1: Creating and Configuring Sections

Goal: teach instructors or delivery managers how sections are created from source materials and configured for teaching.

Pages:

- Page 1: From Project to Section
  - Covers the relationship between published content and sections.
  - Formative activity: `oli_multiple_choice`
- Page 2: Creating a New Section
  - Covers section creation, source selection, and delivery context.
  - Formative activity: `oli_ordering`
  - Media placeholder: `[Screenshot placeholder: new section flow]`
- Page 3: Editing Section Settings and Schedule
  - Covers section edit and schedule workflows.
  - Formative activity: `oli_check_all_that_apply`
- Page 4: Open and Free vs LMS-Integrated Delivery
  - Covers the practical differences between direct delivery and LTI-backed delivery.
  - Formative activity: `oli_short_answer`

Scored assessment:

- Module 2.1 Assessment: Launch a Section
  - Checks understanding of section creation, configuration, and source material choice

#### Module 2.2: Teaching with Torus

Goal: teach instructors how to manage course delivery once a section is live.

Pages:

- Page 1: Learner and Instructor Views
  - Covers the difference between learner-facing delivery and instructor-facing controls.
  - Formative activity: `oli_check_all_that_apply`
- Page 2: Monitoring Progress and Participation
  - Covers dashboards, progress monitoring, and instructional follow-up.
  - Formative activity: `oli_multiple_choice`
  - Media placeholder: `[Screenshot placeholder: instructor dashboard]`
- Page 3: Managing Availability and Course Flow
  - Covers scheduling, visibility, and pacing decisions.
  - Formative activity: `oli_ordering`
- Page 4: Using Data to Support Learners
  - Covers how instructors use progress and assessment signals to intervene.
  - Formative activity: `oli_short_answer`

Scored assessment:

- Module 2.2 Assessment: Run an Active Section
  - Scenario-based teaching decisions tied to dashboards, pacing, and learner support

#### Module 2.3: Learner Experience, Attempts, and Grading

Goal: explain what learners experience in delivery and how graded work behaves.

Pages:

- Page 1: What Learners See on a Page
  - Covers instructional pages, activities, and feedback behavior.
  - Formative activity: `oli_multiple_choice`
- Page 2: Attempts, Feedback, and Scoring
  - Covers attempt lifecycle, feedback timing, and scored work.
  - Formative activity: `oli_check_all_that_apply`
- Page 3: Grade Reporting and Section Outcomes
  - Covers grades as a delivery concern and, where applicable, LMS-connected outcomes.
  - Formative activity: `oli_short_answer`
- Page 4: Delivery Troubleshooting Basics
  - Covers common delivery issues a course team should recognize before escalating.
  - Formative activity: `oli_ordering`

Scored assessment:

- Module 2.3 Assessment: Understand the Learner Runtime
  - Checks understanding of attempts, scoring, and delivery behavior

### Unit 3: Administration

#### Module 3.1: Institutions, Roles, and Access

Goal: teach administrators how Torus access is organized and governed.

Pages:

- Page 1: What Administration Owns
  - Covers the admin role in enabling authoring and delivery.
  - Formative activity: `oli_multiple_choice`
- Page 2: Managing Users, Authors, and Permissions
  - Covers user and author management responsibilities.
  - Formative activity: `oli_check_all_that_apply`
- Page 3: Institutions and Organizational Boundaries
  - Covers institution records and why tenancy boundaries matter.
  - Formative activity: `oli_short_answer`
  - Media placeholder: `[Screenshot placeholder: institutions admin view]`

Scored assessment:

- Module 3.1 Assessment: Admin Access Foundations
  - Checks role, institution, and account-management understanding

#### Module 3.2: Registrations, Deployments, and Integrations

Goal: teach administrators how LMS and external integrations are configured at a high level.

Pages:

- Page 1: LTI Concepts for Torus Administrators
  - Covers registrations, deployments, and the admin responsibility boundary.
  - Formative activity: `oli_multiple_choice`
- Page 2: Managing Registrations and Deployments
  - Covers the admin surfaces for creating and maintaining integration records.
  - Formative activity: `oli_ordering`
  - Media placeholder: `[Screenshot placeholder: registrations and deployments UI]`
- Page 3: External Tools and Delivery Dependencies
  - Covers how integrations affect downstream delivery workflows.
  - Formative activity: `oli_check_all_that_apply`
- Page 4: Integration Readiness Checklist
  - Covers the operational checklist before enabling an institution or section.
  - Formative activity: `oli_short_answer`

Scored assessment:

- Module 3.2 Assessment: Integration Readiness Check
  - Scenario-based scored questions on registrations, deployments, and setup validation

#### Module 3.3: Operations, Governance, and Support

Goal: teach administrators the recurring operational responsibilities that keep Torus usable and safe.

Pages:

- Page 1: Section and Product Oversight
  - Covers admin visibility into products, sections, and related management surfaces.
  - Formative activity: `oli_check_all_that_apply`
- Page 2: Ingest, Publishers, and Platform Operations
  - Covers ingestion, publisher management, and operational tooling awareness.
  - Formative activity: `oli_multiple_choice`
- Page 3: Security, Performance, and Escalation Paths
  - Covers what admins should monitor and when to escalate.
  - Formative activity: `oli_short_answer`
- Page 4: Supporting Authors and Instructors
  - Covers cross-functional support patterns and triage expectations.
  - Formative activity: `oli_ordering`

Scored assessment:

- Module 3.3 Assessment: Operate and Support the Platform
  - Checks operational judgment and support routing

## Assessment Design Rules

Each module assessment should:

- be scored
- contain 5 to 8 items
- use at least two activity types
- favor scenario-based prompts over definition recall
- end with a clear mastery signal for the module goal

Recommended assessment mix:

- 3 to 4 `oli_multiple_choice`
- 1 to 2 `oli_check_all_that_apply`
- 1 `oli_ordering`
- 1 `oli_short_answer` when the module benefits from explanation or applied judgment

## Media Placeholder Rules

Use explicit placeholders during authoring when a screenshot, diagram, or video would help but is not yet produced.

Placeholder format:

- `[Screenshot placeholder: short description]`
- `[Diagram placeholder: short description]`
- `[Video placeholder: short description]`

## Phase Plan

### Phase 1: Outline

Completed in this document:

- course purpose
- research basis
- supported activity palette
- full unit/module/page outline
- assessment and media placeholder strategy

### Phase 2: Module Detail Pass

Next, expand each module with:

- learning objectives
- page-level key concepts
- page summaries
- formative activity prompts
- media placeholder placement

### Phase 3: Assessment Authoring Pass

After the detailed module pass, author:

- full scored assessment blueprints for each module
- item stems
- answer keys
- feedback guidance
- MCP-ready activity JSON where applicable

## Recommended Next Slice

The next document should expand Unit 1 first because it establishes the vocabulary the other two units depend on:

- authoring workspace
- curriculum structure
- revisions and publications
- activity authoring
- publish workflow
