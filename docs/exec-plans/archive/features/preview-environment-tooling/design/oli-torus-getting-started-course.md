# OLI Torus Getting Started Course

## Purpose

`oli_torus_getting_started_course` is the bundled course-seeding scenario for development and
pull-request preview environments. It creates a cohesive course that introduces the core Torus
authoring-to-delivery workflow while also producing realistic learner progress and gradebook data
for QA and demonstrations.

The scenario is a one-time initializer for a fresh or deliberately reset database. It contains only
synthetic identities and no credentials.

## Learning Objectives

The project uses two parent objectives with four assessable sub-objectives:

- Author effective course content
  - Organize projects into units and pages
  - Align activities with learning objectives
- Publish course materials
  - Distinguish projects, publications, and sections
  - Sequence the authoring-to-delivery workflow

Pages and activities attach to the sub-objective that they teach or assess.

## Course Structure

```text
Getting Started with OLI Torus
├── Authoring with Torus
│   ├── Welcome to OLI Torus
│   ├── Organize Your Course
│   └── Design Activities for Learning
└── Publishing and Delivery
    ├── Publish and Deliver Your Course
    └── Getting Started Assessment
```

The first four pages are ungraded. `Getting Started Assessment` is graded.

## Page Content and Activity Map

### Welcome to OLI Torus

- Purpose: Orient a new author to the project workspace and the course lifecycle.
- Page objective: Distinguish projects, publications, and sections.
- Content:
  - A project is the editable authoring workspace.
  - A publication is a stable snapshot of project content.
  - A section delivers a publication to enrolled learners.
  - Authors can continue revising a project without silently changing a published learner
    experience.
- Activity: `torus_workspace_mcq` (`oli_multiple_choice`).
  - Prompt: Which Torus object is the editable authoring workspace?
  - Correct response: Project.
  - Hint: Look for the object where authors arrange and revise content.
  - Correct feedback: A project is the editable workspace.
  - Incorrect feedback: Publications are snapshots and sections are delivery instances.

### Organize Your Course

- Purpose: Demonstrate how containers and pages create a navigable curriculum.
- Page objective: Organize projects into units and pages.
- Content:
  - Containers group related material into units or modules.
  - Pages contain explanations, examples, media, and activities.
  - Clear titles and a deliberate order help learners understand where they are and what comes next.
- Activity: `course_structure_ordering` (`oli_ordering`).
  - Prompt: Order the steps for creating a small course structure.
  - Correct order: Create a project; add a unit; add pages; review the learner sequence.
  - Hint: Start with the authoring workspace and finish by checking the learner path.
  - Correct feedback: The hierarchy grows from project to container to pages, then review.
  - Incorrect feedback: Create the workspace before adding structure and review the sequence last.

### Design Activities for Learning

- Purpose: Show how objectives, practice, hints, and feedback work together.
- Page objective: Align activities with learning objectives.
- Content:
  - Start with observable learning objectives.
  - Attach activities to the objectives they provide evidence for.
  - Use low-stakes practice, targeted hints, and explanatory feedback to help learners improve.
  - Preview both correct and incorrect paths before publishing.
- Activity: `aligned_activity_cata` (`oli_check_all_that_apply`).
  - Prompt: Which authoring choices support aligned learning?
  - Correct responses: Attach activities to objectives; provide useful hints and feedback.
  - Hint: Choose practices that connect evidence and learner support to the intended outcome.
  - Correct feedback: Alignment and actionable support make practice useful.
  - Incorrect feedback: Decorative content alone does not establish alignment or feedback.

### Publish and Deliver Your Course

- Purpose: Explain publication, section creation, and the learner-facing delivery boundary.
- Page objectives:
  - Distinguish projects, publications, and sections.
  - Sequence the authoring-to-delivery workflow.
- Content:
  - Preview and review the project before publishing.
  - Publishing creates a stable snapshot.
  - Create a section from the publication and enroll learners in that section.
  - Later authoring changes require another publication and an intentional section update.
- Activities:
  - `publication_term_short_answer` (`oli_short_answer`).
    - Prompt: What action creates a stable snapshot for delivery?
    - Correct response contains: publish.
    - Hint: It is the action between authoring and section delivery.
    - Correct feedback: Publishing creates the stable snapshot used for delivery.
    - Incorrect feedback: Preview checks content, but publishing creates the snapshot.
  - `delivery_objects_multi_input` (`oli_multi_input`, combined submission).
    - Prompt: Complete the flow: authors revise a ___; learners study in a ___.
    - Correct responses: project; section.
    - Hint: One object is editable by authors and the other is the learner delivery instance.
    - Correct feedback: Projects are authored and sections are delivered.
    - Incorrect feedback: Publications connect the project to the section but are not either blank.

### Getting Started Assessment

- Purpose: Provide scored evidence across the complete introductory workflow.
- Page objectives: all four sub-objectives.
- Content:
  - A short introduction tells learners that the assessment covers course structure, activity
    alignment, publication, and delivery.
  - The assessment references all five activities above so every native response type supported by
    progress simulation is exercised in scored delivery.
- Scoring: normal Torus evaluators score responses, and normal section grading policy retains
  assessment results. The simulator may make multiple submissions according to each learner profile.

## Synthetic Cohort

The scenario creates one instructor and 12 learners with generated realistic names. Learners are
assigned deterministically by count:

- 3 `high_proficiency`
- 4 `steady_learner`
- 3 `persistent_learner`
- 2 `low_engagement`

Fast simulation is the automated default. Paced simulation remains an explicit operator-run
workflow and is not used by the preview initialization Job.

## Verification Map

| Contract | Evidence |
| --- | --- |
| Curriculum hierarchy and graded/ungraded roles | YAML `assert.structure` plus integration inspection of published revisions |
| Page and activity objective mapping | YAML `assert.page_objectives` and `assert.activity_objectives` |
| Rich prose, hints, and feedback | Integration inspection of page/activity revision content |
| Publication, section, and enrollment | Scenario execution state and enrollment queries |
| Native response support and real attempts | Evaluated activity/part-attempt queries by registration slug |
| Learner progress and grades | Resource-access and gradebook queries after `simulate_progress` |
