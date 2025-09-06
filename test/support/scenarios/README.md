# Oli.Scenarios - YAML-Driven Integration Testing

## Overview

`Oli.Scenarios` enables you to write sophisticated integration tests as simple unit tests without writing any Elixir code. By describing test scenarios in YAML files, you can rapidly script complex workflows that would normally require hundreds of lines of setup code.

### Key Benefits

- **Zero-code test creation**: Define entire test scenarios in readable YAML files
- **Integration tests as unit tests**: Test complex multi-step workflows with the speed and isolation of unit tests
- **Rapid iteration**: Add new test cases by creating YAML files, not writing code
- **Self-documenting**: YAML scenarios serve as both tests and documentation
- **Real infrastructure testing**: Uses actual OLI modules like `ContainerEditor`, not mocks or fixtures

## Quick Start

```yaml
# Create a project with content
- project:
    name: "math_course"
    title: "Mathematics 101"
    root:
      children:
        - page: "Introduction"
        - container: "Module 1"
          children:
            - page: "Lesson 1"

# Create a course section
- section:
    name: "spring_2024"
    from: "math_course"
    title: "Math 101 - Spring 2024"

# Modify the project
- manipulate:
    to: "math_course"
    ops:
      - add_page:
          title: "Lesson 2"
          to: "Module 1"

# Publish and update
- publish:
    to: "math_course"
    description: "Added Lesson 2"

- update:
    from: "math_course"
    to: "spring_2024"

# Assert the update is applied successfully
- assert:
    structure:
      to: "spring_2024"
      children:
        - page: "Introduction"
        - container: "Module 1"
          children:
            - page: "Lesson 1"
            - page: "Lesson 2"
```

## Directive Reference

All directives are documented in detail in the linked documentation files.

| Category | Directive | Description | Documentation |
|----------|-----------|-------------|---------------|
| **Projects** | | | |
| | `project` | Create a new project with content structure | [projects.md](docs/projects.md#project) |
| | `manipulate` | Modify project structure (add, move, remove, etc.) | [projects.md](docs/projects.md#manipulate) |
| | `publish` | Publish project changes | [projects.md](docs/projects.md#publish) |
| | `assert` | Assert project structure/properties | [projects.md](docs/projects.md#assert) |
| **Sections** | | | |
| | `section` | Create course section from project/product | [sections.md](docs/sections.md#section) |
| | `update` | Apply project updates to section | [sections.md](docs/sections.md#update) |
| | `customize` | Modify section curriculum | [sections.md](docs/sections.md#customize) |
| | `remix` | Copy content into section | [sections.md](docs/sections.md#remix) |
| **Products** | | | |
| | `product` | Create reusable course template | [products.md](docs/products.md#product) |
| **Content** | | | |
| | `create_activity` | Create standalone activity | [content_authoring.md](docs/content_authoring.md#create_activity) |
| | `edit_page` | Edit page content with TorusDoc | [content_authoring.md](docs/content_authoring.md#edit_page) |
| **Students** | | | |
| | `view_practice_page` | Simulate student viewing page | [student_simulation.md](docs/student_simulation.md#view_practice_page) |
| | `answer_question` | Simulate answering activity | [student_simulation.md](docs/student_simulation.md#answer_question) |
| **Organization** | | | |
| | `user` | Create users (author/instructor/student) | [users_and_org.md](docs/users_and_org.md#user) |
| | `institution` | Create institution | [users_and_org.md](docs/users_and_org.md#institution) |
| | `enroll` | Enroll users in sections | [users_and_org.md](docs/users_and_org.md#enroll) |

## Documentation Guide

Detailed documentation is organized by topic:

- **[Projects and Publishing](docs/projects.md)** - Creating and managing course projects
- **[Sections and Updates](docs/sections.md)** - Course delivery and curriculum management
- **[Products (Blueprints)](docs/products.md)** - Reusable course templates
- **[Content Authoring](docs/content_authoring.md)** - Creating pages and activities with TorusDoc
- **[Student Simulation](docs/student_simulation.md)** - Simulating student interactions and progress
- **[Users and Organization](docs/users_and_org.md)** - Managing users, institutions, and enrollment

## Writing Tests

### Basic Test Structure

```elixir
defmodule MyScenarioTest do
  use Oli.DataCase

  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.DirectiveParser

  test "my scenario" do
    yaml = """
    - project:
        name: "test_project"
        title: "Test Project"
        root:
          children:
            - page: "Page 1"

    - assert:
        structure:
          to: "test_project"
          root:
            children:
              - page: "Page 1"
    """

    directives = DirectiveParser.parse_yaml!(yaml)
    result = Engine.execute(directives)

    assert result.errors == []
    assert length(result.verifications) == 1
    assert hd(result.verifications).passed == true
  end
end
```

### Loading from Files

```elixir
test "scenario from file" do
  result = Engine.execute_file("test/scenarios/my_scenario.yaml")
  assert result.errors == []
end
```

### Universal Runner

The `ScenarioRunner` macro will discover and run all `*.scenario.yaml`
files in the current directory.

```elixir
defmodule Oli.Delivery.MajorUpdatesTest do
  use Oli.Scenarios.ScenarioRunner
end
```

## Error Handling

The framework provides comprehensive error reporting:

- **Unrecognized directives**: Immediate failure with helpful messages
- **Invalid references**: Caught and reported (e.g., non-existent projects)
- **Operation failures**: Detailed error messages with context

Example error handling:
```elixir
result = Engine.execute(directives)

# Check for errors
if result.errors != [] do
  Enum.each(result.errors, fn {directive, message} ->
    IO.puts("Error in #{inspect(directive)}: #{message}")
  end)
end

# Check verifications
Enum.each(result.verifications, fn verification ->
  if not verification.passed do
    IO.puts("Verification failed: #{verification.message}")
  end
end)
```

## Advanced Features

### Virtual IDs
Virtual IDs provide scenario-local identifiers for activities, enabling:
- Activity reuse across pages
- Student response simulation
- Progress tracking

### State Management
The execution engine maintains state throughout scenario execution:
- Projects, sections, and products
- Users and enrollments
- Activities and student attempts
- All state is accessible for assertions

### Real Infrastructure
Unlike traditional fixtures, Oli.Scenarios uses actual OLI modules:
- `ContainerEditor` for project manipulation
- `Oli.Delivery.Hierarchy` for section customization
- `Oli.Delivery.Metrics` for progress calculation
- Real database operations in test transactions

## Tips and Best Practices

1. **Keep scenarios focused**: Each test should verify one workflow
2. **Use descriptive names**: Make directive names self-documenting
3. **Leverage verification**: Always verify expected outcomes
4. **Reuse common patterns**: Extract common setup into helper functions
5. **Test edge cases**: Use scenarios to test complex interactions

## Contributing

When adding new directives:
1. Define the type in `directive_types.ex`
2. Add parsing in `directive_parser.ex`
3. Implement handler in `directives/` folder
4. Update documentation
5. Add tests

## Support

For issues or questions:
- Check the detailed documentation in the `docs/` folder
- Review existing test scenarios for examples
- Consult the handler implementations in `test/support/scenarios/directives/`