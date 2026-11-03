defmodule Mix.Tasks.App.Version do
  use Boundary, classify_to: Oli
  use Mix.Task

  def run(_) do
    IO.puts(Mix.Project.config()[:version])
  end
end
