defmodule Oli.MCP.Resources.SchemaResource do
  @moduledoc """
  Individual schema resource for content schemas.
  """

  use Anubis.Server.Component, type: :resource, uri: "torus://schemas/common/content"

  alias Anubis.Server.Response

  @impl true
  def uri, do: "torus://schemas/common/content"

  @impl true
  def mime_type, do: "application/json"

  @impl true
  def read(_params, frame) do

    schema_path = Application.app_dir(:oli, "priv/schemas/v0-1-0/content-element.schema.json")

    case File.read(schema_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, schema} ->
            {:reply, Response.json(Response.resource(), schema), frame}
          {:error, reason} ->
            {:error, Anubis.MCP.Error.resource(:not_found, %{message: "Failed to parse schema file as JSON: #{inspect(reason)}"}), frame}
        end
      {:error, reason} ->
        {:error, Anubis.MCP.Error.resource(:not_found, %{message: "Failed to read content schema file: #{inspect(reason)}"}), frame}
    end
  end
end
