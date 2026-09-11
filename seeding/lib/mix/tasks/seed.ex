defmodule Mix.Tasks.Seed do
  @moduledoc """
  Runs the environment-neutral Torus seeding CLI in development.

      mix seed scenarios list
      mix seed scenarios run --file path/to/scenario.yaml
      mix seed scenarios run --name preview_smoke
      mix seed projects ingest --url URL --author SELECTOR

  The task mutates the configured development database synchronously. Production
  builds do not compile this task or the seeding CLI.
  """

  use Mix.Task

  alias Oli.Seeding.CLI

  @shortdoc "Runs a Torus data-seeding command"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    result = CLI.dispatch(args, enabled?: Mix.env() == :dev)

    case result do
      %{status: 0, output: output} ->
        Mix.shell().info(output)

      %{output: output} ->
        Mix.raise(output)
    end
  end
end
