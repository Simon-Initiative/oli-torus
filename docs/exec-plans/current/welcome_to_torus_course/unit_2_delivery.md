# Welcome to Torus Course

## Unit 2: Delivery Detailed Design

Last updated: 2026-03-26

This document expands Unit 2 from the outline in `overview.md`. It is intended to be the Phase 2 detail pass for the Delivery unit and to serve as the source material for later page authoring and MCP-based activity creation.

## Unit Goal

By the end of Unit 2, a learner should be able to:

- explain how sections relate to projects and publications
- create and configure a section for teaching
- distinguish learner-facing delivery from instructor-facing management
- describe how attempts, scoring, and review work in delivery
- use dashboards and section tools to support learners
- recognize when a delivery issue is caused by content, section setup, or integration context

## Unit Vocabulary

Use these terms consistently throughout the unit:

- Section
- Source materials
- Publication
- Open and Free
- LTI
- Schedule
- Gating
- Instructor dashboard
- Student view
- Attempt
- Feedback
- Gradebook
- Preview

## Module 2.1: Creating and Configuring Sections

### Module Goal

Teach learners how sections are created from source materials and configured for real course delivery.

### Learning Objectives

After this module, the learner should be able to:

- explain the relationship between published source materials and sections
- describe the workflow for creating a new section
- identify common section configuration areas
- distinguish direct delivery from LMS-integrated delivery at a practical level

### Page Plan

#### Page 1: From Project to Section

Summary:

- Reconnect the authoring publication model to delivery.
- Explain that instructors do not teach directly from a mutable project.
- Introduce the section as the operational delivery container.

Key teaching points:

- sections are delivery instances
- sections depend on source materials that come from publication state
- delivery stability depends on not teaching from draft authoring work

Suggested formative activity:

- Type: `oli_multiple_choice`
- Prompt idea: What is the best description of a section in Torus?
- Answer intent: a delivery instance built from published source materials

Media:

- `[Diagram placeholder: project -> publication -> section relationship]`

#### Page 2: Creating a New Section

Summary:

- Introduce the section creation flow and source selection step.
- Explain that the same concept may be used in direct delivery and LTI contexts.
- Keep focus on the mental model more than button-by-button instructions.

Key teaching points:

- section creation starts with choosing or confirming source materials
- the delivery context affects how the section is launched and used
- naming and setup decisions matter because instructors and learners see them later

Suggested formative activity:

- Type: `oli_ordering`
- Prompt idea: Order the workflow for launching a new section from source selection to configuration.

Media:

- `[Screenshot placeholder: new section creation or select source flow]`

#### Page 3: Editing Section Settings and Schedule

Summary:

- Explain that section delivery behavior is controlled by section-level settings, not only content.
- Introduce schedule and related management tools.

Key teaching points:

- section settings shape the live learning experience
- scheduling affects what learners can access and when
- instructors need to understand settings before a course begins

Suggested formative activity:

- Type: `oli_check_all_that_apply`
- Prompt idea: Which concerns are typically handled at the section level rather than the project-authoring level?

Media:

- `[Screenshot placeholder: section edit and schedule surfaces]`

#### Page 4: Open and Free vs LMS-Integrated Delivery

Summary:

- Contrast direct Torus delivery with LTI-backed delivery in plain language.
- Clarify what changes for learners, instructors, and administrators when LMS integration is involved.

Key teaching points:

- Open and Free supports direct access patterns
- LMS-integrated delivery depends on LTI context and configuration
- course teams need to understand which delivery model they are operating in

Suggested formative activity:

- Type: `oli_short_answer`
- Prompt idea: What is one practical difference between Open and Free delivery and LMS-integrated delivery?

### Module 2.1 Scored Assessment Blueprint

Title:

- Launch a Section

Assessment goal:

- verify that the learner understands the path from source materials to a configured delivery section

Recommended items:

- Item 1: `oli_multiple_choice`
  - Prompt: Why should sections be based on published source materials?
- Item 2: `oli_ordering`
  - Prompt: Order the major steps in creating a new section.
- Item 3: `oli_check_all_that_apply`
  - Prompt: Select the items commonly configured at the section level.
- Item 4: `oli_multiple_choice`
  - Scenario: An instructor needs the course to run through the LMS. Which delivery context matters most?
