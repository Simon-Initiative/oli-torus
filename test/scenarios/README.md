# Scenario Tests

This directory contains YAML-based scenario tests for the Oli.Scenarios system. These tests use a declarative approach to specify complex course structures and operations.

## Directory Structure

```
test/scenarios/
├── core/                      # Core functionality tests
│   ├── simple_project.scenario.yaml
│   └── clone_demo.scenario.yaml
├── features/                  # Feature-specific tests
│   ├── move_and_reorder.scenario.yaml
│   ├── product_creation.scenario.yaml
│   ├── remix_to_section.scenario.yaml
│   ├── section_customization.scenario.yaml
│   └── section_verification.scenario.yaml
├── delivery/                  # Delivery-related tests
│   ├── major_updates/        # Major update scenarios
│   │   ├── add_new_content.scenario.yaml
│   │   ├── apply_major_updates_from_product.scenario.yaml
│   │   ├── product_publishing_with_remix.scenario.yaml
│   │   ├── product_section_update_restriction.scenario.yaml
│   │   ├── remix_selective_updates.scenario.yaml
│   │   └── simple_update_test.scenario.yaml
│   └── minor_updates/        # Minor update scenarios
│       └── page_title_update.scenario.yaml
├── cloning/                   # Cloning-specific tests
│   └── independent_publishing.scenario.yaml
├── hooks/                     # Hook directive examples
│   └── hook_demo.scenario.yaml
└── scenario_runner_test.exs  # Universal test runner

```

## Running Tests

### Run all scenario tests:
```bash
mix test test/scenarios/scenario_runner_test.exs
# or
./scripts/scenario
```

### Run a single scenario file:
```bash
# Using the shell script (recommended)
./scripts/scenario core/simple_project
./scripts/scenario core/simple_project.scenario.yaml
./scripts/scenario features/remix_to_section

# Using environment variable directly
export SCENARIO_FILE=test/scenarios/core/simple_project.scenario.yaml
mix test test/run_single_scenario.exs
```

### Using the mix scenarios task:
```bash
# Run all scenarios
mix scenarios

# Run a single scenario (when mix task is compiled)
mix scenarios core/simple_project
```

### Run tests with specific tags:
```bash
# Run only tests matching a pattern in the test runner
mix test test/scenarios/scenario_runner_test.exs --only core_simple_project
```

## Writing New Scenarios

Scenario files use YAML format with directives. Common directives include:

- `project:` - Create a new project with structure
- `clone:` - Clone an existing project
- `section:` - Create a section from a project
- `product:` - Create a product blueprint
- `remix:` - Remix content between projects
- `publish:` - Publish project changes
- `update:` - Apply updates to sections
- `assert:` - Verify expected structure or state
- `hook:` - Execute custom Elixir functions for advanced testing

Example scenario:
```yaml
# Create a project
- project:
    name: my_project
    title: "My Test Project"
    root:
      container: "Course Root"
      children:
        - page: "Welcome"
        - container: "Module 1"
          children:
            - page: "Lesson 1"

# Create a section from it
- section:
    name: my_section
    title: "Test Section"
    from: my_project

# Verify the structure
- assert:
    structure:
      to: my_section
      root:
        container: "Course Root"
        children:
          - page: "Welcome"
          - container: "Module 1"
```

## Hook Directive

The `hook` directive allows execution of custom Elixir functions during scenario execution:

```yaml
# Log current state for debugging
- hook:
    function: "Oli.Scenarios.Hooks.log_state/1"

# Create test data
- hook:
    function: "Oli.Scenarios.Hooks.create_bulk_users/1"

# Inject errors for testing
- hook:
    function: "Oli.Scenarios.Hooks.inject_error/1"
```

Hook functions must:
- Accept exactly one argument (the ExecutionState)
- Return an updated ExecutionState
- Be specified as "Module.function/1"

See `lib/oli/scenarios/hooks.ex` for available built-in hooks, or create your own custom hook functions.

## Test Discovery

The scenario runner automatically discovers all `.scenario.yaml` files in this directory and its subdirectories. Each file becomes a test case with a name derived from its path (e.g., `core/simple_project` becomes test `core_simple_project`).