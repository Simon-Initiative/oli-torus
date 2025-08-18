defmodule Oli.MCP.Resources.URIBuilder do
  @moduledoc """
  Utilities for building and parsing MCP resource URIs in Torus.

  Supports the following URI scheme:
  - torus://p/{project}/pages/{id}
  - torus://p/{project}/activities/{id}
  - torus://p/{project}/containers/{id}
  - torus://p/{project}/objectives/{id}
  - torus://p/{project}/hierarchy
  - torus://p/{project}/objectives
  - torus://p/{project}
  - torus://examples (global)
  - torus://examples/{activity_type} (global)
  - torus://schemas (global)
  - torus://schemas/{category}/{type} (global)
  """

  @base_scheme "torus"

  @doc """
  Builds a resource URI for a project.
  """
  def build_project_uri(project_slug) do
    "#{@base_scheme}://p/#{project_slug}"
  end

  @doc """
  Builds a resource URI for a page.
  """
  def build_page_uri(project_slug, page_id) do
    "#{@base_scheme}://p/#{project_slug}/pages/#{page_id}"
  end

  @doc """
  Builds a resource URI for an activity.
  """
  def build_activity_uri(project_slug, activity_id) do
    "#{@base_scheme}://p/#{project_slug}/activities/#{activity_id}"
  end

  @doc """
  Builds a resource URI for a container.
  """
  def build_container_uri(project_slug, container_id) do
    "#{@base_scheme}://p/#{project_slug}/containers/#{container_id}"
  end

  @doc """
  Builds a resource URI for an objective.
  """
  def build_objective_uri(project_slug, objective_id) do
    "#{@base_scheme}://p/#{project_slug}/objectives/#{objective_id}"
  end

  @doc """
  Builds a resource URI for the project hierarchy.
  """
  def build_hierarchy_uri(project_slug) do
    "#{@base_scheme}://p/#{project_slug}/hierarchy"
  end

  @doc """
  Builds a resource URI for the objectives graph.
  """
  def build_objectives_graph_uri(project_slug) do
    "#{@base_scheme}://p/#{project_slug}/objectives"
  end

  @doc """
  Builds a global resource URI for the examples list.
  """
  def build_global_examples_list_uri() do
    "#{@base_scheme}://examples"
  end

  @doc """
  Builds a global resource URI for a specific activity example.
  """
  def build_global_example_uri(activity_type) do
    "#{@base_scheme}://examples/#{activity_type}"
  end

  @doc """
  Builds a global resource URI for the schemas list.
  """
  def build_global_schemas_list_uri() do
    "#{@base_scheme}://schemas"
  end

  @doc """
  Builds a global resource URI for a specific schema.
  """
  def build_global_schema_uri(category, schema_type) do
    "#{@base_scheme}://schemas/#{category}/#{schema_type}"
  end

  @doc """
  Parses a resource URI and returns the components.

  Returns {:ok, {project_slug, resource_type, resource_id}} for project resources,
  or {:ok, {nil, resource_type, resource_id}} for global resources.

  For special resources like hierarchy and objectives graph, resource_id will be nil.
  For global resources like examples and schemas, project_slug will be nil.
  """
  def parse_uri(uri) do

    case URI.parse(uri) do
      %URI{scheme: @base_scheme, host: host, path: path} = _parsed_uri ->
        # Reconstruct the full path including the host part
        full_path = "/#{host}#{path}"
        result = parse_path(full_path)
        result

      %URI{scheme: scheme} ->
        {:error, "Invalid scheme: expected '#{@base_scheme}', got '#{scheme}'"}

      _parsed ->
        {:error, "Invalid URI format"}
    end
  end

  defp parse_path("/p/" <> path) do
    case String.split(path, "/") do
      [project_slug] ->
        {:ok, {project_slug, :project, nil}}

      [project_slug, "hierarchy"] ->
        {:ok, {project_slug, :hierarchy, nil}}

      [project_slug, "objectives"] ->
        {:ok, {project_slug, :objectives_graph, nil}}

      [project_slug, resource_type, resource_id] when resource_type in ["pages", "activities", "containers", "objectives"] ->
        type_atom = case resource_type do
          "pages" -> :page
          "activities" -> :activity
          "containers" -> :container
          "objectives" -> :objective
        end
        {:ok, {project_slug, type_atom, resource_id}}

      _ ->
        {:error, "Invalid path format"}
    end
  end

  # Handle global resources
  defp parse_path("/examples") do
    {:ok, {nil, :examples_list, nil}}
  end

  defp parse_path("/examples/" <> activity_type) do
    {:ok, {nil, :example, activity_type}}
  end

  defp parse_path("/schemas") do
    {:ok, {nil, :schemas_list, nil}}
  end

  defp parse_path("/schemas/" <> path) do
    case String.split(path, "/") do
      [category, schema_type] ->
        {:ok, {nil, :schema, {category, schema_type}}}
      _parts ->
        {:error, "Invalid schema path format"}
    end
  end

  defp parse_path(path) do
    {:error, "Invalid path: #{path}"}
  end

  @doc """
  Gets the MIME type for a resource type.
  """
  def get_mime_type(:project), do: "application/vnd.torus.project+json"
  def get_mime_type(:page), do: "application/vnd.torus.page+json"
  def get_mime_type(:activity), do: "application/vnd.torus.activity+json"
  def get_mime_type(:container), do: "application/vnd.torus.container+json"
  def get_mime_type(:objective), do: "application/vnd.torus.objective+json"
  def get_mime_type(:hierarchy), do: "application/vnd.torus.hierarchy+json"
  def get_mime_type(:objectives_graph), do: "application/vnd.torus.objectives-graph+json"
  def get_mime_type(:examples_list), do: "application/vnd.torus.examples-list+json"
  def get_mime_type(:example), do: "application/vnd.torus.example+json"
  def get_mime_type(:schemas_list), do: "application/vnd.torus.schemas-list+json"
  def get_mime_type(:schema), do: "application/json"
end