- Item 5: `oli_short_answer`
  - Prompt: Explain why section setup is distinct from project authoring.
- Item 6: `oli_multiple_choice`
  - Prompt: Which concept best represents the learner-facing teaching instance?

Mastery signal:

- learner can explain how a course moves from published content into a teachable section

## Module 2.2: Teaching with Torus

### Module Goal

Teach learners how instructors manage an active section and use delivery tools to support student progress.

### Learning Objectives

After this module, the learner should be able to:

- distinguish learner and instructor delivery surfaces
- identify where progress and participation data can be reviewed
- explain the role of scheduling and gating in active teaching
- describe how instructors use delivery signals to intervene with learners

### Page Plan

#### Page 1: Learner and Instructor Views

Summary:

- Show that delivery contains different experiences for different roles.
- Introduce learner-facing pages and instructor-facing management/dashboard tools.

Key teaching points:

- student delivery emphasizes content, assignments, and progress
- instructor delivery emphasizes visibility, monitoring, and management
- the same section can expose different surfaces depending on role

Suggested formative activity:

- Type: `oli_check_all_that_apply`
- Prompt idea: Which surfaces are more likely to be instructor-facing than learner-facing?

Media:

- `[Screenshot placeholder: compare learner view and instructor dashboard entry points]`

#### Page 2: Monitoring Progress and Participation

Summary:

- Introduce instructor dashboard concepts and downloadable views of progress.
- Emphasize how instructors use these surfaces to interpret section health.

Key teaching points:

- dashboards expose progress and performance trends
- progress data helps instructors identify who may need support
- exports and summaries help instructors work beyond the immediate UI

Suggested formative activity:

- Type: `oli_multiple_choice`
- Prompt idea: What is the main reason to review instructor dashboard progress data?

Media:

- `[Screenshot placeholder: instructor dashboard progress or summary view]`

#### Page 3: Managing Availability and Course Flow

Summary:

- Explain that delivery is not static after section creation.
- Introduce scheduling, gating, and assessment settings as instructor tools for controlling flow.

Key teaching points:

- instructors can shape pacing through schedule and gating tools
- availability rules affect learner access
- settings should reinforce instructional intent, not confuse it

Suggested formative activity:

- Type: `oli_ordering`
- Prompt idea: Put these instructor actions in a sensible teaching sequence: configure section, schedule content, monitor progress, adjust as needed.

Media:

- `[Screenshot placeholder: gating and scheduling interface]`

#### Page 4: Using Data to Support Learners

Summary:

- Move from monitoring to action.
- Show how instructors interpret progress, attempts, and dashboard signals in order to help learners.

Key teaching points:

- data is useful only when it informs support actions
- instructors should look for patterns, not isolated noise
- delivery tools help identify when intervention may be needed

Suggested formative activity:

- Type: `oli_short_answer`
- Prompt idea: What is one sign in delivery data that might prompt an instructor to intervene?

### Module 2.2 Scored Assessment Blueprint

Title:

- Run an Active Section

Assessment goal:

- verify that the learner understands how instructors monitor and manage a live course section

Recommended items:

- Item 1: `oli_multiple_choice`
  - Prompt: Which surface is designed for section monitoring rather than student content consumption?
- Item 2: `oli_check_all_that_apply`
  - Prompt: Select the kinds of information an instructor might review while teaching.
- Item 3: `oli_ordering`
  - Prompt: Order a sensible teaching workflow from configuration through support.
- Item 4: `oli_multiple_choice`
  - Scenario: A section is live, but students cannot yet access a lesson. Which section capability is most relevant?
- Item 5: `oli_short_answer`
  - Prompt: Why should instructors review progress trends rather than only single isolated events?
- Item 6: `oli_multiple_choice`
  - Prompt: What is the main purpose of instructor-facing delivery analytics?

Mastery signal:

- learner can connect instructor tools to real teaching decisions in a live section

## Module 2.3: Learner Experience, Attempts, and Grading

### Module Goal

Explain what learners experience in delivery and how attempts, scoring, feedback, and grading behave.

### Learning Objectives

After this module, the learner should be able to:

- describe the learner-facing delivery experience
- explain the basic lifecycle of an attempt
- distinguish feedback, review, and grading concepts
- identify where graded outcomes and instructor review tools fit in delivery

