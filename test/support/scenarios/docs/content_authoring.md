# Content Authoring with TorusDoc

This document covers directives for creating and editing content using the TorusDoc YAML format.

## Table of Contents
- [Overview](#overview)
- [create_activity](#create_activity) - Create standalone activities
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

---

## create_activity

Creates a standalone activity that can be referenced in pages.

### Parameters
- `project`: Target project name (required)
- `title`: Activity title for referencing
- `virtual_id`: Scenario-local identifier for the activity (optional)
- `scope`: "embedded" or "banked" (default: "embedded")
- `type`: Activity type slug (e.g., "oli_multiple_choice")
- `content`: TorusDoc YAML content defining the activity

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

---

## edit_page

Edits an existing page's content using TorusDoc YAML.

### Parameters
- `project`: Target project name (required)
- `page`: Title of the page to edit (required)
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

### oli_multi_input
```yaml
type: oli_multi_input
stem_md: "Question text"
inputs:
  - id: "input1"
    type: "text" or "numeric"
rule: "Evaluation rule expression"
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