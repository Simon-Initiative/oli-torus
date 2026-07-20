defmodule Oli.Authoring.ProjectRepair.Analysis do
  @moduledoc """
  Implements bounded, read-only analysis for the project repair tool.

  The database cursor yields one current page revision at a time. Full page JSON is
  used only to classify that row and extract nested activity references; it is never
  placed in the accumulator or returned report. The retained state is therefore
  limited to compact page metadata and the two relationship maps required to detect
  missing and cross-page shared activity resources.

  This module is an internal domain service. Callers should use
  `Oli.Authoring.ProjectRepair.analyze_project/3`, which applies authorization and
  project/publication normalization before entering this analysis path.
  """

  import Ecto.Query, warn: false

  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Editing.Utils

  alias Oli.Authoring.ProjectRepair.{
    MissingActivityReference,
    PageSummary,
    Report,
    SharedActivityReference,
    Summary
  }

  alias Oli.Publishing.AuthoringResolver
  alias Oli.Publishing.PublishedResource
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Resources.{ResourceType, Revision}

  @typedoc "Validated controls for database cursor and resolver batch sizes."
  @type options :: %{
          stream_max_rows: pos_integer(),
          resolution_batch_size: pos_integer(),
          preview_issue_limit: pos_integer() | nil,
          preview_group_page_limit: pos_integer() | nil
        }

  @type error :: {:invalid_page_content, pos_integer()}

  @doc """
  Streams and classifies the current unpublished pages for one normalized project.

  The returned report is sorted by numeric resource identifiers and contains no
  authored content. A malformed page fails the complete analysis with its resource
  id; returning a partial report would make a subsequent repair preview unsafe.
  """
  @spec analyze(Project.t(), Publication.t(), options()) ::
          {:ok, Report.t()} | {:error, error()}
  def analyze(
        %Project{} = project,
        %Publication{} = publication,
        %{
          stream_max_rows: stream_max_rows,
          resolution_batch_size: resolution_batch_size
        } = options
      ) do
    with {:ok, relationships} <- stream_relationships(publication.id, stream_max_rows) do
      resolved_activity_ids =
        resolve_activity_ids(
          project.slug,
          Map.keys(relationships.activity_to_pages),
          resolution_batch_size
        )

      {:ok, build_report(project, relationships, resolved_activity_ids, options)}
    end
  end

  # The query is tied directly to the already-normalized working publication id.
  # Joining its mappings to their selected revisions avoids historical revisions,
  # while the type, deleted, and project-scope predicates exclude non-current or
  # non-project page rows before any JSON reaches the application process.
  defp page_stream_query(publication_id) do
    page_type_id = ResourceType.id_for_page()

    from(mapping in PublishedResource,
      join: revision in Revision,
      on:
        revision.id == mapping.revision_id and
          revision.resource_id == mapping.resource_id,
      where:
        mapping.publication_id == ^publication_id and
          revision.resource_type_id == ^page_type_id and
          revision.deleted == false and
          revision.resource_scope == :project,
      order_by: [asc: revision.resource_id],
      select: %{
        revision_id: revision.id,
        resource_id: revision.resource_id,
        revision_slug: revision.slug,
        title: revision.title,
        content: revision.content
      }
    )
  end

  defp stream_relationships(publication_id, stream_max_rows) do
    initial = %{
      pages: %{},
      page_to_activities: %{},
      activity_to_pages: %{},
      scanned_pages_count: 0,
      skipped_adaptive_pages_count: 0
    }

    # PostgreSQL cursors are valid only inside a transaction. `max_rows` bounds
    # each fetch, and `Enum.reduce_while/3` ensures malformed content stops the
    # cursor immediately instead of producing a deceptively incomplete report.
    transaction_result =
      Repo.transaction(fn ->
        publication_id
        |> page_stream_query()
        |> Repo.stream(max_rows: stream_max_rows)
        |> Enum.reduce_while({:ok, initial}, fn page, {:ok, acc} ->
          reduce_page(page, acc)
        end)
      end)

    case transaction_result do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end

  # Adaptive exclusion is absolute: once the top-level boolean is true, this row
  # contributes only to the skipped count. Its page id, metadata, and nested
  # activity ids never enter either relationship map and cannot become repair work.
  defp reduce_page(%{content: content} = page, acc) do
    case basic_page?(content) do
      false ->
        {:cont, {:ok, Map.update!(acc, :skipped_adaptive_pages_count, fn count -> count + 1 end)}}

      true ->
        case activity_references(content, page.resource_id) do
          {:ok, activity_ids} ->
            summary = page_summary(page)

            # `Utils.activity_references/1` returns a MapSet, so duplicate nodes
            # within one page become one relationship. Keeping both map directions
            # makes missing reporting and shared-cardinality checks straightforward
            # without retaining the page's full content payload.
            activity_to_pages =
              Enum.reduce(activity_ids, acc.activity_to_pages, fn activity_id, inverted ->
                Map.update(
                  inverted,
                  activity_id,
                  MapSet.new([page.resource_id]),
                  &MapSet.put(&1, page.resource_id)
                )
              end)

            {:cont,
             {:ok,
              %{
                acc
                | pages: Map.put(acc.pages, page.resource_id, summary),
                  page_to_activities:
                    Map.put(acc.page_to_activities, page.resource_id, activity_ids),
                  activity_to_pages: activity_to_pages,
                  scanned_pages_count: acc.scanned_pages_count + 1
              }}}

          {:error, _reason} = error ->
            {:halt, error}
        end
    end
  end

  @doc """
  Returns whether page content belongs to the Basic authoring format.

  This predicate is shared by analysis and repair-time validation. Missing and
  boolean false values are Basic; only the exact top-level boolean true is Adaptive.
  Nested flags and truthy strings intentionally do not exclude a page.
  """
  @spec basic_page?(map()) :: boolean()
  def basic_page?(%{"advancedDelivery" => true}), do: false
  def basic_page?(_content), do: true

  defp activity_references(%{"model" => model} = content, page_resource_id)
       when is_list(model) do
    try do
      activity_ids = Utils.activity_references(content)

      # Resolver queries require persisted resource ids. Treat a missing, string,
      # zero, or otherwise malformed `activity_id` as page-content corruption here
      # so it cannot escape later as an Ecto cast exception during batched lookup.
      case Enum.all?(activity_ids, &(is_integer(&1) and &1 > 0)) do
        true -> {:ok, activity_ids}
        false -> {:error, {:invalid_page_content, page_resource_id}}
      end
    rescue
      # Existing traversal deliberately expects valid page nodes. Normalize any
      # traversal shape failure to a content-free page-scoped error rather than
      # exposing an exception or silently treating the page as reference-free.
      _exception -> {:error, {:invalid_page_content, page_resource_id}}
    end
  end

  defp activity_references(_content, page_resource_id),
    do: {:error, {:invalid_page_content, page_resource_id}}

  defp page_summary(page) do
    %PageSummary{
      resource_id: page.resource_id,
      revision_id: page.revision_id,
      revision_slug: page.revision_slug,
      title: page.title
    }
  end

  defp resolve_activity_ids(_project_slug, [], _batch_size), do: MapSet.new()

  defp resolve_activity_ids(project_slug, activity_ids, batch_size) do
    activity_ids
    |> Enum.sort()
    |> Enum.chunk_every(batch_size)
    |> Enum.reduce(MapSet.new(), fn activity_id_batch, resolved_ids ->
      # The resolver's activity-id projection executes one parameterized query for
      # the chunk and selects no revision JSON. Besides avoiding a relationship N+1,
      # this type-checks clone candidates and prevents large activity bodies from
      # replacing the page stream's bounded-memory win.
      project_slug
      |> AuthoringResolver.existing_activity_resource_ids(activity_id_batch)
      |> Enum.reduce(resolved_ids, &MapSet.put(&2, &1))
    end)
  end

  defp build_report(project, relationships, resolved_activity_ids, options) do
    issue_limit = Map.get(options, :preview_issue_limit)
    group_page_limit = Map.get(options, :preview_group_page_limit)

    missing_activity_references =
      build_missing_activity_references(relationships, resolved_activity_ids, issue_limit)

    shared_activity_references =
      build_shared_activity_references(
        relationships,
        resolved_activity_ids,
        issue_limit,
        group_page_limit
      )

    summary = build_summary(relationships, resolved_activity_ids)

    %Report{
      project_id: project.id,
      project_slug: project.slug,
      scanned_pages_count: relationships.scanned_pages_count,
      skipped_adaptive_pages_count: relationships.skipped_adaptive_pages_count,
      missing_activity_references: missing_activity_references,
      shared_activity_references: shared_activity_references,
      summary: summary
    }
  end

  defp build_missing_activity_references(relationships, resolved_activity_ids, limit) do
    relationships.page_to_activities
    |> Enum.flat_map(fn {page_resource_id, activity_ids} ->
      page = Map.fetch!(relationships.pages, page_resource_id)

      activity_ids
      |> MapSet.difference(resolved_activity_ids)
      |> Enum.map(fn activity_resource_id ->
        %MissingActivityReference{
          activity_resource_id: activity_resource_id,
          page: page
        }
      end)
    end)
    |> Enum.sort_by(fn missing -> {missing.page.resource_id, missing.activity_resource_id} end)
    |> maybe_take(limit)
  end

  defp build_shared_activity_references(
         relationships,
         resolved_activity_ids,
         issue_limit,
         group_page_limit
       ) do
    relationships.activity_to_pages
    |> Enum.filter(fn {_activity_resource_id, page_ids} -> MapSet.size(page_ids) > 1 end)
    |> Enum.map(fn {activity_resource_id, page_ids} ->
      pages =
        page_ids
        |> Enum.map(&Map.fetch!(relationships.pages, &1))
        |> Enum.sort_by(& &1.resource_id)

      %SharedActivityReference{
        activity_resource_id: activity_resource_id,
        pages: maybe_take(pages, group_page_limit),
        page_count: length(pages),
        repairable?: MapSet.member?(resolved_activity_ids, activity_resource_id)
      }
    end)
    |> Enum.sort_by(& &1.activity_resource_id)
    |> maybe_take(issue_limit)
  end

  defp build_summary(relationships, resolved_activity_ids) do
    {missing_count, missing_page_ids} =
      Enum.reduce(relationships.page_to_activities, {0, MapSet.new()}, fn {page_resource_id,
                                                                           activity_ids},
                                                                          {count, page_ids} ->
        missing_activity_ids = MapSet.difference(activity_ids, resolved_activity_ids)
        missing_activity_count = MapSet.size(missing_activity_ids)

        page_ids =
          case missing_activity_count > 0 do
            true -> MapSet.put(page_ids, page_resource_id)
            false -> page_ids
          end

        {count + missing_activity_count, page_ids}
      end)

    shared_groups =
      relationships.activity_to_pages
      |> Enum.filter(fn {_activity_resource_id, page_ids} -> MapSet.size(page_ids) > 1 end)

    # A page involved in several shared groups is one affected page. Counting a
    # union here keeps the UI's page cardinality distinct from its resource-group
    # cardinality and prevents inflated preview totals.
    {repairable_shared_count, repairable_shared_page_ids, non_repairable_shared_count} =
      Enum.reduce(shared_groups, {0, MapSet.new(), 0}, fn {activity_resource_id, page_ids},
                                                          {repairable_count, affected_pages,
                                                           non_repairable_count} ->
        case MapSet.member?(resolved_activity_ids, activity_resource_id) do
          true ->
            {
              repairable_count + 1,
              MapSet.union(affected_pages, page_ids),
              non_repairable_count
            }

          false ->
            {repairable_count, affected_pages, non_repairable_count + 1}
        end
      end)

    %Summary{
      scanned_pages_count: relationships.scanned_pages_count,
      skipped_adaptive_pages_count: relationships.skipped_adaptive_pages_count,
      missing_activity_reference_count: missing_count,
      missing_activity_affected_page_count: MapSet.size(missing_page_ids),
      repairable_shared_activity_resource_count: repairable_shared_count,
      repairable_shared_activity_affected_page_count: MapSet.size(repairable_shared_page_ids),
      non_repairable_shared_missing_activity_resource_count: non_repairable_shared_count
    }
  end

  defp maybe_take(items, nil), do: items
  defp maybe_take(items, limit), do: Enum.take(items, limit)
end
