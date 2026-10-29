defmodule Mix.Tasks.Oli.Genai.Audit do
  @shortdoc "Reports secret-free GenAI migration and node-capacity audit"
  @moduledoc "Run with the target release environment before routing cutover; the audit sends no inference, but ordinary application startup may run independent probes. Set GENAI_HEALTH_CHECKS_ENABLED=false for probe-free maintenance."
  use Mix.Task

  @impl true
  def run(_) do
    Mix.Task.run("app.start")
    Mix.shell().info(Jason.encode!(Oli.GenAI.Operations.audit(), pretty: true))
  end
end
