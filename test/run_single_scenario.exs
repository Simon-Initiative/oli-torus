defmodule RunSingleScenarioTest do
  @moduledoc """
  Test runner for executing a single scenario file.
  
  This test reads the scenario file path from the SCENARIO_FILE environment variable
  and executes it. Used by `mix scenarios <file>` to run individual scenario files.
  """
  
  use Oli.DataCase
  
  test "run scenario specified in SCENARIO_FILE env var" do
    scenario_path = System.get_env("SCENARIO_FILE")
    
    # Ensure the env var is set
    assert scenario_path != nil, """
    SCENARIO_FILE environment variable not set.
    
    This test should be run via: mix scenarios <path/to/scenario.yaml>
    """
    
    # Ensure the file exists
    assert File.exists?(scenario_path), """
    Scenario file not found: #{scenario_path}
    """
    
    # Display what we're running
    relative_path = Path.relative_to_cwd(scenario_path)
    IO.puts("\nRunning scenario: #{relative_path}")
    IO.puts(String.duplicate("=", 60))
    
    # Execute the scenario
    result = Oli.Scenarios.TestSupport.execute_file_with_fixtures(scenario_path)
    
    # Check for execution errors
    if Enum.any?(result.errors) do
      IO.puts("\n❌ Execution errors:")
      Enum.each(result.errors, fn {directive, reason} ->
        IO.puts("  #{inspect_directive(directive)}: #{reason}")
      end)
      
      flunk("Scenario '#{relative_path}' had #{length(result.errors)} execution error(s)")
    end
    
    # Check for verification failures
    failed_verifications = Enum.filter(result.verifications, fn v -> !v.passed end)
    
    if Enum.any?(failed_verifications) do
      IO.puts("\n❌ Verification failures:")
      Enum.each(failed_verifications, fn v ->
        IO.puts("  #{v.to || "assertion"}: #{v.message}")
      end)
      
      flunk("Scenario '#{relative_path}' had #{length(failed_verifications)} verification failure(s)")
    end
    
    # Success! Report what was created
    project_count = map_size(result.state.projects)
    section_count = map_size(result.state.sections)
    verification_count = length(result.verifications)
    
    IO.puts("\n✅ Success!")
    IO.puts("  Created: #{project_count} project(s), #{section_count} section(s)")
    IO.puts("  Verified: #{verification_count} assertion(s)")
  end
  
  defp inspect_directive(%{__struct__: module} = directive) do
    name = module |> Module.split() |> List.last() |> String.replace("Directive", "")
    
    case directive do
      %{name: n} -> "#{name}(#{n})"
      %{title: t} -> "#{name}(#{t})"
      %{to: t} -> "#{name}(to: #{t})"
      %{from: f} -> "#{name}(from: #{f})"
      _ -> name
    end
  end
  
  defp inspect_directive(directive), do: inspect(directive)
end