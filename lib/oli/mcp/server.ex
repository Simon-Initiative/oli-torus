defmodule Oli.MCP.Server do
  @moduledoc """
  MCP (Model Context Protocol) server for external AI agents to interact with Torus.

  This server provides tools for external AI agents to retrieve and work with
  Torus content, enabling them to author course materials.

  Uses Anubis MCP for MCP protocol implementation.

  Authentication is initialized in the init/2 callback using the Authorization
  header. Dynamic project reads also validate the current request's Bearer token
  because Anubis shares the frame between client sessions.
  """

  use Anubis.Server,
    name: "torus",
    version: "1.0.0",
    capabilities: [:tools, :resources]

  alias Anubis.MCP.Error
  alias Anubis.Server.{Frame, Handlers, Response}
  alias Oli.MCP.Auth
  alias Oli.MCP.Resources.{ProjectResources, URIBuilder}

  # Register our resources
  component(Oli.MCP.Resources.ProjectResources)
  component(Oli.MCP.Resources.SchemasResource)
  component(Oli.MCP.Resources.SchemaResource)
  component(Oli.MCP.Resources.ExamplesResource)
  component(Oli.MCP.Resources.ExampleResource)

  # Register our tools
  component(Oli.MCP.Tools.ActivityValidationTool)
  component(Oli.MCP.Tools.ActivityTestEvalTool)
  component(Oli.MCP.Tools.CreateActivityTool)

  @doc """
  Lists project resource templates and dispatches dynamic project reads.

  Anubis 0.14 only dispatches exact static resource URIs. Project reads must
  still pass through the project-resource handler's authorization checks.
  """
  @impl true
  def handle_request(%{"method" => "resources/templates/list"} = request, frame) do
    resources = Frame.get_components(frame) ++ ProjectResources.resource_templates()
    template_frame = Frame.put_private(frame, :__mcp_components__, resources)

    {:reply, result, _} =
      Handlers.Resources.handle_templates_list(request, template_frame, __MODULE__)

    {:reply, result, frame}
  end

  def handle_request(
        %{"method" => "resources/read", "params" => %{"uri" => "torus://p/" <> _ = uri}},
        frame
      ) do
    with {:ok, {_project, type, _id}} <- URIBuilder.parse_uri(uri),
         {:ok, request_frame} <- authenticate_request(frame),
         {:reply, response, _request_frame} <-
           ProjectResources.read(%{"uri" => uri}, request_frame) do
      content = Response.to_protocol(response, uri, URIBuilder.get_mime_type(type))
      {:reply, %{"contents" => [content]}, frame}
    else
      {:error, %Error{} = error, _request_frame} ->
        {:error, error, frame}

      {:error, _reason} ->
        {:error, Error.resource(:not_found, %{message: "Resource unavailable"}), frame}
    end
  end

  @doc "Initializes the MCP authentication context from the request's Bearer token."
  @impl true
  def init(_arg, frame) do
    case authenticate_request(frame) do
      {:ok, frame} ->
        Auth.track_usage_by_token(frame.assigns.bearer_token, "init")
        {:ok, frame}

      {:error, _reason} ->
        {:stop, :unauthorized}
    end
  end

  # Anubis shares the frame between sessions, so never trust a previous request's
  # assigns when reading project content. Validate this request's bearer token.
  defp authenticate_request(frame) do
    with {_, "Bearer " <> token} <-
           Enum.find(Map.get(frame.transport, :req_headers, []), fn {name, _} ->
             name == "authorization"
           end),
         {:ok, %{author_id: author_id, project_id: project_id}} <- Auth.validate_token(token) do
      {:ok,
       Map.put(frame, :assigns, %{
         author_id: author_id,
         project_id: project_id,
         bearer_token: token
       })}
    else
      _ -> {:error, :unauthorized}
    end
  end
end
