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
  alias Oli.Accounts
  alias Oli.Authoring.Course
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Authoring.Editing.BankContext
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Delivery.Sections
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
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
      execute_publication_query(publication.id, parsed_logic, parsed_paging)
    else
      error -> error
    end
  end

  @doc """
  Executes a paged Activity Bank query for an authorized delivery section preview.

  This is useful when the caller has already resolved a publication and needs to
  query against delivery section context.
  """
  def query_section_publication(
        section_slug,
        user,
        author,
        publication_id,
        %Logic{} = logic,
        %Paging{} = paging,
        opts \\ []
      ) do
    if Sections.is_instructor?(user, section_slug) or Accounts.at_least_content_admin?(author) do
      execute_publication_query(
        publication_id,
        logic,
        paging,
        Keyword.put_new(opts, :section_slug, section_slug)
      )
    else
      {:error, {:not_authorized}}
    end
  end

  @doc """
  Creates a single banked activity.
  """
  def create(project_slug, author, attrs) when is_map(attrs) do
    with {:ok, _project} <- authorize_project(project_slug, author),
         {:ok, activity_type_slug} <- resolve_activity_type_slug(attrs),
         {:ok, objective_ids} <- resolve_objective_references(project_slug, objectives(attrs)),
         {:ok, tag_ids} <- resolve_tag_references(project_slug, tags(attrs)) do
      ActivityEditor.create(
        project_slug,
        activity_type_slug,
        author,
        map_value(attrs, :model) || map_value(attrs, :content) || %{},
        objective_ids,
        "banked",
        map_value(attrs, :title),
        map_value(attrs, :objective_map) || %{},
        tag_ids
      )
    end
  end

  @doc """
  Creates multiple banked activities.
  """
  def create_bulk(project_slug, author, attrs_list) when is_list(attrs_list) do
    with {:ok, _project} <- authorize_project(project_slug, author),
         {:ok, normalized_attrs_list} <- normalize_bulk_create_attrs(project_slug, attrs_list) do
      ActivityEditor.create_bulk(project_slug, author, normalized_attrs_list, "banked")
    end
  end

  @doc """
  Resolves an activity type reference to a registered activity type slug.
  """
  def resolve_activity_type_slug(attrs) when is_map(attrs) do
    case activity_type_slug(attrs) do
      nil ->
        {:error, "Activity type is required"}

      type when is_binary(type) ->
        case Activities.get_registration_by_slug(type) do
          nil -> {:error, "Unknown activity type: #{type}"}
          registration -> {:ok, registration.slug}
        end

      type ->
        {:error, "Activity type must be a string, got: #{inspect(type)}"}
    end
  end

  @doc """
  Resolves objective titles or IDs to objective resource IDs for a project.
  """
  def resolve_objective_references(project_slug, references) do
    resolve_resource_references(
      project_slug,
      references,
      ResourceType.id_for_objective(),
      "Objective"
    )
  end

  @doc """
  Resolves tag titles or IDs to tag resource IDs for a project.
  """
  def resolve_tag_references(project_slug, references) do
    resolve_resource_references(project_slug, references, ResourceType.id_for_tag(), "Tag")
  end

  @doc """
  Updates a banked activity using the same ActivityEditor path as the UI.
  """
  def update(project_slug, author, activity_resource_id, attrs) when is_map(attrs) do
    with {:ok, _project} <- authorize_project(project_slug, author),
         {:ok, _revision} <- get_banked_activity(project_slug, activity_resource_id) do
      ActivityEditor.edit(
        project_slug,
        activity_resource_id,
        activity_resource_id,
        author.email,
        attrs
      )
    end
  end

  @doc """
  Deletes a banked activity using the same ActivityEditor path as the UI.
  """
  def delete(project_slug, author, activity_resource_id) do
    with {:ok, _project} <- authorize_project(project_slug, author),
         {:ok, _revision} <- get_banked_activity(project_slug, activity_resource_id) do
      ActivityEditor.delete(project_slug, activity_resource_id, activity_resource_id, author)
    end
  end

  @doc """
  Deletes multiple banked activities.
  """
  def delete_bulk(project_slug, author, activity_resource_ids)
      when is_list(activity_resource_ids) do
    with {:ok, _project} <- authorize_project(project_slug, author),
         {:ok, _revisions} <- get_banked_activities(project_slug, activity_resource_ids) do
      ActivityEditor.delete_bulk(project_slug, activity_resource_ids, author)
    end
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

  defp authorize_project(project_slug, author) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project) do
      {:ok, project}
    end
  end

  defp get_banked_activities(project_slug, activity_resource_ids) do
    revisions_by_resource_id =
      project_slug
      |> AuthoringResolver.from_resource_id(activity_resource_ids)
      |> Enum.reject(&is_nil/1)
      |> Map.new(fn revision -> {revision.resource_id, revision} end)

    Enum.reduce_while(activity_resource_ids, {:ok, []}, fn activity_resource_id, {:ok, acc} ->
      revision = Map.get(revisions_by_resource_id, activity_resource_id)

      case validate_banked_activity_revision(revision, activity_resource_id) do
        {:ok, revision} -> {:cont, {:ok, [revision | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, revisions} -> {:ok, Enum.reverse(revisions)}
      error -> error
    end
  end

  defp get_banked_activity(project_slug, activity_resource_id) do
    project_slug
    |> AuthoringResolver.from_resource_id(activity_resource_id)
    |> validate_banked_activity_revision(activity_resource_id)
  end

  defp validate_banked_activity_revision(revision, activity_resource_id) do
    activity_type_id = ResourceType.id_for_activity()

    case revision do
      %Revision{resource_type_id: ^activity_type_id, scope: :banked} = revision ->
        {:ok, revision}

      %Revision{resource_type_id: ^activity_type_id} ->
        {:error, "Activity resource '#{activity_resource_id}' is not banked"}

      %Revision{} ->
        {:error,
         "Activity resource '#{activity_resource_id}' does not have the expected resource type"}

      nil ->
        {:error, "Activity resource '#{activity_resource_id}' not found in project"}
    end
  end

  defp execute_publication_query(publication_id, %Logic{} = logic, %Paging{} = paging, opts \\ []) do
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

  defp normalize_bulk_create_attrs(project_slug, attrs_list) do
    Enum.reduce_while(attrs_list, {:ok, []}, fn attrs, {:ok, acc} ->
      with {:ok, normalized} <- normalize_bulk_create_attr(project_slug, attrs) do
        {:cont, {:ok, [normalized | acc]}}
      else
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  defp normalize_bulk_create_attr(project_slug, attrs) when is_map(attrs) do
    with {:ok, activity_type_slug} <- resolve_activity_type_slug(attrs),
         {:ok, objective_ids} <- resolve_objective_references(project_slug, objectives(attrs)),
         {:ok, tag_ids} <- resolve_tag_references(project_slug, tags(attrs)) do
      {:ok,
       %{
         "activityTypeSlug" => activity_type_slug,
         "objectives" => objective_ids,
         "content" => map_value(attrs, :content) || map_value(attrs, :model) || %{},
         "title" => map_value(attrs, :title),
         "tags" => tag_ids
       }}
    end
  end

  defp normalize_bulk_create_attr(_project_slug, attrs),
    do: {:error, "Bulk activity data must be a map, got: #{inspect(attrs)}"}

  defp objectives(attrs) do
    map_value(attrs, :objectives) || []
  end

  defp tags(attrs) do
    map_value(attrs, :tags) || []
  end

  defp activity_type_slug(attrs) do
    map_value(attrs, :activity_type_slug) ||
      Map.get(attrs, :activityTypeSlug) ||
      Map.get(attrs, "activityTypeSlug") ||
      map_value(attrs, :type)
  end

  defp resolve_resource_references(_project_slug, nil, _resource_type_id, _label), do: {:ok, []}
  defp resolve_resource_references(_project_slug, [], _resource_type_id, _label), do: {:ok, []}

  defp resolve_resource_references(project_slug, references, resource_type_id, label)
       when is_list(references) do
    Enum.reduce_while(references, {:ok, []}, fn reference, {:ok, acc} ->
      case resolve_resource_reference(project_slug, reference, resource_type_id, label) do
        {:ok, resource_id} -> {:cont, {:ok, [resource_id | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, resource_ids} -> {:ok, Enum.reverse(resource_ids)}
      error -> error
    end
  end

  defp resolve_resource_references(_project_slug, references, _resource_type_id, label) do
    {:error, "#{label} references must be a list, got: #{inspect(references)}"}
  end

  defp resolve_resource_reference(project_slug, resource_id, resource_type_id, label)
       when is_integer(resource_id) do
    resolve_project_resource_reference(project_slug, resource_id, resource_type_id, label)
  end

  defp resolve_resource_reference(project_slug, reference, resource_type_id, label)
       when is_binary(reference) do
    case Integer.parse(reference) do
      {resource_id, ""} ->
        resolve_project_resource_reference(project_slug, resource_id, resource_type_id, label)

      _ ->
        case AuthoringResolver.from_title(project_slug, reference, resource_type_id) do
          [revision | _] -> {:ok, revision.resource_id}
          [] -> {:error, "#{label} '#{reference}' not found in project"}
        end
    end
  end

  defp resolve_resource_reference(_project_slug, reference, _resource_type_id, label) do
    {:error, "#{label} reference must be a title or resource ID, got: #{inspect(reference)}"}
  end

  defp resolve_project_resource_reference(project_slug, resource_id, resource_type_id, label) do
    case AuthoringResolver.from_resource_id(project_slug, resource_id) do
      %Revision{resource_type_id: ^resource_type_id} ->
        {:ok, resource_id}

      %Revision{} ->
        {:error, "#{label} resource '#{resource_id}' does not have the expected resource type"}

      nil ->
        {:error, "#{label} resource '#{resource_id}' not found in project"}
    end
  end

  defp map_value(map, key) when is_map(map) and is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end
end
