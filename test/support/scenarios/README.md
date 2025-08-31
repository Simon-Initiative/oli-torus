# Oli.Scenarios - YAML-Driven Integration Testing

## Overview

Oli.Scenarios enables you to write sophisticated integration tests as simple unit tests without writing any Elixir code. By describing test scenarios in YAML files, you can rapidly script complex workflows that would normally require hundreds of lines of setup code.

### Key Benefits

- **Zero-code test creation**: Define entire test scenarios in readable YAML files - no Elixir code required
- **Integration tests as unit tests**: Test complex multi-step workflows (project creation → publishing → section delivery → updates → verification) with the speed and isolation of unit tests
- **Rapid iteration**: Add new test cases by creating YAML files, not writing code
- **Self-documenting**: YAML scenarios serve as both tests and documentation of system behavior
- **Real infrastructure testing**: Uses the actual ContainerEditor infrastructure, ensuring tests exercise the same code paths as the authoring UI

### Example

Instead of writing hundreds of lines of test setup code, you can describe your entire test scenario declaratively:

```yaml
# Create a project with initial content
- project:
    name: "math_course"
    title: "Mathematics 101"
    root:
      children:
        - page: "Introduction"
        - container: "Module 1"
          children:
            - page: "Lesson 1"

# Create a course section from the project
- section:
    name: "spring_2024"
    from: "math_course"
    title: "Math 101 - Spring 2024"

# Apply operations to modify the project
- manipulate:
    target: "math_course"
    ops:
      - add_page:
          title: "Lesson 2"
          parent: "Module 1"

# Publish the changes
- publish:
    target: "math_course"
    description: "Adding Lesson 2"

# Apply the update to the section
- update:
    from: "math_course"
    to: "spring_2024"

# Verify the section now has the updated content
- verify:
    target: "spring_2024"
    structure:
      root:
        children:
          - page: "Introduction"
          - container: "Module 1"
            children:
              - page: "Lesson 1"
              - page: "Lesson 2"
```

## Available Directives

### Structure Creation

- **`project`**: Creates a new project with hierarchical content structure
- **`section`**: Creates a course section from a project or standalone
- **`user`**: Creates users (authors, instructors, students)
- **`institution`**: Creates an institution

### Content Manipulation

- **`manipulate`**: Applies operations to modify a project's structure
  - Operations: `add_page`, `add_container`, `move`, `reorder`, `remove`, `edit_page_title`
- **`remix`**: Copies content from one project/section to another

### Publishing & Updates

- **`publish`**: Publishes outstanding changes in a project
- **`update`**: Applies published updates from a project to a section

### Organization & Testing

- **`enroll`**: Enrolls users in sections with specific roles
- **`verify`**: Verifies the structure of a project or section matches expectations

## Operations (used within `manipulate`)

### Content Creation
- **`add_page`**: Adds a new page to a container
  ```yaml
  - add_page:
      title: "New Page"
      parent: "Module 1"  # Optional, defaults to root
  ```

- **`add_container`**: Adds a new container (module/unit)
  ```yaml
  - add_container:
      title: "Module 2"
      parent: "root"  # Optional, defaults to root
  ```

### Content Organization
- **`move`**: Moves a resource to a different parent container
  ```yaml
  - move:
      source: "Page 1"
      to: "Module 2"
  ```

- **`reorder`**: Reorders a resource within its current container
  ```yaml
  - reorder:
      source: "Page 2"
      before: "Page 1"  # Or use 'after: "Page 3"'
  ```

### Content Modification
- **`remove`**: Removes a resource from its parent (doesn't delete it)
  ```yaml
  - remove:
      target: "Old Page"
  ```

- **`edit_page_title`**: Changes the title of an existing page
  ```yaml
  - edit_page_title:
      title: "Current Title"
      new_title: "Updated Title"
  ```

## Error Handling

The framework provides strict validation:
- Unrecognized directives cause immediate test failure with helpful error messages
- Invalid references (e.g., non-existent projects or sections) are caught and reported
- All operations use the real ContainerEditor infrastructure, ensuring realistic test behavior

This declarative approach replaces complex test setup code while ensuring your tests exercise the same code paths as the actual application.