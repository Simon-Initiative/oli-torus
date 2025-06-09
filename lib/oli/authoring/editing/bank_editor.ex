defmodule Oli.Authoring.Editing.BankEditor do
  @moduledoc """
  This module provides content editing facilities for banked activities.

  """
  import Oli.Authoring.Editing.Utils
  alias Oli.Publishing
  alias Oli.Activities
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Query.Paging
  alias Oli.Activities.Realizer.Query
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Query.Result

  import Ecto.Query, warn: false

  @doc """
  Creates the context necessary to power a client side activity bank editor.
  """
  def create_context(project_slug, author) do
    with {:ok, publication} <-
           Publishing.project_working_publication(project_slug)
           |> trap_nil(),
         {:ok, objectives} <-
           Publishing.get_published_objective_details(publication.id) |> trap_nil(),
         {:ok, objectives_with_parent_reference} <-
           PageEditor.construct_parent_references(objectives) |> trap_nil(),
         {:ok, tags} <-
           Oli.Authoring.Editing.ResourceEditor.list(
             project_slug,
             author,
             Oli.Resources.ResourceType.id_for_tag()
           ),
         {:ok, %Result{totalCount: totalCount}} <-
           Query.execute(
             %Logic{conditions: nil},
             %Source{
               publication_id: publication.id,
               blacklisted_activity_ids: [],
               section_slug: ""
             },
             %Paging{limit: 1, offset: 0}
           ) do
      editor_map =
        Activities.create_registered_activity_map(project_slug)
        |> Enum.reject(fn {_key, entry} -> entry.isLtiActivity end)
        |> Enum.into(%{})

      project = Oli.Authoring.Course.get_project_by_slug(project_slug)

      {:ok,
       %Oli.Authoring.Editing.BankContext{
         authorEmail: author.email,
         projectSlug: project_slug,
         editorMap: editor_map,
         allObjectives: objectives_with_parent_reference,
         allTags: Enum.map(tags, fn t -> %{id: t.resource_id, title: t.title} end),
         totalCount: totalCount,
         allowTriggers: project.allow_triggers
       }}
    else
      _ -> {:error, :not_found}
    end
  end
end
