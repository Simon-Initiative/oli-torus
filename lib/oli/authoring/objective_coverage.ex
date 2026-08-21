defmodule Oli.Authoring.ObjectiveCoverage do
  @moduledoc """
  Builds a read-only snapshot of the learning-objective coverage data for an
  authoring project's working publication.

  The snapshot is intentionally request-scoped. It is built from a compact
  projection and does not load page or activity content, create a process, or
  mutate authoring data. Coverage calculations and consumer-specific views are
  layered on top of this index in later iterations.
  """

  import Ecto.Query, warn: false

  alias Oli.Authoring.Course.Project
  alias Oli.Publishing.Publications.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Resources.ResourceType

  @telemetry_prefix [:oli, :authoring, :objective_coverage]

  @type row :: %{
          required(:project_id) => pos_integer(),
          required(:publication_id) => pos_integer(),
          required(:revision_id) => pos_integer(),
          required(:resource_id) => pos_integer(),
          required(:resource_type_id) => pos_integer(),
          optional(:slug) => String.t() | nil,
          optional(:title) => String.t() | nil,
          optional(:deleted) => boolean(),
          optional(:objectives) => map() | nil,
          optional(:children) => list() | nil,
          optional(:graded) => boolean() | nil,
          optional(:activity_refs) => list() | nil,
          optional(:scope) => atom() | String.t() | nil,
          optional(:activity_type_id) => pos_integer() | nil
        }

  @type t :: %{
          project_id: pos_integer() | nil,
          publication_id: pos_integer() | nil,
          rows_by_type: %{pos_integer() => [row()]},
          objectives_by_id: %{pos_integer() => map()},
          parents_by_child: %{pos_integer() => [pos_integer()]},
          children_by_parent: %{pos_integer() => [pos_integer()]},
          objective_scope_by_id: %{pos_integer() => [pos_integer()]},
          pages_by_id: %{pos_integer() => map()},
          activities_by_id: %{pos_integer() => map()},
          curriculum_by_id: %{pos_integer() => map()},
          curriculum_parents_by_child: %{pos_integer() => [pos_integer()]},
          curriculum_children_by_parent: %{pos_integer() => [pos_integer()]},
          curriculum_descendants_by_id: %{pos_integer() => [pos_integer()]},
          curriculum_paths_by_id: %{pos_integer() => [[pos_integer()]]},
          top_level_objective_ids: [pos_integer()],
          direct_page_ids_by_objective: %{pos_integer() => [pos_integer()]},
          activity_ids_by_objective: %{pos_integer() => %{atom() => [pos_integer()]}},
          coverage_by_objective: %{pos_integer() => map()},
          details_by_objective: %{pos_integer() => %{atom() => [map()]}},
          search_by_objective: %{pos_integer() => map()}
        }

  @projection_types [
    ResourceType.id_for_objective(),
    ResourceType.id_for_page(),
    ResourceType.id_for_activity(),
    ResourceType.id_for_container()
  ]

  @doc """
  Loads the compact working-publication projection for a project slug or
  project struct and builds its in-memory indexes.

  An existing project with an empty working publication returns an empty
  snapshot with project and publication context. Missing projects and working
  publications return tagged errors. Invalid project arguments return an error
  before querying the database.
  """
  @spec load(Project.t() | %{required(:id) => pos_integer()} | String.t()) ::
          {:ok, t()}
          | {:error,
             :invalid_project
             | :project_not_found
             | :working_publication_not_found
             | :multiple_working_publications}
  def load(project_or_slug) do
    started_at = System.monotonic_time()

    try do
      result =
        with {:ok, query} <- projection_query(project_or_slug) do
          rows = Repo.all(query)
          context = context_from_rows(rows)

          case {context[:project_id], context[:publication_ids]} do
            {nil, _publication_id} ->
              {:error, :project_not_found}

            {_project_id, []} ->
              {:error, :working_publication_not_found}

            {_project_id, [_publication_id, _other_publication_id | _]} ->
              {:error, :multiple_working_publications}

            {_project_id, [publication_id]} ->
              build_context = %{project_id: context.project_id, publication_id: publication_id}
              {:ok, build(Enum.filter(rows, &is_integer(&1.resource_id)), build_context)}
          end
        end

      emit_load(result, project_or_slug, started_at)
      result
    rescue
      exception ->
        safe_telemetry_execute(
          @telemetry_prefix ++ [:load, :exception],
          %{count: 1},
          project_metadata(project_or_slug) |> Map.put(:exception, exception.__struct__)
        )

        reraise(exception, __STACKTRACE__)
    end
  end

  @doc "Returns the single compact Ecto projection used by `load/1`."
  @spec projection_query(Project.t() | %{required(:id) => pos_integer()} | String.t()) ::
          {:ok, Ecto.Query.t()} | {:error, :invalid_project}
  def projection_query(%Project{id: project_id}), do: projection_query_by_id(project_id)

  def projection_query(%{id: project_id}) when is_integer(project_id),
    do: projection_query_by_id(project_id)

  def projection_query(project_slug) when is_binary(project_slug) do
    {:ok,
     base_projection_query()
     |> where([project, _pub, _mapping, _revision], project.slug == ^project_slug)}
  end

  def projection_query(_), do: {:error, :invalid_project}

  @doc """
  Builds indexes from compact projection rows. This function is public so the
  transformation can be tested without a database.
  """
  @spec build([map()], map()) :: t()
  def build(rows, context \\ %{}) when is_list(rows) do
    started_at = System.monotonic_time()

    normalized_rows =
      rows
      |> Enum.map(&normalize_row/1)
      |> Enum.sort_by(&{&1.resource_type_id, &1.resource_id})

    rows_by_type = Enum.group_by(normalized_rows, & &1.resource_type_id)

    objectives = Map.get(rows_by_type, ResourceType.id_for_objective(), [])
    pages = Map.get(rows_by_type, ResourceType.id_for_page(), [])
    activities = Map.get(rows_by_type, ResourceType.id_for_activity(), [])
    containers = Map.get(rows_by_type, ResourceType.id_for_container(), [])

    objectives_by_id = Map.new(objectives, &{&1.resource_id, objective_summary(&1)})
    children_by_parent = children_by_parent(objectives)
    parents_by_child = parents_by_child(children_by_parent)
    objective_scope_by_id = objective_scopes_by_id(objectives_by_id, children_by_parent)
    pages_by_id = Map.new(pages, &{&1.resource_id, page_summary(&1)})
    activities_by_id = Map.new(activities, &{&1.resource_id, activity_summary(&1)})
    direct_page_ids_by_objective = direct_page_ids_by_objective(pages)
    activity_occurrences = activity_occurrences_by_objective(pages, activities_by_id)
    activity_ids_by_objective = activity_ids_by_objective(activity_occurrences)

    coverage_by_objective =
      coverage_by_objective(
        objectives_by_id,
        objective_scope_by_id,
        children_by_parent,
        direct_page_ids_by_objective,
        activity_ids_by_objective
      )

    details_by_objective =
      details_by_objective(
        objectives_by_id,
        objective_scope_by_id,
        direct_page_ids_by_objective,
        activity_occurrences,
        pages_by_id,
        activities_by_id
      )

    search_by_objective =
      search_by_objective(
        objectives_by_id,
        objective_scope_by_id,
        details_by_objective
      )

    curriculum_by_id = Map.new(containers ++ pages, &{&1.resource_id, curriculum_summary(&1)})
    curriculum_children_by_parent = curriculum_children_by_parent(curriculum_by_id)
    curriculum_parents_by_child = parents_by_child(curriculum_children_by_parent)

    model = %{
      project_id: context[:project_id] || first_value(normalized_rows, :project_id),
      publication_id: context[:publication_id] || first_value(normalized_rows, :publication_id),
      rows_by_type: rows_by_type,
      objectives_by_id: objectives_by_id,
      parents_by_child: parents_by_child,
      children_by_parent: children_by_parent,
      objective_scope_by_id: objective_scope_by_id,
      pages_by_id: pages_by_id,
      activities_by_id: activities_by_id,
      curriculum_by_id: curriculum_by_id,
      curriculum_parents_by_child: curriculum_parents_by_child,
      curriculum_children_by_parent: curriculum_children_by_parent,
      curriculum_descendants_by_id:
        curriculum_descendants_by_id(curriculum_by_id, curriculum_children_by_parent),
      curriculum_paths_by_id:
        curriculum_paths_by_id(curriculum_by_id, curriculum_parents_by_child),
      top_level_objective_ids: top_level_objective_ids(objectives_by_id, parents_by_child),
      direct_page_ids_by_objective: direct_page_ids_by_objective,
      activity_ids_by_objective: activity_ids_by_objective,
      coverage_by_objective: coverage_by_objective,
      details_by_objective: details_by_objective,
      search_by_objective: search_by_objective
    }

    emit_build(model, length(normalized_rows), started_at)
    model
  end

  @doc "Returns the top-level objectives in stable title/id order."
  @spec objectives(t()) :: [map()]
  def objectives(model) do
    Enum.map(model.top_level_objective_ids, &Map.fetch!(model.objectives_by_id, &1))
  end

  @doc "Returns coverage counts for an objective, or `nil` when it is unknown."
  @spec coverage(t(), pos_integer()) :: map() | nil
  def coverage(model, objective_id), do: Map.get(model.coverage_by_objective, objective_id)

  @doc "Returns page-first detail groups for an objective and assessment bucket."
  @spec details(t(), pos_integer(), atom() | String.t()) :: [map()]
  def details(model, objective_id, bucket) do
    bucket = normalize_bucket(bucket)
    get_in(model.details_by_objective, [objective_id, bucket]) || []
  end

  @doc "Returns in-memory partial-search results for objective coverage."
  @spec search(t(), String.t()) :: [map()]
  def search(model, query) when is_binary(query) do
    normalized_query = normalize_search_text(query)

    if normalized_query == "" do
      []
    else
      model.search_by_objective
      |> Enum.flat_map(fn {objective_id, projection} ->
        matches =
          Enum.filter(projection.matches, fn match ->
            String.contains?(match.normalized_title, normalized_query)
          end)

        if matches == [] do
          []
        else
          [
            %{
              objective_id: objective_id,
              matches: Enum.map(matches, &Map.delete(&1, :normalized_title))
            }
          ]
        end
      end)
      |> Enum.sort_by(fn result ->
        objective = Map.fetch!(model.objectives_by_id, result.objective_id)
        {normalize_search_text(objective.title), result.objective_id}
      end)
    end
  end

  @doc "Returns page ids below selected curriculum nodes."
  @spec curriculum_pages(t(), [pos_integer()]) :: [pos_integer()]
  def curriculum_pages(model, selected_ids) do
    selected_ids
    |> normalize_ids()
    |> Enum.flat_map(fn resource_id ->
      [resource_id | Map.get(model.curriculum_descendants_by_id, resource_id, [])]
    end)
    |> Enum.filter(&Map.has_key?(model.pages_by_id, &1))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp base_projection_query do
    from project in Project,
      left_join: pub in Publication,
      on: pub.project_id == project.id and is_nil(pub.published),
      left_join: mapping in PublishedResource,
      on: mapping.publication_id == pub.id,
      left_join: revision in Revision,
      on:
        revision.id == mapping.revision_id and
          revision.resource_id == mapping.resource_id and
          revision.deleted == false and
          revision.resource_type_id in ^@projection_types,
      select: %{
        project_id: project.id,
        publication_id: pub.id,
        revision_id: revision.id,
        resource_id: revision.resource_id,
        resource_type_id: revision.resource_type_id,
        slug: revision.slug,
        title: revision.title,
        deleted: revision.deleted,
        objectives: revision.objectives,
        children: revision.children,
        graded: revision.graded,
        activity_refs: revision.activity_refs,
        scope: revision.scope,
        activity_type_id: revision.activity_type_id
      }
  end

  defp projection_query_by_id(project_id) do
    {:ok,
     base_projection_query()
     |> where([project, _pub, _mapping, _revision], project.id == ^project_id)}
  end

  defp context_from_rows(rows) when is_list(rows) do
    %{
      project_id: first_value(rows, :project_id),
      publication_ids:
        rows
        |> Enum.map(&Map.get(&1, :publication_id))
        |> Enum.filter(&is_integer/1)
        |> Enum.uniq()
        |> Enum.sort()
    }
  end

  defp normalize_row(row) do
    %{
      project_id: Map.get(row, :project_id),
      publication_id: Map.get(row, :publication_id),
      revision_id: Map.get(row, :revision_id),
      resource_id: Map.get(row, :resource_id),
      resource_type_id: Map.get(row, :resource_type_id),
      slug: Map.get(row, :slug),
      title: Map.get(row, :title),
      deleted: Map.get(row, :deleted, false) == true,
      objectives: normalize_map(Map.get(row, :objectives)),
      children: normalize_ids(Map.get(row, :children)),
      graded: Map.get(row, :graded, false) == true,
      activity_refs: normalize_ids(Map.get(row, :activity_refs)),
      scope: Map.get(row, :scope),
      activity_type_id: Map.get(row, :activity_type_id)
    }
  end

  defp objective_summary(row) do
    Map.take(row, [:resource_id, :revision_id, :slug, :title, :children, :objectives])
  end

  defp page_summary(row) do
    Map.take(row, [
      :resource_id,
      :revision_id,
      :slug,
      :title,
      :children,
      :objectives,
      :graded,
      :activity_refs
    ])
  end

  defp activity_summary(row) do
    Map.take(row, [
      :resource_id,
      :revision_id,
      :slug,
      :title,
      :objectives,
      :scope,
      :activity_type_id
    ])
  end

  defp curriculum_summary(row) do
    Map.take(row, [:resource_id, :revision_id, :slug, :title, :children])
  end

  defp direct_page_ids_by_objective(pages) do
    pages
    |> Enum.reduce(%{}, fn page, acc ->
      Enum.reduce(objective_ids(page.objectives), acc, fn objective_id, acc ->
        Map.update(acc, objective_id, MapSet.new([page.resource_id]), fn page_ids ->
          MapSet.put(page_ids, page.resource_id)
        end)
      end)
    end)
    |> Map.new(fn {objective_id, page_ids} ->
      {objective_id, page_ids |> MapSet.to_list() |> Enum.sort()}
    end)
  end

  defp activity_occurrences_by_objective(pages, activities_by_id) do
    Enum.reduce(pages, %{}, fn page, acc ->
      bucket = assessment_bucket(page.graded)

      Enum.reduce(page.activity_refs, acc, fn activity_id, acc ->
        case Map.get(activities_by_id, activity_id) do
          %{scope: scope, objectives: objectives} when scope in [:embedded, "embedded"] ->
            Enum.reduce(objective_ids(objectives), acc, fn objective_id, acc ->
              objective_occurrences = Map.get(acc, objective_id, %{})
              bucket_occurrences = Map.get(objective_occurrences, bucket, %{})

              bucket_occurrences =
                Map.update(
                  bucket_occurrences,
                  page.resource_id,
                  MapSet.new([activity_id]),
                  fn activity_ids ->
                    MapSet.put(activity_ids, activity_id)
                  end
                )

              Map.put(
                acc,
                objective_id,
                Map.put(objective_occurrences, bucket, bucket_occurrences)
              )
            end)

          _ ->
            acc
        end
      end)
    end)
    |> normalize_activity_occurrences()
  end

  defp normalize_activity_occurrences(activity_occurrences) do
    Map.new(activity_occurrences, fn {objective_id, by_bucket} ->
      {objective_id,
       Map.new(by_bucket, fn {bucket, by_page} ->
         {bucket,
          Map.new(by_page, fn {page_id, activity_ids} ->
            {page_id, activity_ids |> MapSet.to_list() |> Enum.sort()}
          end)}
       end)}
    end)
  end

  defp activity_ids_by_objective(activity_occurrences) do
    Map.new(activity_occurrences, fn {objective_id, by_bucket} ->
      {objective_id,
       Map.new(by_bucket, fn {bucket, by_page} ->
         {bucket, by_page |> Map.values() |> List.flatten() |> Enum.uniq() |> Enum.sort()}
       end)}
    end)
  end

  defp coverage_by_objective(
         objectives_by_id,
         objective_scope_by_id,
         children_by_parent,
         direct_page_ids_by_objective,
         activity_ids_by_objective
       ) do
    Map.new(objectives_by_id, fn {objective_id, _objective} ->
      related_ids = Map.fetch!(objective_scope_by_id, objective_id)

      page_count =
        related_ids
        |> Enum.flat_map(&Map.get(direct_page_ids_by_objective, &1, []))
        |> Enum.uniq()
        |> length()

      activity_counts =
        Enum.reduce([:formative, :summative], %{}, fn bucket, acc ->
          count =
            related_ids
            |> Enum.flat_map(&(get_in(activity_ids_by_objective, [&1, bucket]) || []))
            |> Enum.uniq()
            |> length()

          Map.put(acc, bucket, count)
        end)

      {objective_id,
       %{
         page_count: page_count,
         formative_activity_count: activity_counts.formative,
         summative_activity_count: activity_counts.summative,
         sub_objective_count: length(Map.get(children_by_parent, objective_id, []))
       }}
    end)
  end

  defp details_by_objective(
         objectives_by_id,
         objective_scope_by_id,
         direct_page_ids_by_objective,
         activity_occurrences,
         pages_by_id,
         activities_by_id
       ) do
    Map.new(objectives_by_id, fn {objective_id, _objective} ->
      related_ids = Map.fetch!(objective_scope_by_id, objective_id)

      direct_page_ids =
        related_ids
        |> Enum.flat_map(&Map.get(direct_page_ids_by_objective, &1, []))
        |> MapSet.new()

      activity_pages =
        related_ids
        |> Enum.flat_map(fn related_id ->
          activity_occurrences
          |> Map.get(related_id, %{})
          |> Enum.flat_map(fn {_bucket, by_page} -> Map.keys(by_page) end)
        end)
        |> MapSet.new()

      page_ids = MapSet.union(direct_page_ids, activity_pages)

      buckets =
        Map.new([:formative, :summative], fn bucket ->
          groups =
            page_ids
            |> MapSet.to_list()
            |> Enum.sort()
            |> Enum.flat_map(fn page_id ->
              case Map.get(pages_by_id, page_id) do
                nil ->
                  []

                page ->
                  activity_ids =
                    related_ids
                    |> Enum.flat_map(fn related_id ->
                      get_in(activity_occurrences, [related_id, bucket, page_id]) || []
                    end)
                    |> Enum.uniq()
                    |> Enum.sort()

                  activities = Enum.map(activity_ids, &Map.fetch!(activities_by_id, &1))

                  if assessment_bucket(page.graded) == bucket or activity_ids != [] do
                    [%{page: page, activities: activities}]
                  else
                    []
                  end
              end
            end)

          {bucket, groups}
        end)

      {objective_id, buckets}
    end)
  end

  defp search_by_objective(objectives_by_id, objective_scope_by_id, details_by_objective) do
    Map.new(objectives_by_id, fn {objective_id, _objective} ->
      related_ids =
        Map.fetch!(objective_scope_by_id, objective_id)
        |> Enum.filter(&Map.has_key?(objectives_by_id, &1))

      objective_matches =
        related_ids
        |> Enum.map(fn related_id ->
          related_objective = Map.fetch!(objectives_by_id, related_id)

          %{
            type: if(related_id == objective_id, do: :objective, else: :sub_objective),
            resource_id: related_id,
            title: related_objective.title,
            normalized_title: normalize_search_text(related_objective.title)
          }
        end)

      detail_matches =
        details_by_objective
        |> Map.get(objective_id, %{})
        |> Map.values()
        |> List.flatten()
        |> Enum.flat_map(fn %{page: page, activities: activities} ->
          [
            %{
              type: :page,
              resource_id: page.resource_id,
              title: page.title,
              normalized_title: normalize_search_text(page.title)
            }
          ] ++
            Enum.map(activities, fn activity ->
              %{
                type: :activity,
                resource_id: activity.resource_id,
                title: activity.title,
                normalized_title: normalize_search_text(activity.title)
              }
            end)
        end)

      matches =
        (objective_matches ++ detail_matches)
        |> Enum.reject(&(&1.normalized_title == ""))
        |> Enum.uniq_by(&{&1.type, &1.resource_id})

      {objective_id,
       %{
         text: matches |> Enum.map(& &1.title) |> Enum.join(" ") |> normalize_search_text(),
         matches: matches
       }}
    end)
  end

  defp top_level_objective_ids(objectives_by_id, parents_by_child) do
    objectives_by_id
    |> Map.keys()
    |> Enum.reject(&Map.has_key?(parents_by_child, &1))
    |> Enum.sort_by(fn objective_id ->
      objective = Map.fetch!(objectives_by_id, objective_id)
      {normalize_search_text(objective.title), objective_id}
    end)
  end

  defp objective_scopes_by_id(objectives_by_id, children_by_parent) do
    {scopes_by_id, _memo} =
      Enum.reduce(Map.keys(objectives_by_id), {%{}, %{}}, fn objective_id, {scopes, memo} ->
        {scope, memo, _cyclic?} =
          objective_scope_ids(objective_id, children_by_parent, memo, MapSet.new())

        {Map.put(scopes, objective_id, scope), memo}
      end)

    scopes_by_id
  end

  defp objective_scope_ids(objective_id, children_by_parent, memo, visiting) do
    cond do
      Map.has_key?(memo, objective_id) ->
        {Map.fetch!(memo, objective_id), memo, false}

      MapSet.member?(visiting, objective_id) ->
        {[objective_id], memo, true}

      true ->
        visiting = MapSet.put(visiting, objective_id)

        {child_scopes, memo, cyclic?} =
          Enum.reduce(
            Map.get(children_by_parent, objective_id, []),
            {[], memo, false},
            fn child_id, {scopes, memo, cyclic?} ->
              {scope, memo, child_cyclic?} =
                objective_scope_ids(child_id, children_by_parent, memo, visiting)

              {[scope | scopes], memo, cyclic? or child_cyclic?}
            end
          )

        scope =
          [objective_id | List.flatten(child_scopes)]
          |> Enum.uniq()
          |> Enum.sort()

        memo = if cyclic?, do: memo, else: Map.put(memo, objective_id, scope)
        {scope, memo, cyclic?}
    end
  end

  defp curriculum_children_by_parent(curriculum_by_id) do
    Map.new(curriculum_by_id, fn {resource_id, node} ->
      children =
        node.children
        |> Enum.filter(&Map.has_key?(curriculum_by_id, &1))
        |> Enum.sort()

      {resource_id, children}
    end)
  end

  defp curriculum_descendants_by_id(curriculum_by_id, children_by_parent) do
    {descendants_by_id, _memo} =
      Enum.reduce(Map.keys(curriculum_by_id), {%{}, %{}}, fn resource_id, {descendants, memo} ->
        {scope, memo, _cyclic?} =
          curriculum_scope_ids(resource_id, children_by_parent, memo, MapSet.new())

        {Map.put(descendants, resource_id, List.delete(scope, resource_id)), memo}
      end)

    descendants_by_id
  end

  defp curriculum_scope_ids(resource_id, children_by_parent, memo, visiting) do
    cond do
      Map.has_key?(memo, resource_id) ->
        {Map.fetch!(memo, resource_id), memo, false}

      MapSet.member?(visiting, resource_id) ->
        {[resource_id], memo, true}

      true ->
        visiting = MapSet.put(visiting, resource_id)

        {child_scopes, memo, cyclic?} =
          Enum.reduce(
            Map.get(children_by_parent, resource_id, []),
            {[], memo, false},
            fn child_id, {scopes, memo, cyclic?} ->
              {scope, memo, child_cyclic?} =
                curriculum_scope_ids(child_id, children_by_parent, memo, visiting)

              {[scope | scopes], memo, cyclic? or child_cyclic?}
            end
          )

        scope =
          [resource_id | List.flatten(child_scopes)]
          |> Enum.uniq()
          |> Enum.sort()

        memo = if cyclic?, do: memo, else: Map.put(memo, resource_id, scope)
        {scope, memo, cyclic?}
    end
  end

  defp curriculum_paths_by_id(curriculum_by_id, parents_by_child) do
    {paths_by_id, _memo} =
      Enum.reduce(Map.keys(curriculum_by_id), {%{}, %{}}, fn resource_id, {paths_by_id, memo} ->
        {reverse_paths, memo, _cyclic?} =
          curriculum_reverse_paths(resource_id, parents_by_child, memo, MapSet.new())

        node_paths =
          reverse_paths
          |> Enum.map(&Enum.reverse/1)
          |> Enum.sort()

        {Map.put(paths_by_id, resource_id, node_paths), memo}
      end)

    paths_by_id
  end

  defp curriculum_reverse_paths(resource_id, parents_by_child, memo, visiting) do
    cond do
      Map.has_key?(memo, resource_id) ->
        {Map.fetch!(memo, resource_id), memo, false}

      MapSet.member?(visiting, resource_id) ->
        {[[]], memo, true}

      true ->
        visiting = MapSet.put(visiting, resource_id)
        parent_ids = Map.get(parents_by_child, resource_id, [])

        {parent_paths, memo, cyclic?} =
          Enum.reduce(parent_ids, {[], memo, false}, fn parent_id, {paths, memo, cyclic?} ->
            {parent_paths, memo, parent_cyclic?} =
              curriculum_reverse_paths(parent_id, parents_by_child, memo, visiting)

            {Enum.map(parent_paths, &[resource_id | &1]) ++ paths, memo,
             cyclic? or parent_cyclic?}
          end)

        reverse_paths = if parent_ids == [], do: [[resource_id]], else: parent_paths
        memo = if cyclic?, do: memo, else: Map.put(memo, resource_id, reverse_paths)
        {reverse_paths, memo, cyclic?}
    end
  end

  defp objective_ids(objectives) when is_map(objectives) do
    objectives
    |> Map.values()
    |> Enum.flat_map(&List.wrap/1)
    |> Enum.filter(&is_integer/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp objective_ids(_), do: []

  defp assessment_bucket(true), do: :summative
  defp assessment_bucket(_), do: :formative

  defp normalize_bucket(:formative), do: :formative
  defp normalize_bucket(:summative), do: :summative
  defp normalize_bucket("formative"), do: :formative
  defp normalize_bucket("summative"), do: :summative
  defp normalize_bucket(_), do: :formative

  defp normalize_search_text(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  defp normalize_search_text(_), do: ""

  defp emit_load(result, project_or_slug, started_at) do
    {status, model} =
      case result do
        {:ok, model} -> {:completed, model}
        {:error, reason} -> {reason, nil}
      end

    metadata =
      project_metadata(project_or_slug)
      |> Map.merge(model_metadata(model))
      |> Map.put(:status, status)

    safe_telemetry_execute(
      @telemetry_prefix ++ [:load, :stop],
      %{count: 1, duration_ms: duration_ms(started_at)},
      metadata
    )
  end

  defp emit_build(model, row_count, started_at) do
    resource_counts =
      model.rows_by_type
      |> Enum.map(fn {resource_type_id, rows} ->
        {Integer.to_string(resource_type_id), length(rows)}
      end)
      |> Map.new()

    safe_telemetry_execute(
      @telemetry_prefix ++ [:build, :stop],
      %{count: 1, duration_ms: duration_ms(started_at), row_count: row_count},
      %{
        project_id: model.project_id,
        publication_id: model.publication_id,
        resource_counts: resource_counts
      }
    )
  end

  defp model_metadata(nil), do: %{project_id: nil, publication_id: nil, row_count: 0}

  defp model_metadata(model) do
    %{
      project_id: model.project_id,
      publication_id: model.publication_id,
      row_count: model.rows_by_type |> Map.values() |> Enum.map(&length/1) |> Enum.sum(),
      objective_count: map_size(model.objectives_by_id),
      page_count: map_size(model.pages_by_id),
      activity_count: map_size(model.activities_by_id)
    }
  end

  defp project_metadata(%Project{id: project_id, slug: project_slug}),
    do: %{project_id: project_id, project_slug: project_slug}

  defp project_metadata(%{id: project_id}), do: %{project_id: project_id}

  defp project_metadata(project_slug) when is_binary(project_slug),
    do: %{project_slug: project_slug}

  defp project_metadata(_), do: %{}

  defp safe_telemetry_execute(event, measurements, metadata) do
    :telemetry.execute(event, measurements, metadata)
  rescue
    _ -> :ok
  end

  defp duration_ms(started_at) do
    System.monotonic_time()
    |> Kernel.-(started_at)
    |> System.convert_time_unit(:native, :millisecond)
  end

  defp children_by_parent(objectives) do
    objectives
    |> Enum.reduce(%{}, fn row, acc -> Map.put(acc, row.resource_id, row.children) end)
    |> Map.new(fn {parent_id, children} -> {parent_id, Enum.sort(children)} end)
  end

  defp parents_by_child(children_by_parent) do
    Enum.reduce(children_by_parent, %{}, fn {parent_id, children}, acc ->
      Enum.reduce(children, acc, fn child_id, acc ->
        Map.update(acc, child_id, [parent_id], fn parents -> Enum.sort([parent_id | parents]) end)
      end)
    end)
  end

  defp normalize_map(value) when is_map(value), do: value
  defp normalize_map(_), do: %{}

  defp normalize_ids(value) when is_list(value),
    do: value |> Enum.filter(&is_integer/1) |> Enum.uniq() |> Enum.sort()

  defp normalize_ids(_), do: []

  defp first_value([row | _], key), do: Map.get(row, key)
  defp first_value([], _key), do: nil
end
