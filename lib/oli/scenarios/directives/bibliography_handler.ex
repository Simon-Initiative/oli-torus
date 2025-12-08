defmodule Oli.Scenarios.Directives.BibliographyHandler do
  @moduledoc """
  Handles bibliography directives by adding an entry to a project's bibliography.
  """

  alias Oli.Scenarios.DirectiveTypes.BibliographyDirective
  alias Oli.Scenarios.Engine
  alias Oli.Authoring.Editing.BibEntryEditor

  def handle(%BibliographyDirective{project: project_name, entry: entry}, state) do
    try do
      built_project =
        Engine.get_project(state, project_name) ||
          raise "Project '#{project_name}' not found in scenario state"

      author = state.current_author || raise "current_author missing from execution state"

      attrs = %{
        "title" => entry,
        "author_id" => author.id,
        # store raw entry as-is; API wraps JSON under data
        "content" => %{data: %{"bibtex" => entry}}
      }

      case BibEntryEditor.create(built_project.project.slug, author, attrs) do
        {:ok, _rev} ->
          {:ok, state}

        {:error, {:not_authorized}} ->
          raise "Author not authorized to add bibliography to project '#{project_name}'"

        {:error, reason} ->
          raise "Failed to add bibliography: #{inspect(reason)}"
      end
    rescue
      e ->
        {:error,
         "Failed to add bibliography entry to '#{project_name}': #{Exception.message(e)}"}
    end
  end
end
