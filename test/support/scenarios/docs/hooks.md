# Hook Directive Documentation

The `hook` directive provides a powerful extension mechanism for Oli.Scenarios, allowing test authors to execute custom Elixir functions during scenario execution. This enables advanced testing capabilities that go beyond the standard directives.

## Overview

Hooks allow you to:
- Inject custom test data
- Corrupt data for error testing
- Add validation logic
- Manipulate state in ways not covered by standard directives
- Debug and inspect state during execution
- Perform cleanup operations

## Syntax

```yaml
- hook:
    function: "Module.function/1"
```

## Requirements

All hook functions must:
1. Accept exactly **one** argument: the `ExecutionState`
2. Return an updated `ExecutionState`
3. Have arity of 1 (indicated by `/1` in the function specification)
4. Be available in the runtime (module must be loaded)

## Built-in Hooks

The framework provides several useful hooks in `Oli.Scenarios.Hooks`:

### Debugging and Inspection

#### `log_state/1`
Logs the current execution state for debugging purposes.

```yaml
- hook:
    function: "Oli.Scenarios.Hooks.log_state/1"
```

Output includes counts of projects, sections, products, users, and activities.

### State Manipulation

#### `set_test_flag/1`
Adds a test flag to the state for conditional testing.

```yaml
- hook:
    function: "Oli.Scenarios.Hooks.set_test_flag/1"
```

Sets `state.test_flags.hook_executed = true`

#### `clear_activities/1`
Removes all activities from the state.

```yaml
- hook:
    function: "Oli.Scenarios.Hooks.clear_activities/1"
```

Useful for testing scenarios where activities need to be rebuilt.

### User Management

#### `create_bulk_users/1`
Creates 5 test users programmatically.

```yaml
- hook:
    function: "Oli.Scenarios.Hooks.create_bulk_users/1"
```

Creates users named `bulk_user_1` through `bulk_user_5`.

### Testing Utilities

#### `inject_error/1`
Injects an error condition for testing error handling.

```yaml
- hook:
    function: "Oli.Scenarios.Hooks.inject_error/1"
```

Adds error information to `state.error_injected`.

#### `corrupt_page_content/1`
Corrupts the content of the first page in the first project.

```yaml
- hook:
    function: "Oli.Scenarios.Hooks.corrupt_page_content/1"
```

Useful for testing error handling and validation.

#### `delay_execution/1`
Pauses execution for 1 second.

```yaml
- hook:
    function: "Oli.Scenarios.Hooks.delay_execution/1"
```

Useful for testing timeout behaviors.

### Validation

#### `validate_state/1`
Validates that certain conditions are met in the state.

```yaml
- hook:
    function: "Oli.Scenarios.Hooks.validate_state/1"
```

Raises an error if no projects or sections exist.

### Publication Management

#### `modify_publications/1`
Modifies publication settings for all projects.

```yaml
- hook:
    function: "Oli.Scenarios.Hooks.modify_publications/1"
```

Adds custom descriptions to working publications.

## Creating Custom Hooks

### Basic Structure

```elixir
defmodule MyProject.ScenarioHooks do
  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  
  @doc """
  My custom hook function.
  Must accept ExecutionState and return ExecutionState.
  """
  def my_custom_hook(%ExecutionState{} = state) do
    # Your custom logic here
    
    # Always return the (potentially modified) state
    state
  end
end
```

### Example: Data Injection

```elixir
defmodule MyProject.TestDataHooks do
  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  alias Oli.Resources
  
  def inject_specific_content(%ExecutionState{} = state) do
    # Get a specific project
    case Map.get(state.projects, "my_project") do
      nil -> 
        state  # Project not found, return unchanged
        
      built_project ->
        # Find a specific page
        page_rev = built_project.rev_by_title["Lesson 1"]
        
        # Update its content
        custom_content = %{
          "model" => [
            %{
              "type" => "p",
              "children" => [
                %{"text" => "Injected test content"}
              ]
            }
          ]
        }
        
        {:ok, _} = Resources.update_revision(page_rev, %{content: custom_content})
        
        state
    end
  end
end
```

