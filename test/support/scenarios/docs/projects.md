# Projects and Publishing

This document covers directives for creating, manipulating, and publishing projects in Oli.Scenarios.

## Table of Contents
- [project](#project) - Create new projects
- [manipulate](#manipulate) - Modify project structure
- [publish](#publish) - Publish project changes
- [assert](#assert) - Assert project structure and properties

---

## project

Creates a new project with hierarchical content structure.

### Parameters
- `name`: Internal identifier for the project (required)
- `title`: Display title for the project
- `root`: Hierarchical structure definition
- `objectives`: Learning objectives hierarchy (optional)
- `tags`: List of tag titles (optional)

### Structure Definition
Projects use a nested structure with containers and pages:
- `container`: A folder/module that can contain other resources
- `page`: A leaf node containing content
- `children`: Array of child resources

### Examples

#### Simple Project
```yaml
- project:
    name: "intro_course"
    title: "Introduction to Programming"
    root:
      children:
        - page: "Welcome"
        - page: "Getting Started"
```

#### Nested Structure
```yaml
- project:
    name: "math_course"
    title: "Mathematics 101"
    root:
      children:
        - page: "Course Overview"
        - container: "Module 1: Basics"
          children:
            - page: "Introduction"
            - page: "Lesson 1.1"
            - page: "Lesson 1.2"
        - container: "Module 2: Advanced"
          children:
            - container: "Unit 1"
              children:
                - page: "Topic A"
                - page: "Topic B"
```

#### Project with Learning Objectives
```yaml
- project:
    name: "course_with_objectives"
    title: "Course with Learning Objectives"
    root:
      children:
        - page: "Introduction"
        - container: "Module 1"
          children:
            - page: "Lesson 1"
    objectives:
      - Understand basic concepts:
        - Define key terms
        - Identify core principles
      - Apply knowledge:
        - Solve practice problems
        - Complete exercises
      - Independent study  # Simple objective with no children
```

The objectives structure creates a two-level hierarchy of learning objectives:
- Simple strings create parent objectives with no children
- To add sub-objectives, use the parent title as a key with children as an array value
- Each objective gets a unique resource that can be referenced later

#### Project with Tags
```yaml
- project:
    name: "tagged_course"
    title: "Course with Tags"
    root:
      children:
        - page: "Getting Started"
        - container: "Module 1"
          children:
            - page: "Lesson 1"
    tags:
      - "Beginner"
      - "Mathematics"
      - "Algebra"
      - "Self-paced"
```

Tags are flat metadata labels that can be attached to projects and activities:
- Simple list of string titles
- Each tag gets a unique resource that can be referenced later
- Tags can be attached to activities for categorization

---

## manipulate

Applies operations to modify a project's structure. This directive uses the real `ContainerEditor` infrastructure, ensuring that tests exercise the same code paths as actual authoring operations.

### Parameters
- `to`: Name of the project to manipulate (required)
- `ops`: Array of operations to apply

### Available Operations

#### add_page
Adds a new page to a container.

```yaml
- manipulate:
    to: "my_project"
    ops:
      - add_page:
          title: "New Page"
          to: "Module 1"  # Optional, defaults to root
```

#### add_container
Adds a new container (module/unit).

```yaml
- manipulate:
    to: "my_project"
    ops:
      - add_container:
          title: "Module 2"
          to: "root"  # Optional, defaults to root
```

#### move
Moves a resource to a different parent container.

```yaml
- manipulate:
    to: "my_project"
    ops:
      - move:
          from: "Page 1"
          to: "Module 2"
```

#### reorder
Reorders a resource within its current container.

```yaml
- manipulate:
    to: "my_project"
    ops:
      - reorder:
          from: "Page 2"
          before: "Page 1"  # Or use 'after: "Page 3"'
```

#### remove
Removes a resource from its parent (doesn't delete it from the project).

```yaml
- manipulate:
    to: "my_project"
    ops:
      - remove:
          from: "Old Page"
```

#### revise
Updates properties of a page or container.

```yaml
- manipulate:
    to: "my_project"
    ops:
      - revise:
          target: "Quiz Page"
          set:
            purpose: "@atom(deliberate_practice)"  # foundation, application, or deliberate_practice
            graded: true
            max_attempts: 3
            title: "Updated Quiz Page"  # Can also rename
```

### Complex Manipulation Example

```yaml
# Create initial project
- project:
    name: "evolving_course"
    title: "Evolving Course"
    root:
      children:
        - page: "Introduction"
        - container: "Module 1"
          children:
            - page: "Lesson 1"

# Apply multiple operations
- manipulate:
    to: "evolving_course"
    ops:
      # Add new content
      - add_container:
          title: "Module 2"
      - add_page:
          title: "Lesson 2"
          to: "Module 1"
      - add_page:
          title: "Final Exam"
          to: "Module 2"
      
      # Reorganize content
      - move:
          from: "Introduction"
          to: "Module 1"
      - reorder:
          from: "Introduction"
          before: "Lesson 1"
      
      # Update properties
      - revise:
          target: "Final Exam"
          set:
            graded: true
            max_attempts: 2
            purpose: "@atom(deliberate_practice)"
```

---

## publish

Publishes outstanding changes in a project, creating a new publication that can be deployed to sections.

### Parameters
- `to`: Name of the project to publish (required)
- `description`: Description of the changes being published

### Example

```yaml
# Make changes to project
- manipulate:
    to: "my_project"
    ops:
      - add_page:
          title: "New Content"

# Publish the changes
- publish:
    to: "my_project"
    description: "Added new content page"
```

### Publishing Workflow

Publishing is typically part of a larger workflow:

```yaml
# 1. Create project
- project:
    name: "course_v1"
    title: "My Course"
    root:
      children:
        - page: "Lesson 1"

# 2. Create section from project (auto-publishes)
- section:
    name: "spring_2024"
    from: "course_v1"

# 3. Make changes to project
- manipulate:
    to: "course_v1"
    ops:
      - add_page:
          title: "Lesson 2"

# 4. Publish changes
- publish:
    to: "course_v1"
    description: "Added Lesson 2"

# 5. Apply update to section (see sections.md)
- update:
    from: "course_v1"
    to: "spring_2024"
```

---

## assert

Asserts the structure or resource properties of a project.

### Structure Assertion

Asserts the hierarchical structure matches expectations.

```yaml
- assert:
    structure:
      to: "my_project"
      root:
        children:
          - page: "Introduction"
          - container: "Module 1"
            children:
              - page: "Lesson 1"
              - page: "Lesson 2"
```

### Resource Property Assertion

Asserts specific properties of individual resources.

```yaml
- assert:
    resource:
      to: "my_project"
      target: "Quiz Page"
      resource:
        graded: true
        max_attempts: 3
        purpose: "@atom(deliberate_practice)"
```

### Combined Example

```yaml
# Create and modify project
- project:
    name: "test_project"
    title: "Test Project"
    root:
      children:
        - page: "Page 1"

- manipulate:
    to: "test_project"
    ops:
      - add_page:
          title: "Quiz"
      - revise:
          target: "Quiz"
          set:
            graded: true
            max_attempts: 2

# Assert structure
- assert:
    structure:
      to: "test_project"
      root:
        children:
          - page: "Page 1"
          - page: "Quiz"

# Assert properties
- assert:
    resource:
      to: "test_project"
      target: "Quiz"
      resource:
        graded: true
        max_attempts: 2
```

## Complete Project Lifecycle Example

```yaml
# Create initial project
- project:
    name: "full_course"
    title: "Complete Course Example"
    root:
      children:
        - page: "Welcome"
        - container: "Module 1"
          children:
            - page: "Introduction"
            - page: "Lesson 1"

# Add more content
- manipulate:
    to: "full_course"
    ops:
      - add_container:
          title: "Module 2"
      - add_page:
          title: "Lesson 2"
          to: "Module 1"
      - add_page:
          title: "Advanced Topics"
          to: "Module 2"

# Configure assessment pages
- manipulate:
    to: "full_course"
    ops:
      - add_page:
          title: "Quiz 1"
          to: "Module 1"
      - revise:
          target: "Quiz 1"
          set:
            graded: true
            max_attempts: 3
            purpose: "@atom(application)"

# Reorganize content
- manipulate:
    to: "full_course"
    ops:
      - move:
          from: "Welcome"
          to: "Module 1"
      - reorder:
          from: "Welcome"
          before: "Introduction"

# Publish the complete project
- publish:
    to: "full_course"
    description: "Initial course release v1.0"

# Assert final structure
- assert:
    structure:
      to: "full_course"
      root:
        children:
          - container: "Module 1"
            children:
              - page: "Welcome"
              - page: "Introduction"
              - page: "Lesson 1"
              - page: "Lesson 2"
              - page: "Quiz 1"
          - container: "Module 2"
            children:
              - page: "Advanced Topics"
```

## Notes

- All manipulate operations use the actual `ContainerEditor` infrastructure, not mocks
- Project names must be unique within a test scenario
- Resources are identified by title, so titles should be unique within a project
- The `@atom()` syntax in `revise` operations converts strings to Elixir atoms
- Publishing creates an immutable snapshot that sections can use