# Student Simulation and Progress Tracking

This document covers directives for simulating student interactions and tracking progress.

## Table of Contents
- [Overview](#overview)
- [view_practice_page](#view_practice_page) - Simulate viewing pages
- [answer_question](#answer_question) - Simulate answering activities
- [assert_progress](#assert_progress) - Assert progress metrics
- [Complete Workflows](#complete-workflows)

---

## Overview

These directives simulate the student experience in a course section:
- Viewing pages (creates attempts)
- Answering questions (submits responses)
- Tracking progress (verifies completion metrics)

This enables testing of:
- Student workflows and interactions
- Progress calculation
- Assessment scoring
- Attempt management

---

## view_practice_page

Simulates a student viewing a practice (ungraded) page in a section. This creates the necessary attempt records that enable answering questions.

### Parameters
- `student`: Name of the student user (as defined in user directive) (required)
- `section`: Name of the section (required)
- `page`: Title of the page to view (required)

### Example
```yaml
# Setup
- user:
    name: "alice"
    type: student

- enroll:
    user: "alice"
    section: "my_section"
    role: student

# Student views a page
- view_practice_page:
    student: "alice"
    section: "my_section"
    page: "Lesson 1"
```

### Notes
- Creates an attempt record for the page
- Must be called before `answer_question` for that page
- Automatically enrolls the student if not already enrolled
- Only works with practice (ungraded) pages

---

## answer_question

Simulates a student answering a question on a page they've already viewed.

### Parameters
- `student`: Name of the student user (required)
- `section`: Name of the section (required)
- `page`: Title of the page containing the activity (required)
- `activity_virtual_id`: Virtual ID of the activity to answer (required)
- `response`: The student's response (required)

### Response Formats

#### Multiple Choice
Use the choice ID:
```yaml
- answer_question:
    student: "alice"
    section: "my_section"
    page: "Quiz Page"
    activity_virtual_id: "mcq_1"
    response: "b"  # Choice ID
```

#### Short Answer
Use the text response:
```yaml
- answer_question:
    student: "alice"
    section: "my_section"
    page: "Quiz Page"
    activity_virtual_id: "short_1"
    response: "The mitochondria is the powerhouse of the cell"
```

#### Multi-Input
Use a map of input IDs to values:
```yaml
- answer_question:
    student: "alice"
    section: "my_section"
    page: "Quiz Page"
    activity_virtual_id: "multi_1"
    response:
      input1: "42"
      input2: "answer"
```

### Example Workflow
```yaml
# Create content with activities
- edit_page:
    project: "my_project"
    page: "Quiz"
    content: |
      blocks:
        - type: activity
          virtual_id: "q1"
          activity:
            type: oli_multiple_choice
            stem_md: "Choose the correct answer"
            choices:
              - id: "a"
                body_md: "Wrong"
                score: 0
              - id: "b"
                body_md: "Correct"
                score: 1

# Student interaction
- view_practice_page:
    student: "alice"
    section: "my_section"
    page: "Quiz"

- answer_question:
    student: "alice"
    section: "my_section"
    page: "Quiz"
    activity_virtual_id: "q1"
    response: "b"
```

---

## assert_progress

Asserts student progress in a page or container. Can check individual student progress or average progress across all students.

### Parameters
- `section`: Name of the section (required)
- `progress`: Expected progress value 0.0-1.0 (required)
- `page`: Title of the page (one of page/container required)
- `container`: Title of the container (one of page/container required)
- `student`: Name of student user (optional - if omitted, asserts average progress for all students)

### Progress Values
- `0.0`: No progress
- `1.0`: Complete
- Values between represent partial completion

### Examples

#### Individual Student Progress on Page
```yaml
- assert_progress:
    section: "my_section"
    student: "alice"
    page: "Lesson 1"
    progress: 1.0  # Alice completed the page
```

#### Average Progress for All Students
```yaml
- assert_progress:
    section: "my_section"
    page: "Lesson 1"
    progress: 0.5  # Half the students completed
```

#### Container Progress
```yaml
- assert_progress:
    section: "my_section"
    student: "alice"
    container: "Module 1"
    progress: 0.33  # Alice completed 1 of 3 pages in module
```

### Progress Calculation
- **Page progress**: Based on activity completion
  - Viewing page and answering all activities = 1.0
  - Partial completion based on activities answered
- **Container progress**: Based on child page completion
  - Average of all child page progress values
  - Nested containers calculate recursively

---

## Complete Workflows

### Workflow 1: Single Student Complete Path

```yaml
# Setup course
- project:
    name: "tutorial"
    title: "Tutorial Course"
    root:
      children:
        - page: "Introduction"
        - container: "Module 1"
          children:
            - page: "Lesson 1"
            - page: "Lesson 2"
            - page: "Quiz"

# Add activities to pages
- edit_page:
    project: "tutorial"
    page: "Lesson 1"
    content: |
      blocks:
        - type: prose
          body_md: "Welcome to Lesson 1"
        - type: activity
          virtual_id: "l1_q1"
          activity:
            type: oli_multiple_choice
            stem_md: "Lesson 1 Question"
            choices:
              - id: "correct"
                body_md: "Correct Answer"
                score: 1
              - id: "wrong"
                body_md: "Wrong Answer"
                score: 0

- edit_page:
    project: "tutorial"
    page: "Quiz"
    content: |
      blocks:
        - type: activity
          virtual_id: "quiz_q1"
          activity:
            type: oli_multiple_choice
            stem_md: "Quiz Question 1"
            choices:
              - id: "a"
                body_md: "Option A"
                score: 1
              - id: "b"
                body_md: "Option B"
                score: 0
        - type: activity
          virtual_id: "quiz_q2"
          activity:
            type: oli_short_answer
            stem_md: "Explain your answer"
            input_type: "text"

# Create section and student
- section:
    name: "course_section"
    from: "tutorial"

- user:
    name: "john"
    type: student

- enroll:
    user: "john"
    section: "course_section"

# Student completes Lesson 1
- view_practice_page:
    student: "john"
    section: "course_section"
    page: "Lesson 1"

- answer_question:
    student: "john"
    section: "course_section"
    page: "Lesson 1"
    activity_virtual_id: "l1_q1"
    response: "correct"

# Assert Lesson 1 complete
- assert_progress:
    section: "course_section"
    student: "john"
    page: "Lesson 1"
    progress: 1.0

# Student partially completes Quiz
- view_practice_page:
    student: "john"
    section: "course_section"
    page: "Quiz"

- answer_question:
    student: "john"
    section: "course_section"
    page: "Quiz"
    activity_virtual_id: "quiz_q1"
    response: "a"
# Doesn't answer quiz_q2

# Assert partial Quiz progress
- assert_progress:
    section: "course_section"
    student: "john"
    page: "Quiz"
    progress: 0.5  # Answered 1 of 2 questions

# Assert Module 1 progress (1 complete, 1 partial, 1 not started)
- assert_progress:
    section: "course_section"
    student: "john"
    container: "Module 1"
    progress: 0.5  # Average of child progress
```

### Workflow 2: Multiple Students with Varying Progress

```yaml
# Create course with assessment
- project:
    name: "assessment_course"
    title: "Assessment Course"
    root:
      children:
        - page: "Pre-Test"
        - page: "Content"
        - page: "Post-Test"

# Add activities
- edit_page:
    project: "assessment_course"
    page: "Pre-Test"
    content: |
      blocks:
        - type: activity
          virtual_id: "pre_q1"
          activity:
            type: oli_multiple_choice
            stem_md: "Pre-test question"
            choices:
              - id: "a"
                body_md: "Answer A"
                score: 1
              - id: "b"
                body_md: "Answer B"
                score: 0

- edit_page:
    project: "assessment_course"
    page: "Post-Test"
    content: |
      blocks:
        - type: activity
          virtual_id: "post_q1"
          activity:
            type: oli_multiple_choice
            stem_md: "Post-test question"
            choices:
              - id: "a"
                body_md: "Answer A"
                score: 0
              - id: "b"
                body_md: "Answer B"
                score: 1

# Setup section with multiple students
- section:
    name: "class_section"
    from: "assessment_course"

- user:
    name: "student1"
    type: student
- user:
    name: "student2"
    type: student
- user:
    name: "student3"
    type: student

- enroll:
    user: "student1"
    section: "class_section"
- enroll:
    user: "student2"
    section: "class_section"
- enroll:
    user: "student3"
    section: "class_section"

# Student 1 completes everything
- view_practice_page:
    student: "student1"
    section: "class_section"
    page: "Pre-Test"
- answer_question:
    student: "student1"
    section: "class_section"
    page: "Pre-Test"
    activity_virtual_id: "pre_q1"
    response: "a"

- view_practice_page:
    student: "student1"
    section: "class_section"
    page: "Post-Test"
- answer_question:
    student: "student1"
    section: "class_section"
    page: "Post-Test"
    activity_virtual_id: "post_q1"
    response: "b"

# Student 2 only completes Pre-Test
- view_practice_page:
    student: "student2"
    section: "class_section"
    page: "Pre-Test"
- answer_question:
    student: "student2"
    section: "class_section"
    page: "Pre-Test"
    activity_virtual_id: "pre_q1"
    response: "a"

# Student 3 doesn't complete anything

# Assert individual progress
- assert_progress:
    section: "class_section"
    student: "student1"
    page: "Pre-Test"
    progress: 1.0

- assert_progress:
    section: "class_section"
    student: "student1"
    page: "Post-Test"
    progress: 1.0

- assert_progress:
    section: "class_section"
    student: "student2"
    page: "Pre-Test"
    progress: 1.0

- assert_progress:
    section: "class_section"
    student: "student2"
    page: "Post-Test"
    progress: 0.0

- assert_progress:
    section: "class_section"
    student: "student3"
    page: "Pre-Test"
    progress: 0.0

# Assert average progress across all students
- assert_progress:
    section: "class_section"
    page: "Pre-Test"
    progress: 0.67  # 2 of 3 completed

- assert_progress:
    section: "class_section"
    page: "Post-Test"
    progress: 0.33  # 1 of 3 completed
```

### Workflow 3: Testing Different Response Types

```yaml
# Create diverse assessment
- project:
    name: "diverse_assessment"
    title: "Diverse Assessment"
    root:
      children:
        - page: "Mixed Questions"

- edit_page:
    project: "diverse_assessment"
    page: "Mixed Questions"
    content: |
      blocks:
        # Multiple choice
        - type: activity
          virtual_id: "mc_q"
          activity:
            type: oli_multiple_choice
            stem_md: "Multiple choice question"
            choices:
              - id: "opt1"
                body_md: "Option 1"
                score: 0
              - id: "opt2"
                body_md: "Option 2"
                score: 1
        
        # Short answer
        - type: activity
          virtual_id: "short_q"
          activity:
            type: oli_short_answer
            stem_md: "Short answer question"
            input_type: "text"
        
        # Check all that apply
        - type: activity
          virtual_id: "check_q"
          activity:
            type: oli_check_all_that_apply
            stem_md: "Select all correct options"
            choices:
              - id: "c1"
                body_md: "Correct 1"
                score: 1
              - id: "c2"
                body_md: "Correct 2"
                score: 1
              - id: "c3"
                body_md: "Incorrect"
                score: 0

# Test student responses
- section:
    name: "test_section"
    from: "diverse_assessment"

- user:
    name: "tester"
    type: student

- view_practice_page:
    student: "tester"
    section: "test_section"
    page: "Mixed Questions"

# Answer multiple choice
- answer_question:
    student: "tester"
    section: "test_section"
    page: "Mixed Questions"
    activity_virtual_id: "mc_q"
    response: "opt2"

# Answer short answer
- answer_question:
    student: "tester"
    section: "test_section"
    page: "Mixed Questions"
    activity_virtual_id: "short_q"
    response: "This is my detailed answer to the question"

# Answer check all (multiple selections)
- answer_question:
    student: "tester"
    section: "test_section"
    page: "Mixed Questions"
    activity_virtual_id: "check_q"
    response: ["c1", "c2"]  # Selected both correct options

# Assert completion
- assert_progress:
    section: "test_section"
    student: "tester"
    page: "Mixed Questions"
    progress: 1.0
```

## Notes

- Students must be enrolled before viewing pages
- Pages must be viewed before questions can be answered
- Virtual IDs link activities to student responses
- Progress is calculated based on actual completion, not correctness
- The `assert_progress` directive uses `Oli.Delivery.Metrics` for calculations
- Container progress may be 0.0 in test scenarios due to ResourceAccess record limitations