### Example: Custom Validation

```elixir
defmodule MyProject.ValidationHooks do
  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  
  def validate_custom_conditions(%ExecutionState{} = state) do
    # Check custom conditions
    projects_count = map_size(state.projects)
    sections_count = map_size(state.sections)
    
    cond do
      projects_count < 2 ->
        raise "Expected at least 2 projects, found #{projects_count}"
        
      sections_count != projects_count ->
        raise "Expected equal number of projects and sections"
        
      true ->
        # Validation passed
        state
    end
  end
end
```

### Example: State Extension

```elixir
defmodule MyProject.StateHooks do
  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  
  def add_custom_tracking(%ExecutionState{} = state) do
    # Add custom fields to track additional information
    state
    |> Map.put(:custom_metrics, %{
      operations_count: 0,
      last_operation: nil,
      timestamp: DateTime.utc_now()
    })
  end
  
  def increment_operation_count(%ExecutionState{} = state) do
    metrics = Map.get(state, :custom_metrics, %{operations_count: 0})
    updated_metrics = %{metrics | 
      operations_count: metrics.operations_count + 1,
      last_operation: "hook_executed",
      timestamp: DateTime.utc_now()
    }
    
    Map.put(state, :custom_metrics, updated_metrics)
  end
end
```

## Usage in Scenarios

### Sequential Hooks

```yaml
# Setup
- hook:
    function: "MyProject.StateHooks.add_custom_tracking/1"

# Create project
- project:
    name: "test_project"
    title: "Test Project"
    root:
      children:
        - page: "Page 1"

# Track operation
- hook:
    function: "MyProject.StateHooks.increment_operation_count/1"

# Inject test data
- hook:
    function: "MyProject.TestDataHooks.inject_specific_content/1"

# Validate
- hook:
    function: "MyProject.ValidationHooks.validate_custom_conditions/1"
```

### Conditional Testing

```yaml
# Set a flag
- hook:
    function: "Oli.Scenarios.Hooks.set_test_flag/1"

# ... other operations ...

# Later, use custom hook to check the flag and act accordingly
- hook:
    function: "MyProject.ConditionalHooks.check_and_modify/1"
```

## Error Handling

Hook errors are captured and reported in the execution result:

```elixir
result = Engine.execute(directives)

# Check for hook errors
Enum.each(result.errors, fn {directive, message} ->
  case directive do
    %HookDirective{} ->
      IO.puts("Hook failed: #{message}")
    _ ->
      # Handle other errors
  end
end)
```

Common error messages:
- `"Failed to load module"` - Module doesn't exist
- `"Hook function must have arity 1"` - Wrong number of arguments
- `"Function not found"` - Function doesn't exist in module
- `"Invalid function specification format"` - Incorrect format (should be "Module.function/1")
- `"Hook function must return an ExecutionState"` - Function returned wrong type

## Best Practices

1. **Keep hooks focused**: Each hook should do one specific thing
2. **Document your hooks**: Use @doc strings to explain what each hook does
3. **Handle missing data gracefully**: Check if expected data exists before manipulating
4. **Always return state**: Even if unchanged, always return the ExecutionState
5. **Use descriptive names**: Make hook function names self-documenting
6. **Avoid side effects**: Hooks should primarily modify state, not perform I/O
7. **Test your hooks**: Write unit tests for complex hook functions

## Security Considerations

Hooks can execute any Elixir code, so:
- Only use hooks in test environments
- Never allow user-provided hook specifications
- Review custom hooks for security implications
- Be cautious with hooks that modify database state directly

## Examples Repository

For more examples, see:
- `lib/oli/scenarios/hooks.ex` - Built-in hooks
- `test/scenarios/hooks/hook_demo.scenario.yaml` - Demo scenario
- `test/scenarios/directives/hook_handler_test.exs` - Hook tests

## Limitations

- Hooks must have arity 1 (exactly one argument)
- Hooks must return ExecutionState
- Module must be available at runtime
- Errors in hooks will fail the scenario execution