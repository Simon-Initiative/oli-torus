defmodule Oli.MCP.Resources.ProjectResources do
  @moduledoc """
  MCP resource provider for Torus project content.

  Exposes project content as individual MCP resources with stable URIs following the scheme:
  - torus://p/{project}/pages/{id}
  - torus://p/{project}/activities/{id}
  - torus://p/{project}/containers/{id}
  - torus://p/{project}/objectives/{id}
  - torus://p/{project}/hierarchy
  - torus://p/{project}/objectives
  - torus://p/{project}

  Supports both list and read operations for browsing and accessing project content.
  """

  use Anubis.Server.Component, type: :resource, uri: "torus://p"

  alias Anubis.Server.Response

  @impl true
  def uri, do: "torus://p"

  @impl true
  def mime_type, do: "application/json"

  alias Oli.Publishing.AuthoringResolver
  alias Anubis.Server.Response
  alias Anubis.Server.Component.Resource
  alias Oli.MCP.Auth.Authorization
  alias Oli.MCP.Resources.{URIBuilder, HierarchyBuilder}
  alias Oli.MCP.UsageTracker

  @impl true
  def read(%{"uri" => uri}, frame) do
    # Track resource usage
    UsageTracker.track_resource_usage(uri, frame)

    case URIBuilder.parse_uri(uri) do
      {:ok, {project_slug, resource_type, resource_id}} when not is_nil(project_slug) ->
        # Validate project access before proceeding for project-specific resources
        case Authorization.validate_project_access(project_slug, frame) do
          {:ok, _auth_context} ->
            handle_resource_read(project_slug, resource_type, resource_id, frame)

          {:error, reason} ->
            {:error, Anubis.MCP.Error.resource(:not_found, %{message: "Authorization failed: #{reason}"}), frame}
        end

      {:ok, {nil, resource_type, resource_id}} ->
        # Handle global resources (no project validation needed)
        handle_resource_read(nil, resource_type, resource_id, frame)

      {:error, reason} ->
        {:error, Anubis.MCP.Error.resource(:not_found, %{message: reason}), frame}
    end
  end

  # Handle reading different resource types
  defp handle_resource_read(project_slug, :project, nil, frame) do
    case get_project_metadata(project_slug) do
      {:ok, metadata} ->
        json_content = Jason.encode!(metadata, pretty: true)
        {:reply, Response.text(Response.resource(), json_content), frame}

      {:error, reason} ->
        {:error, Anubis.MCP.Error.resource(:not_found, %{message: reason}), frame}
    end
  end

  defp handle_resource_read(project_slug, :hierarchy, nil, frame) do
    case get_project_hierarchy(project_slug) do
      {:ok, hierarchy} ->
        json_content = Jason.encode!(hierarchy, pretty: true)
        {:reply, Response.text(Response.resource(), json_content), frame}

      {:error, reason} ->
        {:error, Anubis.MCP.Error.resource(:not_found, %{message: reason}), frame}
    end
  end

  defp handle_resource_read(project_slug, :objectives_graph, nil, frame) do
    case get_objectives_graph(project_slug) do
      {:ok, objectives} ->
        json_content = Jason.encode!(objectives, pretty: true)
        {:reply, Response.text(Response.resource(), json_content), frame}

      {:error, reason} ->
        {:error, Anubis.MCP.Error.resource(:not_found, %{message: reason}), frame}
    end
  end


  defp handle_resource_read(project_slug, resource_type, resource_id, frame)
       when resource_type in [:page, :activity, :container, :objective] do
    case get_resource_content(project_slug, resource_type, resource_id) do
      {:ok, content} ->
        json_content = Jason.encode!(content, pretty: true)
        {:reply, Response.text(Response.resource(), json_content), frame}

      {:error, reason} ->
        {:error, Anubis.MCP.Error.resource(:not_found, %{message: reason}), frame}
    end
  end

  # Helper functions for retrieving content

  defp get_project_metadata(project_slug) do
    case Oli.Authoring.Course.get_project_by_slug(project_slug) do
      nil ->
        {:error, "Project not found: #{project_slug}"}

      %{deleted: true} ->
        {:error, "Project has been deleted: #{project_slug}"}

      project ->
        metadata = %{
          slug: project.slug,
          title: project.title,
          description: project.description,
          status: project.status,
          created: project.inserted_at,
          updated: project.updated_at
        }
        {:ok, metadata}
    end
  end

  defp get_project_hierarchy(project_slug) do
    try do
      hierarchy_node = AuthoringResolver.full_hierarchy(project_slug)
      hierarchy = HierarchyBuilder.build_hierarchy_resource(hierarchy_node, project_slug)
      {:ok, hierarchy}
    rescue
      _ ->
        {:error, "Failed to retrieve project hierarchy for: #{project_slug}"}
    end
  end

  defp get_objectives_graph(project_slug) do
    try do
      # Get the objective resource type ID
      objective_type_id = Oli.Resources.ResourceType.get_id_by_type("objective")

      # Get all objective revisions for the project
      objective_revisions = AuthoringResolver.revisions_of_type(project_slug, objective_type_id)

      # Transform into graph format with relationships
      objectives = Enum.map(objective_revisions, fn revision ->
        %{
          resource_uri: URIBuilder.build_objective_uri(project_slug, revision.resource_id),
          resource_id: revision.resource_id,
          title: revision.title || revision.slug || "Untitled Objective",
          children: Map.get(revision, :children, []) || []
        }
      end)

      {:ok, %{objectives: objectives, project_slug: project_slug}}
    rescue
      e ->
        {:error, "Failed to retrieve objectives for: #{project_slug} - #{inspect(e)}"}
    end
  end

  defp get_resource_content(project_slug, resource_type, resource_id) do
    try do
      # Convert string resource_id to integer if needed
      resource_id = case Integer.parse(resource_id) do
        {id, ""} -> id
        _ -> resource_id
      end

      case AuthoringResolver.from_resource_id(project_slug, resource_id) do
        nil ->
          {:error, "Resource not found: project '#{project_slug}', resource_id '#{resource_id}'"}

        %{deleted: true} ->
          {:error, "Resource has been deleted: project '#{project_slug}', resource_id '#{resource_id}'"}

        revision ->
          # Verify resource type matches expectation
          actual_type = get_type_from_resource_type_id(revision.resource_type_id)
          if actual_type == resource_type do
            {:ok, %{
              resource_id: revision.resource_id,
              slug: revision.slug,
              title: revision.title,
              content: revision.content,
              objectives: Map.get(revision, :objectives, []),
              resource_type: actual_type,
              created: revision.inserted_at,
              updated: revision.updated_at
            }}
          else
            {:error, "Resource type mismatch: expected #{resource_type}, got #{actual_type}"}
          end
      end
    rescue
      e ->
        {:error, "Failed to retrieve resource content: #{inspect(e)}"}
    end
  end

  defp get_type_from_resource_type_id(1), do: :page
  defp get_type_from_resource_type_id(2), do: :container
  defp get_type_from_resource_type_id(4), do: :objective
  defp get_type_from_resource_type_id(id) when id > 2 and id != 4 do
    # Activities have resource_type_id > 2 (but not 4 which is objective)
    :activity
  end
  defp get_type_from_resource_type_id(_), do: :unknown


  # Resource templates that tell MCP clients about available URI patterns
  def resource_templates do
    [
      %Resource{
        uri_template: "torus://p/{project}",
        name: "Project Metadata",
        description: "Project information and metadata",
        mime_type: URIBuilder.get_mime_type(:project),
        handler: __MODULE__
      },
      %Resource{
        uri_template: "torus://p/{project}/hierarchy",
        name: "Project Hierarchy",
        description: "Complete nested course outline with containers, pages, and activities",
        mime_type: URIBuilder.get_mime_type(:hierarchy),
        handler: __MODULE__
      },
      %Resource{
        uri_template: "torus://p/{project}/objectives",
        name: "Learning Objectives Graph",
        description: "Directed graph of learning objectives and their relationships",
        mime_type: URIBuilder.get_mime_type(:objectives_graph),
        handler: __MODULE__
      },
      %Resource{
        uri_template: "torus://p/{project}/pages/{id}",
        name: "Course Page",
        description: "Individual course page content",
        mime_type: URIBuilder.get_mime_type(:page),
        handler: __MODULE__
      },
      %Resource{
        uri_template: "torus://p/{project}/activities/{id}",
        name: "Learning Activity",
        description: "Interactive learning activity with questions and assessments",
        mime_type: URIBuilder.get_mime_type(:activity),
        handler: __MODULE__
      },
      %Resource{
        uri_template: "torus://p/{project}/containers/{id}",
        name: "Content Container",
        description: "Container that groups pages and activities into sections",
        mime_type: URIBuilder.get_mime_type(:container),
        handler: __MODULE__
      },
      %Resource{
        uri_template: "torus://p/{project}/objectives/{id}",
        name: "Learning Objective",
        description: "Individual learning objective definition",
        mime_type: URIBuilder.get_mime_type(:objective),
        handler: __MODULE__
      },
    ]
  end
end
