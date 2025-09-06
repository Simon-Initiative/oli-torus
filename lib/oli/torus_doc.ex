defmodule Oli.TorusDoc do
  @moduledoc """
  Main module for processing TorusDoc documents and directives.
  
  This module handles both page-level content and project-level directives
  such as cloning projects.
  """
  
  alias Oli.Authoring.Clone
  alias Oli.TorusDoc.PageParser
  alias Oli.TorusDoc.PageConverter
  
  @doc """
  Processes a TorusDoc YAML document.
  
  The document can contain either:
  - A page definition (type: page)
  - A project directive (type: project_directive)
  
  ## Examples
  
      # Page document
      iex> yaml = \"\"\"
      type: page
      title: My Page
      blocks:
        - type: prose
          body_md: "Hello world"
      \"\"\"
      iex> Oli.TorusDoc.process(yaml)
      {:ok, %{"type" => "Page", ...}}
      
      # Clone directive
      iex> yaml = \"\"\"
      type: project_directive
      directive: clone
      from: source-project-slug
      to: new-project-slug
      \"\"\"
      iex> Oli.TorusDoc.process(yaml, %{author: author})
      {:ok, %{cloned_project: %Project{...}}}
  
  """
  def process(yaml_string, context \\ %{}) when is_binary(yaml_string) do
    case YamlElixir.read_from_string(yaml_string) do
      {:ok, data} ->
        process_document(data, context)
        
      {:error, reason} ->
        {:error, "YAML parsing failed: #{inspect(reason)}"}
    end
  end
  
  defp process_document(%{"type" => "page"} = data, context) do
    # This is a page document, use the existing page processing pipeline
    with {:ok, parsed_page} <- PageParser.parse_page(data),
         {:ok, json} <- PageConverter.to_torus_json(parsed_page, context) do
      {:ok, json}
    end
  end
  
  defp process_document(%{"type" => "project_directive"} = data, context) do
    # This is a project-level directive
    process_project_directive(data, context)
  end
  
  defp process_document(%{"type" => type}, _context) do
    {:error, "Unknown document type: #{type}. Expected 'page' or 'project_directive'"}
  end
  
  defp process_document(_, _context) do
    {:error, "Document must have a 'type' field"}
  end
  
  defp process_project_directive(%{"directive" => "clone"} = data, context) do
    from = data["from"]
    to = data["to"]
    author = Map.get(context, :author)
    
    cond do
      is_nil(from) ->
        {:error, "Clone directive requires 'from' field with source project slug"}
        
      is_nil(to) ->
        {:error, "Clone directive requires 'to' field with target project slug"}
        
      is_nil(author) ->
        {:error, "Clone directive requires author context"}
        
      true ->
        case Clone.clone_project(from, author) do
          {:ok, cloned_project} ->
            {:ok, %{
              type: "clone_result",
              success: true,
              source_project: from,
              cloned_project: cloned_project,
              message: "Successfully cloned project '#{from}' to new project with ID: #{cloned_project.id}"
            }}
            
          {:error, reason} ->
            {:error, "Failed to clone project '#{from}': #{inspect(reason)}"}
        end
    end
  end
  
  defp process_project_directive(%{"directive" => directive}, _context) do
    {:error, "Unknown project directive: #{directive}. Supported directives: clone"}
  end
  
  defp process_project_directive(_, _context) do
    {:error, "Project directive must have a 'directive' field"}
  end
  
end