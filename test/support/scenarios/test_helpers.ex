defmodule Oli.Scenarios.TestHelpers do
  @moduledoc """
  Helper functions for testing with the course specification DSL.
  """

  alias Oli.Scenarios.{Engine, DirectiveParser}
  alias Oli.Scenarios.DirectiveTypes.ExecutionResult

  @doc """
  Executes a YAML specification file and returns the result.
  """
  def execute_spec(yaml_path) do
    Oli.Scenarios.TestSupport.execute_file_with_fixtures(yaml_path)
  end

  @doc """
  Executes YAML content directly and returns the result.
  """
  def execute_yaml(yaml_content) do
    yaml_content
    |> DirectiveParser.parse_yaml!()
    |> Oli.Scenarios.TestSupport.execute_with_fixtures()
  end

  @doc """
  Executes a specification and returns only the state.
  """
  def execute_and_get_state(yaml_path) do
    %ExecutionResult{state: state} = execute_spec(yaml_path)
    state
  end

  @doc """
  Executes a specification and asserts all verifications passed.
  """
  def execute_and_verify!(yaml_path) do
    result = execute_spec(yaml_path)

    # Check for errors
    if Enum.any?(result.errors) do
      raise "Execution errors: #{inspect(result.errors)}"
    end

    # Check all verifications passed
    failed_verifications = Enum.filter(result.verifications, fn v -> !v.passed end)

    if Enum.any?(failed_verifications) do
      messages =
        Enum.map(failed_verifications, fn v ->
          "#{v.to}: #{v.message}"
        end)

      raise "Verification failures:\n#{Enum.join(messages, "\n")}"
    end

    result
  end

  @doc """
  Creates a simple project specification as a string.
  """
  def simple_project_yaml(name, title \\ nil) do
    """
    - project:
        name: "#{name}"
        title: "#{title || name}"
        root:
          children:
            - page: "Page 1"
            - page: "Page 2"
    """
  end

  @doc """
  Creates a simple section specification as a string.
  """
  def simple_section_yaml(name, from_project) do
    """
    - section:
        name: "#{name}"
        from: "#{from_project}"
        title: "Test Section"
    """
  end

  @doc """
  Creates a remix specification as a string.
  """
  def remix_yaml(source, target, resource, _into \\ "root") do
    """
    - remix:
        from: "#{source}"
        to: "#{target}"
        resource: "#{resource}"
    """
  end

  @doc """
  Creates a verify specification as a string.
  """
  def verify_yaml(target, expected_structure) do
    # Parse the structure string and re-indent properly
    lines = expected_structure |> String.trim() |> String.split("\n")
    
    # Add proper YAML indentation - each line needs to be indented under "structure:"
    # The base indentation for items under "structure:" is 6 spaces
    indented_structure = lines
      |> Enum.map(fn line ->
        if String.trim(line) == "" do
          ""
        else
          # Add 6 spaces base indentation
          "      #{line}"
        end
      end)
      |> Enum.join("\n")

    """
    - assert:
        structure:
          to: "#{target}"
#{indented_structure}
    """
  end

  @doc """
  Helper to build a complete test scenario.
  """
  def build_scenario(directives) when is_list(directives) do
    directives
    |> Enum.join("\n")
  end

  @doc """
  Gets a project from the execution result.
  """
  def get_project(%ExecutionResult{state: state}, name) do
    Engine.get_project(state, name)
  end

  @doc """
  Gets a section from the execution result.
  """
  def get_section(%ExecutionResult{state: state}, name) do
    Engine.get_section(state, name)
  end

  @doc """
  Gets a product from the execution result.
  """
  def get_product(%ExecutionResult{state: state}, name) do
    Engine.get_product(state, name)
  end

  @doc """
  Asserts that a project exists in the result.
  """
  def assert_project_exists(%ExecutionResult{} = result, name) do
    project = get_project(result, name)

    if is_nil(project) do
      raise "Expected project '#{name}' to exist"
    end

    project
  end

  @doc """
  Asserts that a section exists in the result.
  """
  def assert_section_exists(%ExecutionResult{} = result, name) do
    section = get_section(result, name)

    if is_nil(section) do
      raise "Expected section '#{name}' to exist"
    end

    section
  end

  @doc """
  Counts the number of verifications that passed.
  """
  def count_passed_verifications(%ExecutionResult{verifications: verifications}) do
    Enum.count(verifications, & &1.passed)
  end

  @doc """
  Counts the number of verifications that failed.
  """
  def count_failed_verifications(%ExecutionResult{verifications: verifications}) do
    Enum.count(verifications, &(!&1.passed))
  end
end
