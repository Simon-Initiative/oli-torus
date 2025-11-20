defmodule Mix.Tasks.Playwright.Seed do
  @moduledoc """
  Execute an `Oli.Scenarios` YAML file to seed data used by Playwright tests.

  By default this task executes `priv/scenarios/playwright_seed.yaml`, but you can
  provide any other scenario file path via `--file`. The task boots the
  application, runs the directives, and prints a short summary of what was
  created. If any directive fails the task will exit with a non-zero status so it
  can be wired into CI/CD workflows.

      mix playwright.seed
      mix playwright.seed --file priv/scenarios/custom.yaml
  """

  use Mix.Task

  alias Oli.Scenarios
  alias Oli.Scenarios.DirectiveTypes.ExecutionResult
  alias Oli.Scenarios.RuntimeOpts

  @shortdoc "Seed Playwright test data via Oli.Scenarios"

  @default_scenario_path "priv/scenarios/playwright_seed.yaml"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, switches: [file: :string])

    scenario_path =
      opts[:file]
      |> default_path()
      |> expand_path()

    unless File.exists?(scenario_path) do
      Mix.raise("Scenario file not found: #{scenario_path}")
    end

    Mix.shell().info("Executing Playwright seed scenario: #{scenario_path}")

    scenario_path
    |> Scenarios.execute_file(RuntimeOpts.build())
    |> report_result(scenario_path)
  end

  defp default_path(nil), do: @default_scenario_path
  defp default_path(path), do: path

  defp expand_path(path) do
    cond do
      Path.type(path) == :absolute -> path
      true -> Path.expand(path, File.cwd!())
    end
  end

  defp report_result(%ExecutionResult{} = result, scenario_path) do
    cond do
      Scenarios.has_errors?(result) ->
        Mix.shell().error("Playwright seed failed for #{scenario_path}")

        Enum.each(result.errors, fn {directive, reason} ->
          Mix.shell().error("  #{inspect(directive)} => #{inspect(reason)}")
        end)

        Mix.raise("Playwright seed scenario contained errors")

      true ->
        summary = Scenarios.summarize(result)
        Mix.shell().info("Playwright seed completed successfully")

        Enum.each(summary, fn {key, value} ->
          Mix.shell().info("  #{key}: #{value}")
        end)
    end
  end
end
