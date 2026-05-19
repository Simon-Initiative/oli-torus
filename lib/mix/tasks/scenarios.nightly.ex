defmodule Mix.Tasks.Scenarios.Nightly do
  @moduledoc """
  Run scenario tests tagged as nightly.

  ## Usage

      mix scenarios.nightly
  """

  use Mix.Task

  @shortdoc "Run nightly scenario tests"

  @impl Mix.Task
  def run(args) do
    case args do
      [] ->
        Mix.shell().info("Running nightly scenario tests...")
        Mix.Task.run("test", ["--only", "nightly", "test/scenarios"])

      _ ->
        Mix.shell().error("Too many arguments.")
        Mix.shell().info("")
        Mix.shell().info("Usage:")
        Mix.shell().info("  mix scenarios.nightly")
        exit({:shutdown, 1})
    end
  end
end
