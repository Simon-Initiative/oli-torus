# Oli.Scenarios - YAML-Driven Integration Testing

## Overview

Oli.Scenarios enables you to write sophisticated integration tests as simple unit tests without writing any Elixir code. By describing test scenarios in YAML files, you can rapidly script complex workflows that would normally require hundreds of lines of setup code.

### Key Benefits

- **Zero-code test creation**: Define entire test scenarios in readable YAML files - no Elixir code required
- **Integration tests as unit tests**: Test complex multi-step workflows (project creation → publishing → section delivery → updates → verification) with the speed and isolation of unit tests
- **Rapid iteration**: Add new test cases by creating YAML files, not writing code
- **Self-documenting**: YAML scenarios serve as both tests and documentation of system behavior
- **Reusable components**: Share project structures, operations, and verifications across multiple test scenarios

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

# Make changes and publish an update
- publish_changes:
    target: "math_course"
    description: "Adding Module 2"
    ops:
      - add_page:
          title: "Lesson 2"
          parent: "Module 1"

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

This single YAML file replaces what would typically require multiple test files with complex factory setups, database transactions, and assertion helpers. The Scenarios framework handles all the complexity behind a simple, declarative interface.