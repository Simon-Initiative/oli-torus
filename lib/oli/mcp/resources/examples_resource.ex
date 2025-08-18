defmodule Oli.MCP.Resources.ExamplesResource do
  @moduledoc """
  Global examples resource that lists available activity example types.
  """

  use Anubis.Server.Component, type: :resource, uri: "torus://examples"

  alias Anubis.Server.Response
  alias Oli.MCP.UsageTracker

  @impl true
  def uri, do: "torus://examples"

  @impl true
  def mime_type, do: "application/vnd.torus.examples-list+json"

  @impl true
  def read(_params, frame) do
    # Track resource usage
    UsageTracker.track_resource_usage(uri(), frame)

    # For now, only support oli_multiple_choice
    examples = [
      %{
        type: "oli_multiple_choice",
        name: "Multiple Choice",
        description: "Single-select question with multiple options",
        uri: "torus://examples/oli_multiple_choice"
      }
    ]

    {:reply, Response.json(Response.resource(), %{examples: examples}), frame}
  end
end