### Page Plan

#### Page 1: What Learners See on a Page

Summary:

- Describe the learner experience at the page and lesson level.
- Reinforce that delivery combines instruction with activities and progress.

Key teaching points:

- learners encounter content, activities, assignments, and navigation together
- page experience is shaped by delivery context and section settings
- the learner view is the operational result of authoring plus delivery configuration

Suggested formative activity:

- Type: `oli_multiple_choice`
- Prompt idea: Which statement best describes the learner-facing page experience in Torus?

Media:

- `[Screenshot placeholder: learner page or lesson view]`

#### Page 2: Attempts, Feedback, and Scoring

Summary:

- Introduce attempts as a core delivery concept.
- Explain that activities may involve attempts, feedback, scoring, and later review.

Key teaching points:

- an attempt records learner work on an activity or page context
- feedback may appear during or after submission depending on design
- scoring and evaluation are part of the delivery runtime

Suggested formative activity:

- Type: `oli_check_all_that_apply`
- Prompt idea: Which events may happen during or after a learner attempt?

#### Page 3: Grade Reporting and Section Outcomes

Summary:

- Explain gradebook and grade-related delivery surfaces at a high level.
- Clarify that grading is a section operation, not merely an authoring concern.

Key teaching points:

- section delivery includes gradebook and grade-related workflows
- instructor review and grade synchronization may matter in integrated contexts
- graded outcomes depend on both authored assessment design and delivery runtime behavior

Suggested formative activity:

- Type: `oli_short_answer`
- Prompt idea: Why should grade reporting be treated as a delivery concern instead of only an authoring concern?

Media:

- `[Screenshot placeholder: gradebook or grades view]`

#### Page 4: Delivery Troubleshooting Basics

Summary:

- Give course teams a simple framework for diagnosing common delivery issues.
- Emphasize distinction between content issue, section setup issue, and integration issue.

Key teaching points:

- some problems originate in authored content
- some problems originate in section configuration
- some problems originate in LMS or integration context
- correct triage improves support speed and accuracy

Suggested formative activity:

- Type: `oli_ordering`
- Prompt idea: Order the first troubleshooting checks you would make when a learner reports a delivery problem.

### Module 2.3 Scored Assessment Blueprint

Title:

- Understand the Learner Runtime

Assessment goal:

- verify that the learner understands learner-facing runtime behavior, attempts, and delivery-side grading

Recommended items:

- Item 1: `oli_multiple_choice`
  - Prompt: What best describes an attempt in delivery?
- Item 2: `oli_check_all_that_apply`
  - Prompt: Select the components that may be part of a learner's activity experience.
- Item 3: `oli_multiple_choice`
  - Scenario: An instructor wants to inspect scored outcomes for a section. Which area is most relevant?
- Item 4: `oli_ordering`
  - Prompt: Put the runtime flow in order from learner work to review.
- Item 5: `oli_short_answer`
  - Prompt: How can a course team tell the difference between a section setup issue and a content issue?
- Item 6: `oli_multiple_choice`
  - Prompt: Why is grading discussed in the delivery unit rather than only in authoring?

Mastery signal:

- learner can describe how authored activities become learner attempts, feedback, and grades in a live section

## Unit 2 Media Backlog

- `[Diagram placeholder: project/publication/section relationship]`
- `[Screenshot placeholder: new section or select source flow]`
- `[Screenshot placeholder: section edit and schedule views]`
- `[Screenshot placeholder: learner home or lesson view]`
- `[Screenshot placeholder: instructor dashboard]`
- `[Screenshot placeholder: gating and scheduling]`
- `[Screenshot placeholder: gradebook or grades tooling]`

## Delivery Notes For Later MCP Work

When this unit is converted into Torus content:

- keep scenarios concrete and role-based
- distinguish student, instructor, and administrator responsibilities in every assessment item
- prefer screenshots where the workflow depends on interface distinctions
- keep troubleshooting prompts focused on diagnosis, not unsupported implementation detail

## Recommended Next Slice

Expand Unit 3 assessment prompts into full item stems first if the course needs operational training emphasis, otherwise move to converting Unit 1 assessments into MCP-ready activity JSON.
