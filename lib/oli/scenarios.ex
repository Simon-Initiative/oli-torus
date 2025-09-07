defmodule Oli.Scenarios do
  @moduledoc """
  Production API for executing scenario specifications.
  
  This module provides a high-level interface for creating and manipulating
  Torus course structures using a YAML-based DSL. It supports:
  
  - Project creation with hierarchical content structures
  - Section creation and management
  - Product blueprints
  - Content remixing between projects
  - User and institution management
  - Activity creation and editing
  - Assertions for validation
  
  ## Basic Usage
  
      # Execute directives from a YAML file
      result = Oli.Scenarios.execute_file("path/to/scenario.yaml")
      
      # Execute directives directly
      directives = [
        %ProjectDirective{name: "my_project", title: "My Project", ...}
      ]
      result = Oli.Scenarios.execute(directives)
      
      # Execute with custom author/institution
      result = Oli.Scenarios.execute(directives, 
        author: author,
        institution: institution
      )
  
  ## Result Structure
  
  All execution functions return an `ExecutionResult` with:
  - `state`: Final execution state with all created entities
  - `verifications`: List of assertion results
  - `errors`: Any errors encountered during execution
  """
  
  alias Oli.Scenarios.{Engine, DirectiveParser}
  alias Oli.Scenarios.DirectiveTypes.ExecutionResult
  
  @doc """
  Executes a list of directives with optional configuration.
  
  ## Options
  
  - `:author` - Use specific author instead of creating default
  - `:institution` - Use specific institution instead of creating default
  
  ## Examples
  
      directives = [...]
      result = Oli.Scenarios.execute(directives)
      
      # With custom author
      result = Oli.Scenarios.execute(directives, author: my_author)
  """
  def execute(directives, opts \\ []) when is_list(directives) do
    Engine.execute(directives, opts)
  end
  
  @doc """
  Parses and executes YAML content containing directives.
  
  ## Examples
  
      yaml = \"\"\"
      - project:
          name: "test"
          title: "Test Project"
      \"\"\"
      
      result = Oli.Scenarios.execute_yaml(yaml)
  """
  def execute_yaml(yaml_content, opts \\ []) when is_binary(yaml_content) do
    yaml_content
    |> DirectiveParser.parse_yaml!()
    |> Engine.execute(opts)
  end
  
  @doc """
  Loads and executes a YAML file containing directives.
  
  ## Examples
  
      result = Oli.Scenarios.execute_file("scenarios/demo.yaml")
  """
  def execute_file(yaml_path, opts \\ []) when is_binary(yaml_path) do
    Engine.execute_file(yaml_path, opts)
  end
  
  @doc """
  Gets a project from execution result by name.
  """
  def get_project(%ExecutionResult{state: state}, name) do
    Engine.get_project(state, name)
  end
  
  @doc """
  Gets a section from execution result by name.
  """
  def get_section(%ExecutionResult{state: state}, name) do
    Engine.get_section(state, name)
  end
  
  @doc """
  Gets a product from execution result by name.
  """
  def get_product(%ExecutionResult{state: state}, name) do
    Engine.get_product(state, name)
  end
  
  @doc """
  Gets a user from execution result by name.
  """
  def get_user(%ExecutionResult{state: state}, name) do
    Engine.get_user(state, name)
  end
  
  @doc """
  Gets an institution from execution result by name.
  """
  def get_institution(%ExecutionResult{state: state}, name) do
    Engine.get_institution(state, name)
  end
  
  @doc """
  Checks if all verifications passed in the result.
  """
  def all_verifications_passed?(%ExecutionResult{verifications: verifications}) do
    Enum.all?(verifications, & &1.passed)
  end
  
  @doc """
  Checks if execution had any errors.
  """
  def has_errors?(%ExecutionResult{errors: errors}) do
    Enum.any?(errors)
  end
  
  @doc """
  Gets a summary of the execution result.
  """
  def summarize(%ExecutionResult{} = result) do
    %{
      projects_created: map_size(result.state.projects),
      sections_created: map_size(result.state.sections),
      products_created: map_size(result.state.products),
      users_created: map_size(result.state.users),
      institutions_created: map_size(result.state.institutions),
      verifications_passed: Enum.count(result.verifications, & &1.passed),
      verifications_failed: Enum.count(result.verifications, & !&1.passed),
      errors: length(result.errors)
    }
  end
end