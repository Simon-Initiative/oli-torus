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

      {normalized_content, title} = normalize_entry(entry)

      attrs = %{
        "title" => title,
        "author_id" => author.id,
        # store normalized content directly; UI/CitationJS can handle list | map | string
        "content" => %{data: normalized_content}
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
        {:error, "Failed to add bibliography entry to '#{project_name}': #{Exception.message(e)}"}
    end
  end

  # Accepts bibtex strings, JSON strings, or already-parsed maps/lists and
  # normalizes them for storage.
  defp normalize_entry(entry) when is_binary(entry) do
    parsed = Jason.decode(entry)

    cond do
      match?({:ok, _}, parsed) ->
        {:ok, data} = parsed
        {data, extract_title(data) || entry}

      true ->
        # Assume bibtex string; store raw string
        {entry, entry}
    end
  end

  defp normalize_entry(entry) when is_list(entry) or is_map(entry) do
    {entry, extract_title(entry) || inspect(entry)}
  end

  defp normalize_entry(entry), do: {entry, inspect(entry)}

  defp extract_title([%{"title" => title} | _]), do: title
  defp extract_title(%{"title" => title}), do: title
  defp extract_title(_), do: nil
end
