defmodule Oli.Authoring.Editing.BankEditor do
  @moduledoc """
  This module provides content editing facilities for banked activities.

  """
  import Oli.Authoring.Editing.Utils
  alias Oli.Publishing
  alias Oli.Activities
  alias Oli.Authoring.Editing.PageEditor

  import Ecto.Query, warn: false

  @doc """
  Creates the context necessary to power a client side activity bank editor.
  """
  def create_context(project_slug, author) do
    with {:ok, publication} <-
           Publishing.get_unpublished_publication_by_slug!(project_slug)
           |> trap_nil(),
         {:ok, objectives} <-
           Publishing.get_published_objective_details(publication.id) |> trap_nil(),
         {:ok, objectives_with_parent_reference} <-
           PageEditor.construct_parent_references(objectives) |> trap_nil() do
      editor_map = Activities.create_registered_activity_map(project_slug)

      {:ok,
       %Oli.Authoring.Editing.BankContext{
         authorEmail: author.email,
         projectSlug: project_slug,
         editorMap: editor_map,
         allObjectives: objectives_with_parent_reference
       }}
    else
      _ -> {:error, :not_found}
    end
  end
end
