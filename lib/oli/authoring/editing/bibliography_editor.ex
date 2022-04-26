defmodule Oli.Authoring.Editing.BibliographyEditor do
  @moduledoc """
  This module provides content editing facilities for bibliography entries.

  """
  import Oli.Authoring.Editing.Utils
  alias Oli.Publishing

  import Ecto.Query, warn: false

  @doc """
  Creates the context necessary to power a client side bibliography editor.
  """
  def create_context(project_slug, author) do
    with {:ok, publication} <-
           Publishing.project_working_publication(project_slug)
           |> trap_nil(),
         {:ok, bib_entries} <- Oli.Authoring.Editing.BibEntryEditor.list(project_slug, author)
    do
      {:ok,
       %Oli.Authoring.Editing.BibliographyContext{
         authorEmail: author.email,
         projectSlug: project_slug,
        #  allBibEntrys: Enum.map(bib_entries, fn t -> %{id: t.resource_id, title: t.title} end),
         totalCount: length(bib_entries)
       }}
    else
      _ -> {:error, :not_found}
    end
  end
end
