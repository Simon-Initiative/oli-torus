defmodule Oli.Analytics.Summary.BrowseInsights do
  @moduledoc """
  Descriptive authoring analytics over ResourceSummary data.

  These relative-difficulty metrics intentionally remain independent of the
  Section-selected proficiency model; they describe authored content rather
  than learner-facing proficiency and are excluded from provider migration.
  """
  alias Oli.Activities
  alias Oli.Publishing.Publications.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Analytics.Summary.BrowseInsightsOptions
  alias Oli.Analytics.Summary.EventualCorrectness
  alias Oli.Analytics.Summary.ResourceSummary
  alias Oli.Resources.{ResourceType, Revision}
  alias Oli.Repo.{Paging, Sorting}
  import Ecto.Query, warn: false
  alias Oli.Repo

  defp get_relative_difficulty_parameters() do
    alpha = Application.get_env(:oli, :relative_difficulty_alpha, 0.5)
    beta = Application.get_env(:oli, :relative_difficulty_beta, 0.3)
    gamma = Application.get_env(:oli, :relative_difficulty_gamma, 0.2)

    {alpha, beta, gamma}
  end

  defp adaptive_activity_type_id do
    case Activities.get_registration_by_slug("oli_adaptive") do
      %{id: id} -> id
      nil -> nil
    end
  end

  @doc """
  Retrieves descriptive insights, deriving eventual correctness from learner
  summaries while retaining submission-based counts and relative difficulty.

  Counts use aggregate summaries only. Ordinary sorts select the
  requested page before loading its learner metrics; eventual-correctness sorts
  rank all matching resources once and place unavailable rates last.
  """
  def browse_insights(
        %Paging{} = paging,
        %Sorting{} = sorting,
        %BrowseInsightsOptions{
          project_id: project_id,
          text_search: text_search
        } = options
      ) do
    adaptive_activity_type_id = adaptive_activity_type_id()
    where_by = build_where_by(options)

    text_search_condition =
      if text_search && text_search != "",
        do: dynamic([_s, _pub, _pr, rev], ilike(rev.title, ^"%#{text_search}%")),
        else: true

    query =
      ResourceSummary
      |> join(:left, [s], pub in Publication, on: pub.project_id == ^project_id)
      |> join(:left, [s, pub], pr in PublishedResource, on: pr.publication_id == pub.id)
      |> join(:left, [s, pub, pr], rev in Revision, on: rev.id == pr.revision_id)
      |> where(^where_by)
      |> where(^text_search_condition)

    case activity_resource_type?(options.resource_type_id) do
      true ->
        browse_activity_insights(query, paging, sorting, adaptive_activity_type_id, options)

      false ->
        browse_non_activity_insights(query, paging, sorting, options)
    end
  end

  defp join_eventual_correctness(query, options, resource_ids) do
    join(
      query,
      :left,
      [s],
      ec in subquery(
        EventualCorrectness.counts_query(
          options.project_id,
          options.section_ids,
          options.resource_type_id,
          resource_ids: resource_ids,
          part_id: options.part_id
        )
      ),
      as: :eventual_correctness,
      on:
        ec.resource_id == s.resource_id and ec.resource_type_id == s.resource_type_id and
          ec.section_id == s.section_id and
          fragment("? IS NOT DISTINCT FROM ?", ec.part_id, s.part_id)
    )
  end

  defp build_where_by(%BrowseInsightsOptions{} = options) do
    options
    |> section_filter()
    |> maybe_filter_resource(options.resource_id)
    |> maybe_filter_part(options.part_id)
  end

  defp section_filter(%BrowseInsightsOptions{
         project_id: project_id,
         resource_type_id: resource_type_id,
         section_ids: []
       }) do
    dynamic(
      [s, pub, pr, _],
      s.project_id == ^project_id and
        s.resource_id == pr.resource_id and
        is_nil(pub.published) and
        s.resource_type_id == ^resource_type_id and
        s.section_id == -1 and
        s.user_id == -1
    )
  end

  defp section_filter(%BrowseInsightsOptions{
         resource_type_id: resource_type_id,
         section_ids: section_ids
       }) do
    dynamic(
      [s, pub, pr, _],
      s.project_id == -1 and s.resource_id == pr.resource_id and
        is_nil(pub.published) and
        s.resource_type_id == ^resource_type_id and
        s.section_id in ^section_ids and
        s.user_id == -1
    )
  end

  defp maybe_filter_resource(where_by, nil), do: where_by

  defp maybe_filter_resource(where_by, resource_id),
    do: dynamic([s, _pub, _pr, _rev], ^where_by and s.resource_id == ^resource_id)

  defp maybe_filter_part(where_by, nil), do: where_by

  defp maybe_filter_part(where_by, part_id),
    do: dynamic([s, _pub, _pr, _rev], ^where_by and s.part_id == ^part_id)

  defmacro safe_div_fragment(numerator, denominator) do
    quote do
      fragment(
        "?::float8 / NULLIF(?::float8, 0::float8)",
        unquote(numerator),
        unquote(denominator)
      )
    end
  end

  # SUM ignores NULLs, so explicitly reject partially available rollups.
  defmacrop complete_rate_fragment(correct, attempted) do
    quote do
      fragment(
        "CASE WHEN count(?) = count(*) THEN sum(?)::float8 / NULLIF(sum(?)::float8, 0) END",
        unquote(attempted),
        unquote(correct),
        unquote(attempted)
      )
    end
  end

  defmacrop adaptive_group_part(activity_type_id, part_id, adaptive_activity_type_id) do
    quote do
      fragment(
        "CASE WHEN ? = ? THEN NULL ELSE ? END",
        unquote(activity_type_id),
        unquote(adaptive_activity_type_id),
        unquote(part_id)
      )
    end
  end

  defp activity_resource_type?(resource_type_id) do
    resource_type_id == ResourceType.id_for_activity()
  end

  defp browse_activity_insights(
         query,
         %Paging{limit: limit, offset: offset},
         %Sorting{} = sorting,
         adaptive_activity_type_id,
         options
       ) do
    include_eventual? = sorting.field == :eventually_correct

    query =
      case include_eventual? do
        true ->
          candidates = query |> select([s], s.resource_id) |> distinct(true)
          join_eventual_correctness(query, options, candidates)

        false ->
          query
      end

    rows =
      query
      |> add_activity_row_select(adaptive_activity_type_id, include_eventual?)
      |> aggregate_activity_rows()
      |> select_aggregated_activity_rows()
      |> add_aggregated_activity_order_by(sorting)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    case include_eventual? do
      true -> rows
      false -> add_eventual_correctness(rows, options, adaptive_activity_type_id)
    end
  end

  defp browse_non_activity_insights(query, paging, sorting, options) do
    query =
      case objective_resource_type?(options) do
        true -> where(query, [_, _, _, rev], rev.deleted == false or is_nil(rev.deleted))
        false -> query
      end

    # Counting never needs learner or historical-attempt data.
    total_count = get_total_count(query, options)

    case {total_count, sorting.field} do
      {0, _} ->
        []

      {_, :eventually_correct} ->
        browse_by_eventual_correctness(query, paging, sorting, options, total_count)

      _ ->
        query
        |> add_non_activity_select(total_count, options)
        |> add_non_activity_order_by(sorting, options)
        |> limit(^paging.limit)
        |> offset(^paging.offset)
        |> Repo.all()
        |> add_eventual_correctness(options)
    end
  end

  # Ordinary sorts choose their page using only existing aggregate counters.
  # Fetch historical membership once, bounded to the returned resource IDs.
  defp add_eventual_correctness(rows, options, adaptive_activity_type_id \\ nil)
  defp add_eventual_correctness([], _options, _adaptive_activity_type_id), do: []

  defp add_eventual_correctness(rows, options, adaptive_activity_type_id) do
    resource_ids = rows |> Enum.map(& &1.resource_id) |> Enum.uniq()

    counts_by_resource =
      EventualCorrectness.counts_query(
        options.project_id,
        options.section_ids,
        options.resource_type_id,
        resource_ids: resource_ids,
        part_id: options.part_id
      )
      |> Repo.all()
      |> Enum.group_by(& &1.resource_id)

    Enum.map(rows, fn row ->
      counts = Map.get(counts_by_resource, row.resource_id, [])

      counts =
        case row.activity_type_id do
          id when not is_nil(id) and id == adaptive_activity_type_id -> counts
          _ -> Enum.filter(counts, &(&1.part_id == row.part_id))
        end

      rate = counts |> Enum.map(&{&1.num_correct, &1.num_attempted}) |> EventualCorrectness.rate()
      Map.put(row, :eventually_correct, rate)
    end)
  end

  defp eventual_sort_direction(:asc), do: :asc_nulls_last
  defp eventual_sort_direction(:desc), do: :desc_nulls_last

  # Sorting by a derived rate must rank every matching resource. Compute just
  # resource IDs and rates in one ranking query; fetch display rows only for
  # the selected page. Candidate IDs apply text/deletion/resource filters before
  # historical membership is read, and no count query repeats that read.
  defp browse_by_eventual_correctness(query, paging, sorting, options, total_count) do
    candidates = query |> select([s], s.resource_id) |> distinct(true)

    ranked =
      query
      |> join_eventual_correctness(options, candidates)
      |> group_by([s], [s.resource_id, s.part_id])
      |> select([s, eventual_correctness: ec], %{
        resource_id: s.resource_id,
        part_id: s.part_id,
        eventually_correct: complete_rate_fragment(ec.num_correct, ec.num_attempted)
      })

    direction = eventual_sort_direction(sorting.direction)

    ranked_page =
      from(row in subquery(ranked),
        order_by: [
          {^direction, row.eventually_correct},
          {:asc, row.resource_id},
          {:asc, row.part_id}
        ],
        limit: ^paging.limit,
        offset: ^paging.offset
      )
      |> Repo.all()

    case ranked_page do
      [] ->
        []

      _ ->
        ids = Enum.map(ranked_page, & &1.resource_id)

        display_rows =
          query
          |> where([s], s.resource_id in ^ids)
          |> add_non_activity_select(total_count, options)
          |> Repo.all()
          |> Map.new(&{{&1.resource_id, &1.part_id}, &1})

        Enum.map(ranked_page, fn row ->
          display_rows
          |> Map.fetch!({row.resource_id, row.part_id})
          |> Map.put(:eventually_correct, row.eventually_correct)
        end)
    end
  end

  defp add_activity_row_select(query, adaptive_activity_type_id, include_eventual?) do
    query =
      select(query, [s, pub, pr, rev], %{
        title: rev.title,
        resource_id: s.resource_id,
        slug: rev.slug,
        part_id: adaptive_group_part(rev.activity_type_id, s.part_id, ^adaptive_activity_type_id),
        pub_id: pub.id,
        activity_type_id: rev.activity_type_id,
        pr_rev: pr.revision_id,
        pr_resource: pr.resource_id,
        num_correct: s.num_correct,
        num_attempts: s.num_attempts,
        num_hints: s.num_hints,
        num_first_attempts: s.num_first_attempts,
        num_first_attempts_correct: s.num_first_attempts_correct
      })

    case include_eventual? do
      true ->
        select_merge(query, [eventual_correctness: ec], %{
          num_eventually_correct: ec.num_correct,
          num_eventually_attempted: ec.num_attempted
        })

      false ->
        select_merge(query, %{
          num_eventually_correct: fragment("NULL::bigint"),
          num_eventually_attempted: fragment("NULL::bigint")
        })
    end
  end

  defp aggregate_activity_rows(query) do
    {alpha, beta, gamma} = get_relative_difficulty_parameters()

    from(row in subquery(query),
      group_by: [
        row.title,
        row.resource_id,
        row.slug,
        row.part_id,
        row.pub_id,
        row.activity_type_id,
        row.pr_rev,
        row.pr_resource
      ],
      select: %{
        title: row.title,
        resource_id: row.resource_id,
        slug: row.slug,
        part_id: row.part_id,
        pub_id: row.pub_id,
        activity_type_id: row.activity_type_id,
        pr_rev: row.pr_rev,
        pr_resource: row.pr_resource,
        num_correct: sum(row.num_correct),
        num_attempts: sum(row.num_attempts),
        num_hints: sum(row.num_hints),
        num_first_attempts: sum(row.num_first_attempts),
        num_first_attempts_correct: sum(row.num_first_attempts_correct),
        eventually_correct:
          complete_rate_fragment(row.num_eventually_correct, row.num_eventually_attempted),
        first_attempt_correct:
          safe_div_fragment(sum(row.num_first_attempts_correct), sum(row.num_first_attempts)),
        relative_difficulty:
          fragment(
            "?::float8 * (1.0 - (?::float8)) + ?::float8 * (1.0 - (?::float8)) + ?::float8 * (?::float8)",
            ^alpha,
            safe_div_fragment(sum(row.num_first_attempts_correct), sum(row.num_first_attempts)),
            ^beta,
            safe_div_fragment(sum(row.num_correct), sum(row.num_attempts)),
            ^gamma,
            sum(row.num_hints)
          )
      }
    )
  end

  defp select_aggregated_activity_rows(query) do
    from(row in subquery(query),
      select: %{
        id: fragment("gen_random_uuid()::text"),
        total_count: fragment("count(*) OVER()"),
        title: row.title,
        resource_id: row.resource_id,
        slug: row.slug,
        part_id: row.part_id,
        pub_id: row.pub_id,
        activity_type_id: row.activity_type_id,
        pr_rev: row.pr_rev,
        pr_resource: row.pr_resource,
        num_correct: row.num_correct,
        num_attempts: row.num_attempts,
        num_hints: row.num_hints,
        num_first_attempts: row.num_first_attempts,
        num_first_attempts_correct: row.num_first_attempts_correct,
        eventually_correct: row.eventually_correct,
        first_attempt_correct: row.first_attempt_correct,
        relative_difficulty: row.relative_difficulty
      }
    )
  end

  defp add_aggregated_activity_order_by(
         query,
         %Sorting{direction: direction, field: field}
       ) do
    query =
      case field do
        :title ->
          order_by(query, [row], {^direction, row.title})

        :part_id ->
          order_by(query, [row], {^direction, row.part_id})

        :num_attempts ->
          order_by(query, [row], {^direction, row.num_attempts})

        :num_first_attempts ->
          order_by(query, [row], {^direction, row.num_first_attempts})

        :eventually_correct ->
          nulls_last = eventual_sort_direction(direction)
          order_by(query, [row], {^nulls_last, row.eventually_correct})

        :first_attempt_correct ->
          order_by(query, [row], {^direction, row.first_attempt_correct})

        :relative_difficulty ->
          order_by(query, [row], {^direction, row.relative_difficulty})

        _ ->
          order_by(query, [row], {^direction, field(row, ^field)})
      end

    query
    |> order_by([row], asc: row.resource_id)
    |> order_by([row], asc_nulls_last: row.part_id)
  end

  defp add_non_activity_select(
         query,
         total_count,
         %BrowseInsightsOptions{section_ids: section_ids}
       ) do
    {alpha, beta, gamma} = get_relative_difficulty_parameters()

    case section_ids do
      [] ->
        query
        |> select([s, pub, pr, rev], %{
          id: s.id,
          total_count: fragment("?::int", ^total_count),
          title: rev.title,
          deleted: rev.deleted,
          resource_id: s.resource_id,
          slug: rev.slug,
          part_id: s.part_id,
          pub_id: pub.id,
          activity_type_id: rev.activity_type_id,
          pr_rev: pr.revision_id,
          pr_resource: pr.resource_id,
          num_correct: s.num_correct,
          num_attempts: s.num_attempts,
          num_hints: s.num_hints,
          num_first_attempts: s.num_first_attempts,
          num_first_attempts_correct: s.num_first_attempts_correct,
          eventually_correct: nil,
          first_attempt_correct:
            safe_div_fragment(s.num_first_attempts_correct, s.num_first_attempts),
          relative_difficulty:
            fragment(
              "?::float8 * (1.0 - ?::float8) + ?::float8 * (1.0 - ?::float8) + ?::float8 * ?::float8",
              ^alpha,
              safe_div_fragment(s.num_first_attempts_correct, s.num_first_attempts),
              ^beta,
              safe_div_fragment(s.num_correct, s.num_attempts),
              ^gamma,
              s.num_hints
            )
        })

      _section_ids ->
        query
        |> group_by([s, _, _, rev], [
          s.resource_id,
          s.part_id,
          rev.title,
          rev.deleted,
          rev.slug,
          rev.activity_type_id
        ])
        |> select([s, _, _, rev], %{
          id: fragment("gen_random_uuid()::text"),
          total_count: fragment("?::int", ^total_count),
          resource_id: s.resource_id,
          title: rev.title,
          deleted: rev.deleted,
          slug: rev.slug,
          part_id: s.part_id,
          activity_type_id: rev.activity_type_id,
          num_correct: sum(s.num_correct),
          num_attempts: sum(s.num_attempts),
          num_hints: sum(s.num_hints),
          num_first_attempts: sum(s.num_first_attempts),
          num_first_attempts_correct: sum(s.num_first_attempts_correct),
          eventually_correct: nil,
          first_attempt_correct:
            safe_div_fragment(sum(s.num_first_attempts_correct), sum(s.num_first_attempts)),
          relative_difficulty:
            fragment(
              "?::float8 * (1.0 - (?::float8)) + ?::float8 * (1.0 - (?::float8)) + ?::float8 * (?::float8)",
              ^alpha,
              safe_div_fragment(sum(s.num_first_attempts_correct), sum(s.num_first_attempts)),
              ^beta,
              safe_div_fragment(sum(s.num_correct), sum(s.num_attempts)),
              ^gamma,
              sum(s.num_hints)
            )
        })
    end
  end

  defp add_non_activity_order_by(
         query,
         %Sorting{direction: direction, field: field},
         %BrowseInsightsOptions{section_ids: []}
       ) do
    {alpha, beta, gamma} = get_relative_difficulty_parameters()

    query =
      case field do
        :title ->
          order_by(query, [_, _, _, rev], {^direction, rev.title})

        :part_id ->
          order_by(query, [s], {^direction, s.part_id})

        :num_attempts ->
          order_by(query, [s], {^direction, s.num_attempts})

        :num_first_attempts ->
          order_by(query, [s], {^direction, s.num_first_attempts})

        :first_attempt_correct ->
          order_by(
            query,
            [s],
            {^direction, safe_div_fragment(s.num_first_attempts_correct, s.num_first_attempts)}
          )

        :relative_difficulty ->
          order_by(
            query,
            [s],
            {^direction,
             fragment(
               "?::float8 * (1.0 - ?::float8) + ?::float8 * (1.0 - ?::float8) + ?::float8 * ?::float8",
               ^alpha,
               safe_div_fragment(s.num_first_attempts_correct, s.num_first_attempts),
               ^beta,
               safe_div_fragment(s.num_correct, s.num_attempts),
               ^gamma,
               s.num_hints
             )}
          )

        _ ->
          order_by(query, [_, _, _, rev], {^direction, field(rev, ^field)})
      end

    # Ensure there is always a stable sort order based on id
    order_by(query, [s], s.resource_id)
  end

  defp add_non_activity_order_by(
         query,
         %Sorting{direction: direction, field: field},
         %BrowseInsightsOptions{section_ids: _}
       ) do
    {alpha, beta, gamma} = get_relative_difficulty_parameters()

    query =
      case field do
        :title ->
          order_by(query, [_, _, _, rev], {^direction, rev.title})

        :part_id ->
          order_by(query, [s], {^direction, s.part_id})

        :num_attempts ->
          order_by(query, [s], {^direction, sum(s.num_attempts)})

        :num_first_attempts ->
          order_by(query, [s], {^direction, sum(s.num_first_attempts)})

        :first_attempt_correct ->
          order_by(
            query,
            [s],
            {^direction,
             safe_div_fragment(sum(s.num_first_attempts_correct), sum(s.num_first_attempts))}
          )

        :relative_difficulty ->
          order_by(
            query,
            [s],
            {^direction,
             fragment(
               "?::float8 * (1.0 - (?::float8)) + ?::float8 * (1.0 - (?::float8)) + ?::float8 * (?::float8)",
               ^alpha,
               safe_div_fragment(sum(s.num_first_attempts_correct), sum(s.num_first_attempts)),
               ^beta,
               safe_div_fragment(sum(s.num_correct), sum(s.num_attempts)),
               ^gamma,
               sum(s.num_hints)
             )}
          )

        _ ->
          order_by(query, [_, _, _, rev], {^direction, field(rev, ^field)})
      end

    # Ensure there is always a stable sort order based on id
    order_by(query, [s], s.resource_id)
  end

  defp get_total_count(query, options) do
    total_count_query =
      query
      |> add_non_activity_group_by_for_count(options)
      |> select(fragment("count(*) OVER() as total_count"))
      |> limit(1)

    Repo.one(total_count_query)
    |> case do
      nil -> 0
      count -> count
    end
  end

  defp add_non_activity_group_by_for_count(
         query,
         %BrowseInsightsOptions{section_ids: section_ids}
       ) do
    case section_ids do
      [] -> query
      _section_ids -> query |> group_by([s, _, _, _], [s.resource_id, s.part_id])
    end
  end

  defp objective_resource_type?(%BrowseInsightsOptions{resource_type_id: resource_type_id}) do
    resource_type_id == ResourceType.get_id_by_type("objective")
  end
end
