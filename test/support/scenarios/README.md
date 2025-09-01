# Oli.Scenarios - YAML-Driven Integration Testing

## Overview

`Oli.Scenarios` enables you to write sophisticated integration tests as simple unit tests without writing any Elixir code. By describing test scenarios in YAML files, you can rapidly script complex workflows that would normally require hundreds of lines of setup code.

### Key Benefits

- **Zero-code test creation**: Define entire test scenarios in readable YAML files - no Elixir code required
- **Integration tests as unit tests**: Test complex multi-step workflows (project creation → publishing → section creation → updates → verification) with the speed and isolation of unit tests
- **Rapid iteration**: Add new test cases by creating YAML files, not writing code
- **Self-documenting**: YAML scenarios serve as both tests and documentation of system behavior
- **Real infrastructure testing**: Scenarios are powered by real infrastructure and **NOT** fixtures or other antiquated approaches. (e.g. `DBSeeder`) That means that things like simulating project hierarchy changes directly uses and tests the actual `ContainerEditor` module, the same code paths used when authors manipulate their curriculum.

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
    to: "math_course"
    ops:
      - add_page:
          title: "Lesson 2"
          to: "Module 1"

# Publish the changes
- publish:
    to: "math_course"
    description: "Adding Lesson 2"

# Apply the update to the section
- update:
    from: "math_course"
    to: "spring_2024"

# Verify the section now has the updated content
- verify:
    to: "spring_2024"
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
- **`product`**: Creates a product (blueprint) from a project that can be used as a template
- **`section`**: Creates a course section from a project, product, or standalone
- **`user`**: Creates users (authors, instructors, students)
- **`institution`**: Creates an institution

### Content Manipulation

- **`manipulate`**: Applies operations to modify a project's structure
  - Operations: `add_page`, `add_container`, `move`, `reorder`, `remove`, `edit_page_title`
- **`remix`**: Copies content from a project into a section or product's hierarchy
  - `from`: Source project name
  - `resource`: Page or container title to copy
  - `section`: Target section or product name
  - `to`: Container in the section/product where content will be added
- **`customize`**: Applies operations to modify a section or product's curriculum (uses real Oli.Delivery.Hierarchy infrastructure)
  - `to`: Target section or product name
  - Operations: `remove` (removes pages/containers), `reorder` (changes order with before/after)

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
      to: "Module 1"  # Optional, defaults to root
  ```

- **`add_container`**: Adds a new container (module/unit)
  ```yaml
  - add_container:
      title: "Module 2"
      to: "root"  # Optional, defaults to root
  ```

### Content Organization
- **`move`**: Moves a resource to a different parent container
  ```yaml
  - move:
      from: "Page 1"
      to: "Module 2"
  ```

- **`reorder`**: Reorders a resource within its current container
  ```yaml
  - reorder:
      from: "Page 2"
      before: "Page 1"  # Or use 'after: "Page 3"'
  ```

### Content Modification
- **`remove`**: Removes a resource from its parent (doesn't delete it)
  ```yaml
  - remove:
      from: "Old Page"
  ```

- **`edit_page_title`**: Changes the title of an existing page
  ```yaml
  - edit_page_title:
      title: "Current Title"
      new_title: "Updated Title"
  ```

- **`revise`**: Updates properties of a page or container
  ```yaml
  - revise:
      target: "Page Title"
      set:
        purpose: "@atom(deliberate_practice)"  # foundation, application, or deliberate_practice
        graded: false
        max_attempts: 0
  ```

## Section Customization Operations

The `customize` directive allows modification of section curriculum after creation:

### Remove Operation
- **`remove`**: Removes a page or container from the section hierarchy
  ```yaml
  - customize:
      to: "section_name"
      ops:
        - remove:
            from: "Page Title"
  ```

### Reorder Operation
- **`reorder`**: Changes the order of pages/containers within their parent
  ```yaml
  - customize:
      to: "section_name"
      ops:
        - reorder:
            from: "Page to Move"
            before: "Target Page"  # Or use 'after: "Target Page"'
  ```
  Note: The `from` and target pages must be siblings (same parent container)

Example workflow:
```yaml
# Create section from project
- section:
    name: "my_section"
    from: "my_project"

# Remove unwanted content from the section
- customize:
    to: "my_section"
    ops:
      - remove:
          from: "Quiz Page"
      - remove:
          from: "Optional Module"

# Reorder content
- customize:
    to: "my_section"
    ops:
      - reorder:
          from: "Final Exam"
          before: "Module 1"
      - reorder:
          from: "Lesson 2"
          after: "Lesson 3"
```

## Products (Blueprints)

Products are templates created from projects that can be used to spawn multiple sections. Products support the same customization and remix operations as sections:

```yaml
# Create a project with content
- project:
    name: "template_project"
    title: "Template Course"
    root:
      children:
        - page: "Welcome"
        - container: "Module 1"
          children:
            - page: "Lesson 1"

# Create a product from the project
- product:
    name: "course_template"
    title: "Course Template V1"
    from: "template_project"

# Customize the product before creating sections
- customize:
    to: "course_template"
    ops:
      - remove:
          from: "Lesson 1"

# Remix additional content into the product
- remix:
    from: "another_project"
    resource: "Additional Content"
    section: "course_template"
    to: "Module 1"

# Create sections from the customized product
- section:
    name: "fall_2024"
    title: "Fall 2024 Section"
    from: "course_template"

- section:
    name: "spring_2025"
    title: "Spring 2025 Section"
    from: "course_template"
```

Both sections will inherit the customizations and remixed content from the product template.

## Remix Operations

The `remix` directive copies content from a project into a section's hierarchy:

```yaml
# Create source project with reusable content
- project:
    name: "library"
    title: "Content Library"
    root:
      children:
        - page: "Shared Lesson"
        - container: "Reusable Module"
          children:
            - page: "Lesson 1"
            - page: "Lesson 2"

# Create section
- section:
    name: "course_section"
    from: "course_project"

# Remix content into the section
- remix:
    from: "library"
    resource: "Shared Lesson"
    section: "course_section"
    to: "Module 1"  # Target container in the section

# Remix an entire module
- remix:
    from: "library"
    resource: "Reusable Module"
    section: "course_section"
    to: "root"  # Add to the root of the section
```

## Error Handling

The framework provides strict validation:
- Unrecognized directives cause immediate test failure with helpful error messages
- Invalid references (e.g., non-existent projects or sections) are caught and reported
- All operations use the real ContainerEditor infrastructure, ensuring realistic test behavior

This declarative approach replaces complex test setup code while ensuring your tests exercise the same code paths as the actual application.