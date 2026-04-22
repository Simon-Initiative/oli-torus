defmodule Oli.Authoring.Editing.AdaptiveDuplication do
  @moduledoc """
  Adaptive page duplication entry point.

  Adaptive duplication performs a deep copy of the page and all referenced
  adaptive screens, then rewires duplicated resource references inside the
  copied screen/page content before attaching the duplicated page to the
  requested container.
  """

  import Ecto.Query, warn: false

  alias Ecto.Adapters.SQL
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Broadcaster
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Publishing.ChangeTracker
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo
  alias Oli.Resources.{ResourceType, Revision}
  alias Oli.ScopedFeatureFlags
  alias Oli.Utils.Slug

  @type screen_ref :: %{
          activity_id: pos_integer(),
          sequence_id: String.t() | nil,
          sequence_name: String.t() | nil
        }

  @type duplication_result :: %{
          duplicated_resource_ids: [pos_integer()],
          duplicated_revision_ids: [pos_integer()],
          duplicated_screen_revisions: [map()],
          screen_resource_map: %{pos_integer() => pos_integer()},
          screen_revision_map: %{pos_integer() => pos_integer()}
        }

  @type page_duplication_result :: %{
          resource_id: pos_integer(),
          revision_id: pos_integer()
        }

  @type duplicate_error ::
          {:adaptive_duplication,
           :disabled
           | :invalid_author
           | :source_page_not_found
           | :not_adaptive_page
           | :missing_deck_group
           | :invalid_screen_reference
           | :missing_screen_revision
           | :invalid_screen_revision
           | :screen_resource_insert_mismatch
           | :screen_slug_generation_failed
           | :screen_revision_insert_mismatch
           | :screen_published_resource_insert_mismatch
           | :screen_revision_update_mismatch
           | :page_resource_insert_mismatch
           | :page_slug_generation_failed
           | :page_revision_insert_mismatch
           | :page_published_resource_insert_mismatch
           | :page_revision_update_mismatch
           | :page_attach_failed}

  @spec duplicate(Project.t(), pos_integer(), Keyword.t()) ::
          {:ok, Revision.t()} | {:error, duplicate_error()}
  def duplicate(%Project{} = project, adaptive_page_resource_id, opts \\ [])
      when is_integer(adaptive_page_resource_id) and is_list(opts) do
    with {:ok, %Author{} = author} <- fetch_author(opts),
         :ok <- ensure_feature_enabled(project),
         {:ok, source_page} <- fetch_source_page(project, adaptive_page_resource_id),
         {:ok, screen_refs} <- extract_adaptive_screen_refs(source_page.content),
         {:ok, source_screen_revisions} <-
           load_source_screen_revisions(project, screen_resource_ids(screen_refs)) do
      container = Keyword.get(opts, :container)

      case Repo.transaction(fn ->
             with {:ok, duplication} <-
                    duplicate_screen_resources(project, source_screen_revisions, author),
                  :ok <-
                    remap_duplicated_screen_revisions(
                      source_screen_revisions,
                      duplication.screen_revision_map,
                      duplication.screen_resource_map
                    ),
                  {:ok, duplicated_page} <- duplicate_page_resource(project, source_page, author),
                  :ok <-
                    remap_duplicated_page_revision(
                      source_page,
                      duplicated_page.revision_id,
                      duplication.screen_resource_map
                    ),
                  {:ok, duplicated_page_revision} <-
                    fetch_revision(duplicated_page.revision_id),
                  {:ok, attached_page_revision} <-
                    attach_duplicated_page(project, duplicated_page_revision, container, author) do
               attached_page_revision
             else
               {:error, reason} -> Repo.rollback(reason)
             end
           end) do
        {:ok, %Revision{} = duplicated_page_revision} ->
          maybe_broadcast_container_update(project, container)
          {:ok, duplicated_page_revision}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc false
  @spec extract_adaptive_screen_refs(map()) :: {:ok, [screen_ref()]} | {:error, duplicate_error()}
  def extract_adaptive_screen_refs(content) when is_map(content) do
    with :ok <- ensure_adaptive_page_content(content),
         {:ok, children} <- deck_children(content) do
      children
      |> Enum.reduce_while({:ok, []}, fn child, {:ok, refs} ->
        case to_screen_ref(child) do
          {:ok, nil} -> {:cont, {:ok, refs}}
          {:ok, screen_ref} -> {:cont, {:ok, refs ++ [screen_ref]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  def extract_adaptive_screen_refs(_), do: {:error, {:adaptive_duplication, :not_adaptive_page}}

  @doc false
  @spec screen_resource_ids([screen_ref()]) :: [pos_integer()]
  def screen_resource_ids(screen_refs) do
    {ids, _seen} =
      Enum.reduce(screen_refs, {[], MapSet.new()}, fn %{activity_id: activity_id}, {ids, seen} ->
        if MapSet.member?(seen, activity_id) do
          {ids, seen}
        else
          {ids ++ [activity_id], MapSet.put(seen, activity_id)}
        end
      end)

    ids
  end

  @doc false
  @spec load_source_screen_revisions(Project.t(), [pos_integer()]) ::
          {:ok, [Revision.t()]} | {:error, duplicate_error()}
  def load_source_screen_revisions(%Project{} = project, screen_resource_ids)
      when is_list(screen_resource_ids) do
    revisions = AuthoringResolver.from_resource_id(project.slug, screen_resource_ids)

    cond do
      Enum.any?(revisions, &is_nil/1) ->
        {:error, {:adaptive_duplication, :missing_screen_revision}}

      Enum.any?(revisions, &(not ResourceType.is_activity(&1))) ->
        {:error, {:adaptive_duplication, :invalid_screen_revision}}

      true ->
        {:ok, revisions}
    end
  end

  @doc false
  @spec duplicate_screen_resources(Project.t(), [Revision.t()], Author.t()) ::
          {:ok, duplication_result()} | {:error, duplicate_error()}
  def duplicate_screen_resources(
        %Project{} = project,
        source_screen_revisions,
        %Author{} = author
      )
      when is_list(source_screen_revisions) do
    count = length(source_screen_revisions)

    if count == 0 do
      {:ok,
       %{
         duplicated_resource_ids: [],
         duplicated_revision_ids: [],
         duplicated_screen_revisions: [],
         screen_resource_map: %{},
         screen_revision_map: %{}
       }}
    else
      with {:ok, duplicated_resource_ids} <-
             allocate_resource_ids(project, count, :screen_resource_insert_mismatch),
           {:ok, screen_slugs} <-
             generate_slugs(
               Enum.map(source_screen_revisions, & &1.title),
               :screen_slug_generation_failed
             ),
           {:ok, duplicated_screen_revisions} <-
             insert_revisions(
               source_screen_revisions,
               duplicated_resource_ids,
               screen_slugs,
               author.id,
               :screen_revision_insert_mismatch
             ),
           :ok <-
             insert_published_resources(
               project,
               duplicated_resource_ids,
               :screen_published_resource_insert_mismatch
             ) do
        {:ok,
         build_duplication_result(
           source_screen_revisions,
           duplicated_resource_ids,
           duplicated_screen_revisions
         )}
      end
    end
  end

  def duplicate_screen_resources(_, _, _), do: {:error, {:adaptive_duplication, :invalid_author}}

  @doc false
  @spec remap_adaptive_screen_content(map(), map()) :: map()
  def remap_adaptive_screen_content(content, screen_resource_map) when is_map(content) do
    content
    |> rewire_flowchart_destination_screen_ids(screen_resource_map)
    |> rewire_activities_required_for_evaluation(screen_resource_map)
    |> rewire_activity_references(screen_resource_map)
    |> rewire_adaptive_resource_links(screen_resource_map)
  end

  @doc false
  @spec remap_adaptive_page_content(map(), map()) :: map()
  def remap_adaptive_page_content(content, screen_resource_map) when is_map(content) do
    content
    |> rewire_activity_references(screen_resource_map)
    |> rewire_adaptive_resource_links(screen_resource_map)
  end

  defp fetch_author(opts) do
    case Keyword.get(opts, :author) do
      %Author{} = author -> {:ok, author}
      _ -> {:error, {:adaptive_duplication, :invalid_author}}
    end
  end

  defp ensure_feature_enabled(%Project{} = project) do
    if ScopedFeatureFlags.enabled?(:adaptive_duplication, project) do
      :ok
    else
      {:error, {:adaptive_duplication, :disabled}}
    end
  end

  defp fetch_source_page(%Project{} = project, adaptive_page_resource_id) do
    case AuthoringResolver.from_resource_id(project.slug, adaptive_page_resource_id) do
      %Revision{} = revision -> {:ok, revision}
      nil -> {:error, {:adaptive_duplication, :source_page_not_found}}
    end
  end

  defp ensure_adaptive_page_content(content) do
    if Map.get(content, "advancedDelivery") == true do
      :ok
    else
      {:error, {:adaptive_duplication, :not_adaptive_page}}
    end
  end

  defp deck_children(content) do
    case Map.get(content, "model", []) do
      [%{"type" => "group", "layout" => "deck", "children" => children} | _]
      when is_list(children) ->
        {:ok, children}

      _ ->
        {:error, {:adaptive_duplication, :missing_deck_group}}
    end
  end

  defp to_screen_ref(%{"type" => "activity-reference", "activity_id" => activity_id} = child)
       when is_integer(activity_id) do
    {:ok,
     %{
       activity_id: activity_id,
       sequence_id: get_in(child, ["custom", "sequenceId"]),
       sequence_name: get_in(child, ["custom", "sequenceName"])
     }}
  end

  defp to_screen_ref(%{"type" => "activity-reference"}),
    do: {:error, {:adaptive_duplication, :invalid_screen_reference}}

  defp to_screen_ref(_child), do: {:ok, nil}

  defp allocate_resource_ids(%Project{} = project, count, error_reason) do
    duplicated_resource_ids = Publishing.create_resource_batch(project, count)

    if length(duplicated_resource_ids) == count do
      {:ok, duplicated_resource_ids}
    else
      {:error, {:adaptive_duplication, error_reason}}
    end
  end

  defp generate_slugs(titles, error_reason) when is_list(titles) do
    slugs = Slug.generate("revisions", titles)

    if length(slugs) == length(titles) do
      {:ok, slugs}
    else
      {:error, {:adaptive_duplication, error_reason}}
    end
  end

  defp insert_revisions(
         source_revisions,
         duplicated_resource_ids,
         slugs,
         author_id,
         error_reason
       ) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    payload =
      Enum.zip([source_revisions, duplicated_resource_ids, slugs])
      |> Enum.map(fn {source_revision, duplicated_resource_id, slug} ->
        build_revision_row(source_revision, duplicated_resource_id, slug, author_id, now)
      end)

    case Repo.insert_all(Revision, payload, returning: [:id, :resource_id]) do
      {count, duplicated_revisions} when count == length(source_revisions) ->
        {:ok, duplicated_revisions}

      _ ->
        {:error, {:adaptive_duplication, error_reason}}
    end
  end

  defp insert_published_resources(%Project{} = project, duplicated_resource_ids, error_reason) do
    publication_id = Publishing.get_unpublished_publication_id!(project.id)

    query =
      from revision in Revision,
        where: revision.resource_id in ^duplicated_resource_ids,
        select: %{
          publication_id: ^publication_id,
          resource_id: revision.resource_id,
          revision_id: revision.id,
          inserted_at: revision.inserted_at,
          updated_at: revision.updated_at
        }

    case Repo.insert_all(PublishedResource, query) do
      {count, _} when count == length(duplicated_resource_ids) ->
        :ok

      _ ->
        {:error, {:adaptive_duplication, error_reason}}
    end
  end

  defp build_duplication_result(
         source_screen_revisions,
         duplicated_resource_ids,
         duplicated_screen_revisions
       ) do
    source_resource_ids = Enum.map(source_screen_revisions, & &1.resource_id)

    screen_resource_map =
      Enum.zip(source_resource_ids, duplicated_resource_ids)
      |> Enum.into(%{})

    screen_revision_map =
      Enum.zip(source_resource_ids, duplicated_screen_revisions)
      |> Enum.into(%{}, fn {source_resource_id, duplicated_revision} ->
        {source_resource_id, duplicated_revision.id}
      end)

    %{
      duplicated_resource_ids: duplicated_resource_ids,
      duplicated_revision_ids: Enum.map(duplicated_screen_revisions, & &1.id),
      duplicated_screen_revisions: duplicated_screen_revisions,
      screen_resource_map: screen_resource_map,
      screen_revision_map: screen_revision_map
    }
  end

  defp remap_duplicated_screen_revisions(
         source_screen_revisions,
         screen_revision_map,
         screen_resource_map
       ) do
    updates =
      Enum.reduce(source_screen_revisions, [], fn source_revision, updates ->
        remapped_content =
          remap_adaptive_screen_content(source_revision.content || %{}, screen_resource_map)

        case remapped_content == source_revision.content do
          true ->
            updates

          false ->
            [
              %{
                revision_id: Map.fetch!(screen_revision_map, source_revision.resource_id),
                content: remapped_content
              }
              | updates
            ]
        end
      end)
      |> Enum.reverse()

    bulk_update_revision_contents(updates, :screen_revision_update_mismatch)
  end

  defp duplicate_page_resource(
         %Project{} = project,
         %Revision{} = source_page,
         %Author{} = author
       ) do
    duplicated_title = "#{source_page.title} (copy)"

    with {:ok, [duplicated_page_resource_id]} <-
           allocate_resource_ids(project, 1, :page_resource_insert_mismatch),
         {:ok, [page_slug]} <- generate_slugs([duplicated_title], :page_slug_generation_failed),
         {:ok, [%{id: duplicated_page_revision_id}]} <-
           insert_revisions(
             [Map.put(source_page, :title, duplicated_title)],
             [duplicated_page_resource_id],
             [page_slug],
             author.id,
             :page_revision_insert_mismatch
           ),
         :ok <-
           insert_published_resources(
             project,
             [duplicated_page_resource_id],
             :page_published_resource_insert_mismatch
           ) do
      {:ok, %{resource_id: duplicated_page_resource_id, revision_id: duplicated_page_revision_id}}
    end
  end

  defp remap_duplicated_page_revision(
         %Revision{} = source_page,
         duplicated_page_revision_id,
         screen_resource_map
       ) do
    remapped_content =
      remap_adaptive_page_content(source_page.content || %{}, screen_resource_map)

    bulk_update_revision_contents(
      [%{revision_id: duplicated_page_revision_id, content: remapped_content}],
      :page_revision_update_mismatch
    )
  end

  defp attach_duplicated_page(_project, duplicated_page_revision, nil, _author),
    do: {:ok, duplicated_page_revision}

  defp attach_duplicated_page(
         %Project{} = project,
         %Revision{} = duplicated_page_revision,
         %Revision{} = container,
         %Author{} = author
       ) do
    append = %{
      children: container.children ++ [duplicated_page_revision.resource_id],
      author_id: author.id
    }

    with {:ok, _updated_container} <-
           ChangeTracker.track_revision(project.slug, container, append),
         {:ok, restored_page_revision} <-
           maybe_restore_deleted_revision(project.slug, duplicated_page_revision, author) do
      {:ok, restored_page_revision}
    else
      _ -> {:error, {:adaptive_duplication, :page_attach_failed}}
    end
  end

  defp maybe_restore_deleted_revision(project_slug, duplicated_page_revision, author) do
    case duplicated_page_revision.deleted do
      true ->
        ChangeTracker.track_revision(project_slug, duplicated_page_revision, %{
          deleted: false,
          author_id: author.id
        })

      _ ->
        {:ok, duplicated_page_revision}
    end
  end

  defp fetch_revision(revision_id) when is_integer(revision_id) do
    case Repo.get(Revision, revision_id) do
      %Revision{} = revision -> {:ok, revision}
      nil -> {:error, {:adaptive_duplication, :page_revision_insert_mismatch}}
    end
  end

  defp maybe_broadcast_container_update(%Project{} = project, %Revision{} = container) do
    updated_container = AuthoringResolver.from_resource_id(project.slug, container.resource_id)
    Broadcaster.broadcast_revision(updated_container, project.slug)
  end

  defp maybe_broadcast_container_update(_project, _container), do: :ok

  defp bulk_update_revision_contents([], _error_reason), do: :ok

  defp bulk_update_revision_contents(update_rows, error_reason) do
    revision_ids = Enum.map(update_rows, & &1.revision_id)
    encoded_contents = Enum.map(update_rows, &Jason.encode!(&1.content))

    sql = """
    UPDATE revisions AS revision
    SET content = updates.content::jsonb,
        updated_at = timezone('UTC', now())
    FROM (
      SELECT
        unnest($1::bigint[]) AS revision_id,
        unnest($2::text[]) AS content
    ) AS updates
    WHERE revision.id = updates.revision_id
    """

    case SQL.query(Repo, sql, [revision_ids, encoded_contents]) do
      {:ok, %{num_rows: count}} when count == length(update_rows) ->
        :ok

      _ ->
        {:error, {:adaptive_duplication, error_reason}}
    end
  end

  defp rewire_flowchart_destination_screen_ids(content, screen_resource_map) do
    update_nested_map(content, "authoring", fn authoring ->
      update_nested_map(authoring, "flowchart", fn flowchart ->
        Map.update(flowchart, "paths", [], fn
          paths when is_list(paths) ->
            Enum.map(paths, fn
              %{"destinationScreenId" => destination_screen_id} = path ->
                Map.put(
                  path,
                  "destinationScreenId",
                  mapped_resource_id(screen_resource_map, destination_screen_id) ||
                    destination_screen_id
                )

              other ->
                other
            end)

          other ->
            other
        end)
      end)
    end)
  end

  defp rewire_activities_required_for_evaluation(content, screen_resource_map) do
    update_nested_map(content, "authoring", fn authoring ->
      Map.update(authoring, "activitiesRequiredForEvaluation", [], fn
        activity_ids when is_list(activity_ids) ->
          Enum.map(activity_ids, fn activity_id ->
            mapped_resource_id(screen_resource_map, activity_id) || activity_id
          end)

        other ->
          other
      end)
    end)
  end

  defp rewire_activity_references(content, screen_resource_map) do
    deep_rewrite(content, fn
      %{"type" => "activity-reference", "activity_id" => activity_id} = reference ->
        case mapped_resource_id(screen_resource_map, activity_id) do
          nil -> reference
          mapped_id -> Map.put(reference, "activity_id", mapped_id)
        end

      other ->
        other
    end)
  end

  defp rewire_adaptive_resource_links(content, screen_resource_map) do
    deep_rewrite(content, fn
      %{"tag" => "a", "idref" => idref} = link ->
        case mapped_resource_id(screen_resource_map, idref) do
          nil -> link
          mapped_id -> Map.put(link, "idref", mapped_id)
        end

      %{"type" => "janus-capi-iframe"} = iframe ->
        rewire_iframe_resource_reference(iframe, screen_resource_map)

      other ->
        other
    end)
  end

  defp rewire_iframe_resource_reference(iframe, screen_resource_map) do
    current_resource_id = Map.get(iframe, "resource_id") || Map.get(iframe, "idref")

    case mapped_resource_id(screen_resource_map, current_resource_id) do
      nil ->
        iframe

      mapped_id ->
        iframe
        |> Map.put("idref", mapped_id)
        |> Map.put("resource_id", mapped_id)
    end
  end

  defp mapped_resource_id(resource_id_map, key) do
    case Map.get(resource_id_map, key) do
      nil ->
        case key do
          integer when is_integer(integer) ->
            Map.get(resource_id_map, Integer.to_string(integer))

          binary when is_binary(binary) ->
            case Integer.parse(binary) do
              {integer, ""} -> Map.get(resource_id_map, integer)
              _ -> nil
            end

          _ ->
            nil
        end

      mapped ->
        mapped
    end
  end

  defp build_revision_row(source_revision, duplicated_resource_id, slug, author_id, now) do
    %{
      title: source_revision.title,
      slug: slug,
      deleted: source_revision.deleted,
      ids_added: source_revision.ids_added,
      author_id: author_id,
      resource_id: duplicated_resource_id,
      previous_revision_id: nil,
      resource_type_id: source_revision.resource_type_id,
      content: source_revision.content,
      children: source_revision.children,
      tags: source_revision.tags,
      activity_refs: source_revision.activity_refs,
      objectives: source_revision.objectives,
      graded: source_revision.graded,
      ai_enabled: source_revision.ai_enabled,
      batch_scoring: source_revision.batch_scoring,
      replacement_strategy: source_revision.replacement_strategy,
      duration_minutes: source_revision.duration_minutes,
      intro_content: source_revision.intro_content,
      intro_video: source_revision.intro_video,
      poster_image: source_revision.poster_image,
      full_progress_pct: source_revision.full_progress_pct,
      max_attempts: source_revision.max_attempts,
      recommended_attempts: source_revision.recommended_attempts,
      time_limit: source_revision.time_limit,
      scope: source_revision.scope,
      resource_scope: source_revision.resource_scope,
      retake_mode: source_revision.retake_mode,
      assessment_mode: source_revision.assessment_mode,
      parameters: source_revision.parameters,
      legacy: embed_to_map(source_revision.legacy),
      explanation_strategy: embed_to_map(source_revision.explanation_strategy),
      collab_space_config: embed_to_map(source_revision.collab_space_config),
      scoring_strategy_id: source_revision.scoring_strategy_id,
      activity_type_id: source_revision.activity_type_id,
      primary_resource_id: source_revision.primary_resource_id,
      purpose: source_revision.purpose,
      relates_to: source_revision.relates_to,
      inserted_at: now,
      updated_at: now
    }
  end

  defp embed_to_map(nil), do: nil
  defp embed_to_map(embed) when is_struct(embed), do: Map.from_struct(embed)
  defp embed_to_map(embed) when is_map(embed), do: embed

  defp update_nested_map(map, key, updater) when is_map(map) do
    case Map.fetch(map, key) do
      {:ok, value} -> Map.put(map, key, updater.(value))
      :error -> map
    end
  end

  defp deep_rewrite(value, rewrite_fun) when is_list(value) do
    value
    |> Enum.map(&deep_rewrite(&1, rewrite_fun))
    |> rewrite_fun.()
  end

  defp deep_rewrite(%{} = value, rewrite_fun) do
    value
    |> Enum.into(%{}, fn {key, child} -> {key, deep_rewrite(child, rewrite_fun)} end)
    |> rewrite_fun.()
  end

  defp deep_rewrite(value, rewrite_fun), do: rewrite_fun.(value)
end
