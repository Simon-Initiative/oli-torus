defmodule Oli.MCP.Resources.SchemasResource do
  @moduledoc """
  Global schemas resource that lists available content schemas.
  """

  use Anubis.Server.Component, type: :resource

  alias Anubis.Server.Response
  alias Oli.MCP.UsageTracker

  @impl true
  def uri, do: "torus://schemas"

  @impl true
  def mime_type, do: "application/vnd.torus.schemas-list+json"

  @impl true
  def read(_params, frame) do
    # Track resource usage
    UsageTracker.track_resource_usage(uri(), frame)

    schemas = [
      %{
        category: "common",
        type: "content",
        name: "Content Element Schema",
        description: "JSON schema for rich content elements",
        uri: "torus://schemas/common/content"
      }
    ]

    {:reply, Response.json(Response.resource(), %{schemas: schemas}), frame}
  end
end
