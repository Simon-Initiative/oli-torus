# Content Authoring with TorusDoc

This document covers directives for creating and editing content using the TorusDoc YAML format.

## Table of Contents
- [Overview](#overview)
- [create_activity](#create_activity) - Create standalone activities
- [activity_bank](#activity_bank) - Execute Activity Bank workflows
- [edit_page](#edit_page) - Edit page content
- [TorusDoc Format](#torusdoc-format)
- [Virtual IDs](#virtual-ids)
- [Activity Types](#activity-types)

---

## Overview

TorusDoc is a YAML-based format for defining OLI content. It provides a human-readable way to create:
- Pages with rich content blocks
- Activities (assessments/questions)
- Complex page structures with groups and surveys

The `create_activity` and `edit_page` directives use TorusDoc to define content in test scenarios.
The `activity_bank` directive exercises author-facing Activity Bank operations
such as querying, duplicating, editing, and deleting banked activities.

---

## create_activity

Creates a standalone activity that can be referenced in pages.

### Parameters
- `project`: Target project name (required)
- `title`: Activity title for referencing
- `virtual_id`: Scenario-local identifier for the activity (optional)
- `scope`: "embedded" or "banked" (default: "embedded")
- `type`: Activity type slug (e.g., "oli_multiple_choice")
- `content_format`: "torusdoc" (default) or "json"
- `content`: TorusDoc YAML content (for `content_format: torusdoc`) or JSON object/string (for `content_format: json`)
- `objectives`: List of learning objective titles to attach (optional)
- `tags`: List of tag titles to attach (optional)

### Examples

#### Multiple Choice Activity
```yaml
- create_activity:
    project: "my_project"
    title: "Math Question 1"
    virtual_id: "math_q1"
    type: "oli_multiple_choice"
    content: |
      stem_md: "What is 2 + 2?"
      choices:
        - id: "a"
          body_md: "3"
          score: 0
        - id: "b"
          body_md: "4"
          score: 1
        - id: "c"
          body_md: "5"
          score: 0
```

#### Short Answer Activity
```yaml
- create_activity:
    project: "my_project"
    title: "Open Response"
    virtual_id: "short_1"
    type: "oli_short_answer"
    content: |
      stem_md: "Explain the water cycle in your own words."
      input_type: "text"
```

#### Multi-Input Activity
```yaml
- create_activity:
    project: "my_project"
    title: "Fill in the Blanks"
    virtual_id: "multi_1"
    type: "oli_multi_input"
    content: |
      stem_md: "Complete the equation"
      inputs:
        - id: "input1"
          type: "numeric"
        - id: "input2"
          type: "text"
      rule: "input1 == 4 && input2 like 'correct'"
```

#### Activity with Learning Objectives
```yaml
# First create project with objectives
- project:
    name: "my_project"
    objectives:
      - Understand concepts:
        - Apply formulas
        - Solve problems

# Then create activity attached to objectives
- create_activity:
    project: "my_project"
    title: "Practice Problem"
    type: "oli_multiple_choice"
    objectives:
      - "Apply formulas"
      - "Solve problems"
    content: |
      stem_md: "Calculate the area of a circle with radius 5"
      choices:
        - id: "a"
          body_md: "25π"
          score: 1
        - id: "b"
          body_md: "10π"
          score: 0
```

**Note**: Objectives are attached by title. The project must have these objectives defined before activities can reference them.

#### Adaptive Activity Using JSON Content
```yaml
- create_activity:
    project: "my_project"
    title: "Adaptive Internal Iframe"
    type: "oli_adaptive"
    content_format: "json"
    content:
      authoring:
        parts:
          - id: "iframe_1"
            type: "janus-capi-iframe"
            src: "/course/link/page_two"
            sourceType: "page"
            linkType: "page"
            idref: 123
      partsLayout:
        - id: "iframe_1"
          type: "janus-capi-iframe"
          src: "/course/link/page_two"
          sourceType: "page"
          linkType: "page"
          idref: 123
```

#### Activity with Tags
```yaml
# First create project with tags
- project:
    name: "my_project"
    tags:
      - "Beginner"
      - "Practice"
      - "Quiz"

# Then create activity with tags
- create_activity:
    project: "my_project"
    title: "Tagged Question"
    type: "oli_multiple_choice"
    tags:
      - "Beginner"
      - "Practice"
    content: |
      stem_md: "What is the capital of France?"
      choices:
        - id: "a"
          body_md: "Paris"
          score: 1
        - id: "b"
          body_md: "London"
          score: 0
```

**Note**: Tags are attached by title. The project must have these tags defined before activities can reference them.

---

## activity_bank

Executes ordered Activity Bank operations for a project. Use this directive when
the behavior under test is the Activity Bank itself: bank queries, bulk creation,
duplication, edits, deletes, and query result assertions.

For simple setup where a scenario only needs a reusable banked activity, prefer
`create_activity` with `scope: "banked"`. Activities created that way are still
queryable by `activity_bank`.

### Parameters

- `project`: Target project name (required)
- `ops`: Ordered list of Activity Bank operations (required)

### Operations

#### create

Creates one banked activity through the Activity Bank path.

```yaml
- activity_bank:
    project: "my_project"
    ops:
      - create:
          title: "Easy Addition"
          virtual_id: "easy_addition"
          type: "oli_multiple_choice"
          tags: ["easy"]
          objectives: ["Understand arithmetic"]
          content: |
            stem_md: "What is 2 + 2?"
            choices:
              - id: "a"
                body_md: "4"
                score: 1
              - id: "b"
                body_md: "5"
                score: 0
```

`create` accepts the same activity content fields as `create_activity`: `title`,
`virtual_id`, `type` or `activity_type_slug`, `content_format`, `content`,
`objectives`, and `tags`.

#### create_bulk

Creates multiple banked activities in one operation.

```yaml
- activity_bank:
    project: "my_project"
    ops:
      - create_bulk:
          activities:
            - title: "Question One"
              virtual_id: "q1"
              type: "oli_multiple_choice"
              content: |
                stem_md: "Question one?"
                choices:
                  - id: "a"
                    body_md: "Yes"
                    score: 1
            - title: "Question Two"
              virtual_id: "q2"
              type: "oli_multiple_choice"
              content: |
                stem_md: "Question two?"
                choices:
                  - id: "a"
                    body_md: "Yes"
                    score: 1
```

#### query

Queries banked activities in the project's working publication. Query results can
be named and reused by a later `assert` operation.

```yaml
- activity_bank:
    project: "my_project"
    ops:
      - query:
          name: "easy_questions"
          filters:
            tags:
              contains: ["easy"]
          expect:
            total_count: 2
            contains_titles: ["Easy Addition", "Easy Geometry"]
            not_titles: ["Cell Function"]
```

Supported friendly filters:

- `tags`: `contains`, `does_not_contain`, `equals`, `does_not_equal`
- `objectives`: `contains`, `does_not_contain`, `equals`, `does_not_equal`
- `type`: `contains`, `does_not_contain`
- `text`: `contains`

Tag and objective filter values may use titles declared on the project. Type
filters may use activity type slugs. For type filters, use a list with
`contains`, for example:

```yaml
filters:
  type:
    contains: ["oli_multiple_choice"]
```

Advanced tests can pass raw Activity Bank realizer logic with `logic` instead of
`filters`.

#### edit

Edits a banked activity by `virtual_id`, `title`, or `resource_id`.

```yaml
- activity_bank:
    project: "my_project"
    ops:
      - edit:
          virtual_id: "q1"
          set:
            title: "Reviewed Question"
            tags: ["review"]
```

`set` supports Activity Bank update fields such as `title`, `content`,
`objectives`, and `tags`. The scenario handler acquires the authoring lock before
editing, matching the UI lifecycle.

#### delete

Deletes a banked activity by `virtual_id`, `title`, or `resource_id`.

```yaml
- activity_bank:
    project: "my_project"
    ops:
      - delete:
          virtual_id: "obsolete_question"
```

#### duplicate

Duplicates a banked activity and optionally assigns a new scenario-local
`virtual_id`.

```yaml
- activity_bank:
    project: "my_project"
    ops:
      - duplicate:
          virtual_id: "q1"
          new_title: "Question One Copy"
          new_virtual_id: "q1_copy"
```

#### assert

Asserts against a named query result produced earlier in the same `activity_bank`
directive.

```yaml
- activity_bank:
    project: "my_project"
    ops:
      - query:
          name: "review_questions"
          filters:
            tags:
              contains: ["review"]
      - assert:
          result: "review_questions"
          expect:
            total_count: 1
            contains_titles: ["Reviewed Question"]
```

### Expectations

Query and stored-result assertions support:

- `total_count`: Total matching rows before paging
- `row_count`: Rows returned for the current page
- `titles`: Exact returned title list
- `contains_titles`: Titles that must be present
- `not_titles`: Titles that must be absent
- `resource_ids`: Exact returned resource ID list

Prefer title-based expectations in YAML. Resource IDs are generated at runtime
and are mainly useful for lower-level tests.

### Complete Example

```yaml
- project:
    name: "bank_project"
    title: "Bank Project"
    tags:
      - "draft"
      - "review"
    root:
      children:
        - page: "Practice"

- activity_bank:
    project: "bank_project"
    ops:
      - create:
          title: "Draft Question"
          virtual_id: "draft_q"
          type: "oli_multiple_choice"
          tags: ["draft"]
          content: |
            stem_md: "Draft question?"
            choices:
              - id: "a"
                body_md: "Yes"
                score: 1
              - id: "b"
                body_md: "No"
                score: 0
      - duplicate:
          virtual_id: "draft_q"
          new_title: "Reviewed Question"
          new_virtual_id: "review_q"
      - edit:
          virtual_id: "review_q"
          set:
            tags: ["review"]
      - query:
          name: "review_questions"
          filters:
            tags:
              contains: ["review"]
          expect:
            total_count: 1
            contains_titles: ["Reviewed Question"]
            not_titles: ["Draft Question"]
```

---

## edit_page

Edits an existing page's content using TorusDoc YAML.

### Parameters
- `project`: Target project name (required)
- `page`: Title of the page to edit (required)
- `objectives`: List of learning objective titles to attach to the page (optional)
- `content`: TorusDoc page YAML content with blocks

### Page Structure

Pages contain an array of blocks:
- **prose**: Markdown text content
- **activity**: Inline activity definition
- **activity_reference**: Reference to existing activity
- **group**: Container for grouped content
- **survey**: Container for survey questions

### Examples

#### Simple Page with Text
```yaml
- edit_page:
    project: "my_project"
    page: "Introduction"
    content: |
      title: "Course Introduction"
      graded: false
      blocks:
        - type: prose
          body_md: |
            # Welcome to the Course

            This course covers the fundamentals of programming.

            ## Learning Objectives
            - Understand variables and data types
            - Write simple functions
            - Debug basic programs

        - type: prose
          body_md: "Let's begin with a simple exercise."
```

#### Page with Inline Activities
```yaml
- edit_page:
    project: "my_project"
    page: "Quiz Page"
    content: |
      title: "Chapter 1 Quiz"
      graded: true
      blocks:
        - type: prose
          body_md: "Answer the following questions:"

        # Inline activity with virtual_id
        - type: activity
          virtual_id: "q1"
          activity:
            type: oli_multiple_choice
            stem_md: "Which of these is a programming language?"
            choices:
              - id: "a"
                body_md: "Python"
                score: 1
              - id: "b"
                body_md: "HTML"
                score: 0
              - id: "c"
                body_md: "CSS"
                score: 0

        # Another inline activity
        - type: activity
          virtual_id: "q2"
          activity:
            type: oli_short_answer
            stem_md: "What does 'API' stand for?"
            input_type: "text"
```

#### Inline Activities with Learning Objectives
```yaml
# Create project with objectives
- project:
    name: "my_project"
    objectives:
      - Programming Basics:
        - Identify languages
        - Understand syntax

# Edit page with inline activities that attach to objectives
- edit_page:
    project: "my_project"
    page: "Practice Page"
    content: |
      title: "Practice Questions"
      blocks:
        - type: activity
          virtual_id: "lang_q"
          activity:
            type: oli_multiple_choice
            objectives:
              - "Identify languages"
            stem_md: "Which is a compiled language?"
            choices:
              - id: "a"
                body_md: "C++"
                score: 1
              - id: "b"
                body_md: "JavaScript"
                score: 0
```

**Note**: Objectives in inline activities work the same way - they're referenced by title and must exist in the project.

#### Page with Learning Objectives
```yaml
- objectives:
    project: "my_project"
    ops:
      - create:
          title: "Understand syntax"

- edit_page:
    project: "my_project"
    page: "Practice Page"
    objectives:
      - "Understand syntax"
    content: |
      title: "Practice Page"
      blocks:
        - type: prose
          body_md: "Practice using syntax."
```

**Note**: Page objectives are resolved by title and attached through the same page editing path used by authoring.

#### Inline Activities with Tags
```yaml
# Create project with tags
- project:
    name: "my_project"
    tags:
      - "Easy"
      - "Medium"
      - "Hard"

# Edit page with inline activities that have tags
- edit_page:
    project: "my_project"
    page: "Practice Page"
    content: |
      title: "Practice Questions"
      blocks:
        - type: activity
          virtual_id: "easy_q"
          activity:
            type: oli_multiple_choice
            tags:
              - "Easy"
            stem_md: "What is 2 + 2?"
            choices:
              - id: "a"
                body_md: "4"
                score: 1
              - id: "b"
                body_md: "5"
                score: 0
```

**Note**: Tags in inline activities work the same way - they're referenced by title and must exist in the project.

---

## Objective Assertions

### Page Objective Assertions

`assert.page_objectives` verifies the learning objective titles attached to a published delivery page.

```yaml
- assert:
    page_objectives:
      section: "my_section"
      page: "Practice Page"
      expected:
        - "Understand syntax"
```

### Activity Objective Assertions

`assert.activity_objectives` verifies the learning objective titles attached to a scenario-created activity by virtual id.

```yaml
- assert:
    activity_objectives:
      project: "my_project"
      activity_virtual_id: "syntax_q1"
      expected:
        - "Apply syntax"
```

#### Page with Activity References
```yaml
# First create standalone activities
- create_activity:
    project: "my_project"
    title: "Reusable Question 1"
    virtual_id: "shared_q1"
    type: "oli_multiple_choice"
    content: |
      stem_md: "What is object-oriented programming?"
      choices:
        - id: "a"
          body_md: "A programming paradigm"
          score: 1
        - id: "b"
          body_md: "A type of database"
          score: 0

# Then reference them in pages
- edit_page:
    project: "my_project"
    page: "Lesson 1"
    content: |
      title: "Lesson 1: OOP Basics"
      blocks:
        - type: prose
          body_md: "## Introduction to OOP"

        # Reference the standalone activity
        - type: activity_reference
          virtual_id: "shared_q1"

        - type: prose
          body_md: "Great! Now let's explore more concepts."
```

#### Page with Groups
```yaml
- edit_page:
    project: "my_project"
    page: "Grouped Content"
    content: |
      title: "Lesson with Groups"
      blocks:
        - type: prose
          body_md: "This lesson has grouped exercises."

        - type: group
          purpose: "quiz"
          blocks:
            - type: prose
              body_md: "**Group Exercise 1**"

            - type: activity
              virtual_id: "group_q1"
              activity:
                type: oli_multiple_choice
                stem_md: "Question in group"
                choices:
                  - id: "a"
                    body_md: "Answer A"
                    score: 1
                  - id: "b"
                    body_md: "Answer B"
                    score: 0

            - type: activity
              virtual_id: "group_q2"
              activity:
                type: oli_short_answer
                stem_md: "Explain your reasoning"
                input_type: "text"
```

#### Page with Survey
```yaml
- edit_page:
    project: "my_project"
    page: "Course Feedback"
    content: |
      title: "End of Course Survey"
      blocks:
        - type: prose
          body_md: "Please provide your feedback:"

        - type: survey
          blocks:
            - type: prose
              body_md: "Your responses help us improve the course."

            - type: activity
              virtual_id: "survey_q1"
              activity:
                type: oli_multiple_choice
                stem_md: "How would you rate this course?"
                choices:
                  - id: "5"
                    body_md: "Excellent"
                    score: 1
                  - id: "4"
                    body_md: "Good"
                    score: 1
                  - id: "3"
                    body_md: "Average"
                    score: 1
                  - id: "2"
                    body_md: "Poor"
                    score: 1

            - type: activity
              virtual_id: "survey_q2"
              activity:
                type: oli_short_answer
                stem_md: "What did you like most about the course?"
                input_type: "text"
```

---

## TorusDoc Format

### Page Properties
- `title`: Page title (updates the page name)
- `graded`: Boolean indicating if page is graded
- `blocks`: Array of content blocks

### Block Types

#### prose
```yaml
- type: prose
  body_md: "Markdown content here"
```

#### activity (inline)
```yaml
- type: activity
  virtual_id: "unique_id"  # Optional
  activity:
    type: "activity_type"
    # Activity-specific fields
```

#### activity_reference
```yaml
- type: activity_reference
  virtual_id: "existing_activity_id"
```

#### group
```yaml
- type: group
  purpose: "quiz"  # or other purposes
  blocks:
    # Nested blocks
```

#### survey
```yaml
- type: survey
  blocks:
    # Survey questions
```

---

## Virtual IDs

Virtual IDs are scenario-local identifiers for activities that enable:
- Creating activities once and referencing them multiple times
- Referencing activities across pages
- Student simulation (answering specific questions)

We need virtual ids because when creating an activity, we do not know
the resource id that its revision will end up having.  So instead, we
rely on these ephemeral "virtual ids" to define and later reference
an activity.

### How Virtual IDs Work

1. **Creation**: Assign a virtual_id when creating an activity
2. **Storage**: The scenario engine tracks virtual_id → activity mappings
3. **Reference**: Use the virtual_id to reference the activity
4. **Reuse**: Same virtual_id always refers to the same activity instance

### Example Workflow
```yaml
# 1. Create activity with virtual_id
- create_activity:
    project: "my_project"
    virtual_id: "reusable_q1"
    type: "oli_multiple_choice"
    content: |
      stem_md: "Reusable question"
      choices:
        - id: "a"
          body_md: "Option A"
          score: 1

# 2. Reference in multiple pages
- edit_page:
    project: "my_project"
    page: "Page 1"
    content: |
      blocks:
        - type: activity_reference
          virtual_id: "reusable_q1"

- edit_page:
    project: "my_project"
    page: "Page 2"
    content: |
      blocks:
        - type: activity_reference
          virtual_id: "reusable_q1"

# 3. Students can answer by virtual_id
- answer_question:
    student: "alice"
    section: "my_section"
    page: "Page 1"
    activity_virtual_id: "reusable_q1"
    response: "a"
```

---

## Activity Types

### oli_multiple_choice
```yaml
type: oli_multiple_choice
stem_md: "Question text"
choices:
  - id: "unique_id"
    body_md: "Choice text"
    score: 0 or 1
```

### oli_short_answer
```yaml
type: oli_short_answer
stem_md: "Question text"
input_type: "text" or "numeric"
```

#### Math Expression Short Answer

Use `input_type: math_expression` with a `math_expression` block. Supported subtypes are
`numeric`, `algebraic`, `number_with_units`, `expression_with_units`, `integer`, `decimal`,
`fraction`, `simplified_fraction`, and `latex_direct`.

```yaml
type: oli_short_answer
stem_md: "Enter one half as a simplified fraction."
input_type: math_expression
math_expression:
  subtype: simplified_fraction
responses:
  - answer: "1/2"
    score: 2
    correct: true
    feedback_md: "Correct."
  - answer: "1/2"
    score: 1
    math_expression:
      subtype: fraction
    feedback_md: "Equivalent, but simplify."
  - catch_all: true
    score: 0
    feedback_md: "Incorrect."
```

For algebraic and expression-with-units questions, set variable validation and domains:

```yaml
type: oli_short_answer
stem_md: "Enter an expression equivalent to x squared plus two x."
input_type: math_expression
math_expression:
  subtype: algebraic
  validation:
    allowed_variables: ["x"]
    domains:
      - variable: "x"
        lower: -5
        upper: 5
        integer_only: true
        exclusions: [0]
responses:
  - answer: "x^2 + 2*x"
    score: 1
    correct: true
```

For unit-aware questions, set a unit policy. `match_wrong_units: true` creates a targeted
response for a mathematically correct value with unacceptable units. `match_missing_unit: true`
creates a targeted response for a mathematically correct value submitted without units.

```yaml
type: oli_short_answer
stem_md: "Enter ten meters per second."
input_type: math_expression
math_expression:
  subtype: number_with_units
  unit_policy:
    type: convertible_units
    units: ["m/s", "cm/s"]
responses:
  - answer: "10 m/s"
    score: 2
    correct: true
  - answer: "10 m/s"
    score: 1
    match_wrong_units: true
    feedback_md: "Use the requested units."
  - answer: "10 m/s"
    score: 1
    match_missing_unit: true
    feedback_md: "Include the requested units."
```

### oli_multi_input
```yaml
type: oli_multi_input
stem_md: "Question text"
inputs:
  - id: "input1"
    type: "text" or "numeric"
rule: "Evaluation rule expression"
```

#### Math Expression Multi Input

Use `{{input_id}}` placeholders in `stem_md`; each math-expression input becomes a separately
evaluated part. Scenario `answer_question.response` can be a YAML map keyed by input id.

```yaml
type: oli_multi_input
stem_md: "Enter speed {{speed}} and energy {{energy}}."
inputs:
  - id: speed
    input_type: math_expression
    math_expression:
      subtype: number_with_units
      unit_policy:
        type: convertible_units
        units: ["m/s", "km/hr"]
    responses:
      - answer: "10 m/s"
        score: 1
        correct: true
  - id: energy
    input_type: math_expression
    math_expression:
      subtype: expression_with_units
      validation:
        allowed_variables: ["m", "v"]
      unit_policy:
        type: convertible_units
        units: ["J", "kJ"]
    responses:
      - answer: "1000 J"
        score: 1
        correct: true
```

```yaml
- answer_question:
    student: "student"
    section: "section"
    page: "Practice"
    activity_virtual_id: "multi_math"
    response:
      speed: "36 km/hr"
      energy: "1 kJ"
```

### oli_check_all_that_apply
```yaml
type: oli_check_all_that_apply
stem_md: "Question text"
choices:
  - id: "unique_id"
    body_md: "Choice text"
    score: 0 or 1
```

### oli_ordering
```yaml
type: oli_ordering
stem_md: "Put these in order"
choices:
  - id: "first"
    body_md: "First item"
  - id: "second"
    body_md: "Second item"
```

---

## Complete Example

```yaml
# Create a project
- project:
    name: "complete_lesson"
    title: "Complete Lesson Example"
    root:
      children:
        - page: "Lesson"
        - page: "Practice"
        - page: "Assessment"

# Create reusable activities
- create_activity:
    project: "complete_lesson"
    title: "Concept Check 1"
    virtual_id: "concept_1"
    type: "oli_multiple_choice"
    content: |
      stem_md: "What is a variable?"
      choices:
        - id: "a"
          body_md: "A container for storing data"
          score: 1
        - id: "b"
          body_md: "A type of loop"
          score: 0

- create_activity:
    project: "complete_lesson"
    title: "Concept Check 2"
    virtual_id: "concept_2"
    type: "oli_short_answer"
    content: |
      stem_md: "Explain the difference between a variable and a constant."
      input_type: "text"

# Edit lesson page
- edit_page:
    project: "complete_lesson"
    page: "Lesson"
    content: |
      title: "Variables and Constants"
      graded: false
      blocks:
        - type: prose
          body_md: |
            # Variables and Constants

            In programming, we use **variables** to store data that can change,
            and **constants** to store data that remains fixed.

            ## Variables
            Variables are like labeled boxes where you can store values.

        - type: activity_reference
          virtual_id: "concept_1"

        - type: prose
          body_md: |
            ## Constants
            Constants are similar to variables but their values cannot be changed.

# Edit practice page
- edit_page:
    project: "complete_lesson"
    page: "Practice"
    content: |
      title: "Practice Exercises"
      graded: false
      blocks:
        - type: group
          purpose: "practice"
          blocks:
            - type: prose
              body_md: "Try these practice questions:"

            - type: activity_reference
              virtual_id: "concept_1"

            - type: activity_reference
              virtual_id: "concept_2"

            - type: activity
              virtual_id: "practice_q1"
              activity:
                type: oli_multiple_choice
                stem_md: "Which is a valid variable name?"
                choices:
                  - id: "a"
                    body_md: "my_variable"
                    score: 1
                  - id: "b"
                    body_md: "123variable"
                    score: 0

# Edit assessment page
- edit_page:
    project: "complete_lesson"
    page: "Assessment"
    content: |
      title: "Chapter Assessment"
      graded: true
      blocks:
        - type: prose
          body_md: "Complete this assessment to test your understanding."

        - type: activity_reference
          virtual_id: "concept_1"

        - type: activity_reference
          virtual_id: "concept_2"

        - type: activity
          virtual_id: "final_q"
          activity:
            type: oli_multi_input
            stem_md: "Declare a variable named `age` with value 25"
            inputs:
              - id: "var_name"
                type: "text"
              - id: "var_value"
                type: "numeric"
            rule: "var_name == 'age' && var_value == 25"
```

## Notes

- Virtual IDs are scoped to the test scenario, not globally unique
- Inline activities with the same virtual_id reuse the first created instance
- The TorusDoc format is a simplified YAML representation that gets converted to Torus JSON
- Activity references using virtual_ids are resolved at page edit time
- Groups and surveys can contain any valid block types
