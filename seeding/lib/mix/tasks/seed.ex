defmodule Mix.Tasks.Seed do
  @moduledoc """
  Runs the environment-neutral Torus seeding CLI in development.

      mix seed scenarios list
      mix seed scenarios run --file path/to/scenario.yaml
      mix seed scenarios run --name oli_torus_getting_started_course
      mix seed projects ingest --url URL --author SELECTOR

  The task mutates the configured development database synchronously. Production
  builds do not compile this task or the seeding CLI.
  """

  use Mix.Task

  alias Oli.Seeding.{CLI, Runtime}

  @shortdoc "Runs a Torus data-seeding command"

  @impl Mix.Task
  @doc "Loads runtime configuration and runs the command in the companion application role."
  def run(args) do
    Mix.Task.run("app.config")
    result = Runtime.run(fn -> CLI.dispatch(args) end)

    case result do
      %{status: 0, output: output} ->
        Mix.shell().info(output)

      %{output: output} ->
        Mix.raise(output)
    end
  end
end
