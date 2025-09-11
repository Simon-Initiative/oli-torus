defmodule Oli.Scenarios.ScenarioRunner do
  @moduledoc """
  Reusable test runner for YAML scenario files.
  Provides functionality to discover and run .scenario.yaml files as individual tests.
  """

  @doc """
  Discovers all .scenario.yaml files in a given directory and subdirectories.
  Returns a list of {relative_path_name, full_path} tuples.
  """
  def discover_scenarios(directory) do
    Path.wildcard(Path.join(directory, "**/*.scenario.yaml"))
    |> Enum.map(fn path ->
      # Create a descriptive name including subdirectory
      relative = Path.relative_to(path, directory)

      name =
        relative
        |> String.replace(".scenario.yaml", "")
        |> String.replace("/", "_")

      {name, path}
    end)
    |> Enum.sort()
  end

  @doc """
  Generates test cases for all scenarios in a directory.
  This macro should be called within a test module.
  """
  defmacro generate_scenario_tests do
    quote do
      # Generate tests at runtime for each discovered scenario
      for {name, path} <- @scenarios do
        @scenario_name name
        @scenario_path path

        test "scenario: #{@scenario_name}" do
          Oli.Scenarios.ScenarioRunner.run_scenario_file!(@scenario_path)
        end
      end
    end
  end

  @doc """
  Runs a single scenario file and returns the result.
  """
  def run_scenario_file(file_path) do
    # Use TestSupport to execute with test fixtures
    Oli.Scenarios.TestSupport.execute_file_with_fixtures(file_path)
  end

  @doc """
  Runs a scenario file and asserts it executed successfully.
  Raises on any errors or failed verifications.
  """
  def run_scenario_file!(file_path) do
    result = run_scenario_file(file_path)

    # Check for execution errors
    if Enum.any?(result.errors) do
      error_messages =
        Enum.map(result.errors, fn {directive, reason} ->
          "#{inspect(directive)}: #{reason}"
        end)

      raise "Scenario '#{Path.basename(file_path)}' had execution errors:\n#{Enum.join(error_messages, "\n")}"
    end

    # Check for failed verifications
    failed_verifications = Enum.filter(result.verifications, fn v -> !v.passed end)

    if Enum.any?(failed_verifications) do
      messages =
        Enum.map(failed_verifications, fn v ->
          "#{v.to}: #{v.message}"
        end)

      raise "Scenario '#{Path.basename(file_path)}' had verification failures:\n#{Enum.join(messages, "\n")}"
    end

    result
  end

  @doc """
  Creates a test module that runs all scenarios in its directory.
  """
  defmacro __using__(opts) do
    opts_ast = opts[:do]

    quote do
      use Oli.DataCase
      import Oli.Scenarios.ScenarioRunner

      # Store the test directory path at compile time
      @test_dir Path.dirname(__ENV__.file)

      # Setup function to discover scenarios
      setup_all do
        # Discover scenarios at runtime
        scenarios = Oli.Scenarios.ScenarioRunner.discover_scenarios(@test_dir)
        {:ok, scenarios: scenarios}
      end

      # Generate tests for each scenario file
      describe "scenario tests" do
        @test_dir Path.dirname(__ENV__.file)

        for {name, path} <- Oli.Scenarios.ScenarioRunner.discover_scenarios(@test_dir) do
          @scenario_name name
          @scenario_path path

          test "scenario: #{@scenario_name}" do
            Oli.Scenarios.ScenarioRunner.run_scenario_file!(@scenario_path)
          end
        end
      end

      # Allow modules to add their own tests
      unquote(opts_ast)
    end
  end
end
