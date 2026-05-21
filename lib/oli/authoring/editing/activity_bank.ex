defmodule Oli.Authoring.Editing.ActivityBank do
  @moduledoc """
  Application-layer operations for author-facing Activity Bank workflows.

  This module keeps Activity Bank behavior available outside web controllers and
  React UI orchestration so scenarios and tests can exercise the same business
  operations directly.
  """

  import Oli.Authoring.Editing.Utils

  alias Oli.Activities
  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Query
  alias Oli.Activities.Realizer.Query.Paging
  alias Oli.Activities.Realizer.Query.Result
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Authoring.Course
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Authoring.Editing.BankContext
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Publishing
  alias Oli.Resources.Revision
  alias Oli.Resources.ResourceType

  @default_query_source_section_slug ""

  @doc """
  Creates the context needed by the Activity Bank editor.
  """
  def context(project_slug, author) do
    with {:ok, publication} <-
           Publishing.project_working_publication(project_slug)
           |> trap_nil(),
         {:ok, objectives} <-
           Publishing.get_published_objective_details(publication.id) |> trap_nil(),
         {:ok, objectives_with_parent_reference} <-
           PageEditor.construct_parent_references(objectives) |> trap_nil(),
         {:ok, tags} <-
           ResourceEditor.list(project_slug, author, ResourceType.id_for_tag()),
         {:ok, %Result{totalCount: total_count}} <-
           query(project_slug, author, %Logic{conditions: nil}, %Paging{limit: 1, offset: 0}) do
      editor_map =
        Activities.create_registered_activity_map(project_slug)
        |> Enum.reject(fn {_key, entry} -> entry.isLtiActivity end)
        |> Enum.into(%{})

      project = Course.get_project_by_slug(project_slug)

      {:ok,
       %BankContext{
         authorEmail: author.email,
         projectSlug: project_slug,
         editorMap: editor_map,
         allObjectives: objectives_with_parent_reference,
         allTags: Enum.map(tags, fn tag -> %{id: tag.resource_id, title: tag.title} end),
         totalCount: total_count,
         allowTriggers: project.allow_triggers
       }}
    else
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Executes a paged Activity Bank query for the project's working publication.

  `logic` and `paging` may be already parsed structs or the JSON-like maps sent
  by the Activity Bank client.
  """
  def query(project_slug, author, logic, paging) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, %Logic{} = parsed_logic} <- parse_logic(logic),
         {:ok, %Paging{} = parsed_paging} <- parse_paging(paging),
         {:ok, publication} <-
           Publishing.project_working_publication(project_slug) |> trap_nil() do
      query_publication(publication.id, parsed_logic, parsed_paging)
    else
      error -> error
    end
  end

  @doc """
  Executes a paged Activity Bank query against a known publication.

  This is useful when the caller has already resolved a publication, such as
  delivery-preview flows.
  """
  def query_publication(publication_id, %Logic{} = logic, %Paging{} = paging, opts \\ []) do
    Query.execute(
      logic,
      %Source{
        publication_id: publication_id,
        blacklisted_activity_ids: Keyword.get(opts, :blacklisted_activity_ids, []),
        section_slug: Keyword.get(opts, :section_slug, @default_query_source_section_slug)
      },
      paging
    )
  end

  @doc """
  Creates a single banked activity.
  """
  def create(project_slug, author, attrs) when is_map(attrs) do
    ActivityEditor.create(
      project_slug,
      map_value(attrs, :activity_type_slug) || map_value(attrs, :type),
      author,
      map_value(attrs, :model) || map_value(attrs, :content) || %{},
      map_value(attrs, :objectives) || [],
      "banked",
      map_value(attrs, :title),
      map_value(attrs, :objective_map) || %{},
      map_value(attrs, :tags) || []
    )
  end

  @doc """
  Creates multiple banked activities.
  """
  def create_bulk(project_slug, author, attrs_list) when is_list(attrs_list) do
    ActivityEditor.create_bulk(project_slug, author, attrs_list, "banked")
  end

  @doc """
  Updates a banked activity using the same ActivityEditor path as the UI.
  """
  def update(project_slug, author, activity_resource_id, attrs) when is_map(attrs) do
    ActivityEditor.edit(
      project_slug,
      activity_resource_id,
      activity_resource_id,
      author.email,
      attrs
    )
  end

  @doc """
  Deletes a banked activity using the same ActivityEditor path as the UI.
  """
  def delete(project_slug, author, activity_resource_id) do
    ActivityEditor.delete(project_slug, activity_resource_id, activity_resource_id, author)
  end

  @doc """
  Deletes multiple banked activities.
  """
  def delete_bulk(project_slug, author, activity_resource_ids)
      when is_list(activity_resource_ids) do
    ActivityEditor.delete_bulk(project_slug, activity_resource_ids, author)
  end

  @doc """
  Serializes a banked activity revision in the shape expected by the Activity Bank UI.
  """
  def serialize_revision(%Revision{} = revision) do
    %{
      content: revision.content,
      title: revision.title,
      objectives: revision.objectives,
      resource_id: revision.resource_id,
      activity_type_id: revision.activity_type_id,
      tags: revision.tags,
      slug: revision.slug
    }
  end

  defp parse_logic(%Logic{} = logic), do: {:ok, logic}
  defp parse_logic(logic), do: Logic.parse(logic)

  defp parse_paging(%Paging{} = paging), do: {:ok, paging}
  defp parse_paging(paging), do: Paging.parse(paging)

  defp map_value(map, key) when is_map(map) and is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end
end
