defmodule Mix.Tasks.Scenarios.Coverage do
  @moduledoc """
  Run coverage for scenario-based tests only.

  This task runs ExCoveralls against `test/scenarios/scenario_runner_test.exs`
  so coverage reflects only YAML scenario execution.

  ## Usage

      mix scenarios.coverage
      mix scenarios.coverage --html
      mix scenarios.coverage --detail
      mix scenarios.coverage --xml
  """

  use Mix.Task

  @shortdoc "Run coverage using only scenario tests"

  @scenario_runner "test/scenarios/scenario_runner_test.exs"

  @impl Mix.Task
  def run(args) do
    {opts, rest, invalid} =
      OptionParser.parse(args,
        strict: [html: :boolean, detail: :boolean, xml: :boolean]
      )

    case {rest, invalid} do
      {[], []} ->
        run_coveralls(opts)

      {_, []} ->
        Mix.shell().error("Unexpected arguments: #{Enum.join(rest, " ")}")
        Mix.shell().info("Usage: mix scenarios.coverage [--html | --detail | --xml]")
        exit({:shutdown, 1})

      {_, _} ->
        Mix.shell().error(
          "Invalid options: #{Enum.map_join(invalid, ", ", fn {k, _} -> "--#{k}" end)}"
        )

        Mix.shell().info("Usage: mix scenarios.coverage [--html | --detail | --xml]")
        exit({:shutdown, 1})
    end
  end

  defp run_coveralls(opts) do
    task = coverage_task(opts)

    Mix.shell().info("Running scenario-only coverage via #{task}...")
    Mix.shell().info("Scenario runner: #{@scenario_runner}")
    Mix.shell().info("")

    Mix.Task.run(task, [@scenario_runner])
  end

  defp coverage_task(opts) do
    case opts do
      [html: true] -> "coveralls.html"
      [detail: true] -> "coveralls.detail"
      [xml: true] -> "coveralls.xml"
      [] -> "coveralls"
      _ -> invalid_combination_error()
    end
  end

  defp invalid_combination_error do
    Mix.shell().error("Choose only one format option: --html, --detail, or --xml")
    exit({:shutdown, 1})
  end
end
