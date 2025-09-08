defmodule Mix.Tasks.Scenarios do
  @moduledoc """
  Run scenario test files.

  ## Usage

  Run all scenarios:
      mix scenarios

  Run a specific scenario file:
      mix scenarios path/to/scenario.yaml
      mix scenarios core/simple_project.scenario.yaml
      mix scenarios core/simple_project

  ## Examples

      # Run all scenarios
      mix scenarios

      # Run a specific scenario (relative to test/scenarios/)
      mix scenarios core/simple_project.scenario.yaml
      mix scenarios core/simple_project  # .scenario.yaml extension is optional

      # Run with full path
      mix scenarios test/scenarios/core/simple_project.scenario.yaml
  """

  use Mix.Task

  @shortdoc "Run scenario test files"

  @impl Mix.Task
  def run(args) do
    case args do
      [] ->
        # Run all scenarios via the test runner
        Mix.shell().info("Running all scenario tests...")
        Mix.shell().info("")
        
        # Run the main scenario runner test
        Mix.Task.run("test", ["test/scenarios/scenario_runner_test.exs"])
      
      [path] ->
        run_single_scenario(path)
      
      _ ->
        Mix.shell().error("Too many arguments. Specify one path or none.")
        Mix.shell().info("")
        Mix.shell().info("Usage:")
        Mix.shell().info("  mix scenarios                    # Run all")
        Mix.shell().info("  mix scenarios file.scenario.yaml  # Run single file")
        exit({:shutdown, 1})
    end
  end

  defp run_single_scenario(path) do
    # Normalize the path
    full_path = normalize_scenario_path(path)
    
    # Check if file exists
    unless File.exists?(full_path) do
      Mix.shell().error("Scenario file not found: #{full_path}")
      suggest_similar(path)
      exit({:shutdown, 1})
    end
    
    # Set the environment variable for the test to read
    System.put_env("SCENARIO_FILE", full_path)
    
    # Run the single scenario test
    Mix.Task.run("test", ["test/run_single_scenario.exs"])
  end

  defp normalize_scenario_path(path) do
    cond do
      # Already a full path starting with test/
      String.starts_with?(path, "test/scenarios/") ->
        path
      
      # Full path but without test/scenarios prefix
      String.starts_with?(path, "/") ->
        path
      
      # Check if file exists as-is (relative to current dir)
      File.exists?(path) ->
        path
      
      # Try with .scenario.yaml extension
      File.exists?(path <> ".scenario.yaml") ->
        path <> ".scenario.yaml"
      
      # Try as relative to test/scenarios/
      true ->
        base_path = Path.join("test/scenarios", path)
        
        cond do
          File.exists?(base_path) ->
            base_path
          
          File.exists?(base_path <> ".scenario.yaml") ->
            base_path <> ".scenario.yaml"
          
          true ->
            # Return the path as-is, file existence check will fail later
            base_path
        end
    end
  end

  defp suggest_similar(path) do
    # Extract the filename part
    filename = Path.basename(path, ".scenario.yaml")
    
    # Find similar files
    all_scenarios = Path.wildcard("test/scenarios/**/*.scenario.yaml") |> Enum.sort()
    similar = all_scenarios
      |> Enum.filter(fn file ->
        String.contains?(String.downcase(file), String.downcase(filename))
      end)
      |> Enum.take(5)
    
    unless Enum.empty?(similar) do
      Mix.shell().info("")
      Mix.shell().info("Did you mean one of these?")
      Enum.each(similar, fn file ->
        relative = String.replace_prefix(file, "test/scenarios/", "")
        Mix.shell().info("  mix scenarios #{relative}")
      end)
    end
  end
end