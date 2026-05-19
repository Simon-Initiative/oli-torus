defmodule Oli.Analytics.Summary.BrowseInsights do
  alias Oli.Activities
  alias Oli.Publishing.Publications.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Analytics.Summary.BrowseInsightsOptions
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
        browse_activity_insights(query, paging, sorting, adaptive_activity_type_id)

      false ->
        browse_non_activity_insights(query, paging, sorting, options)
    end
  end

  defp build_where_by(%BrowseInsightsOptions{
         project_id: project_id,
         resource_type_id: resource_type_id,
         section_ids: section_ids
       }) do
    case section_ids do
      [] ->
        dynamic(
          [s, pub, pr, _],
          s.project_id == ^project_id and
            s.resource_id == pr.resource_id and
            is_nil(pub.published) and
            s.resource_type_id == ^resource_type_id and
            s.section_id == -1 and
            s.user_id == -1
        )

      section_ids ->
        dynamic(
          [s, pub, pr, _],
          s.resource_id == pr.resource_id and
            is_nil(pub.published) and
            s.resource_type_id == ^resource_type_id and
            s.section_id in ^section_ids and
            s.user_id == -1
        )
    end
  end

  defmacro safe_div_fragment(numerator, denominator) do
    quote do
      fragment(
        "?::float8 / NULLIF(?::float8, 0::float8)",
        unquote(numerator),
        unquote(denominator)
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
         adaptive_activity_type_id
       ) do
    query
    |> add_activity_row_select(adaptive_activity_type_id)
    |> aggregate_activity_rows()
    |> select_aggregated_activity_rows()
    |> add_aggregated_activity_order_by(sorting)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  defp browse_non_activity_insights(
         query,
         %Paging{limit: limit, offset: offset},
         %Sorting{} = sorting,
         options
       ) do
    total_count = get_total_count(query, options)

    query
    |> add_non_activity_select(total_count, options)
    |> add_non_activity_order_by(sorting, options)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  defp add_activity_row_select(query, adaptive_activity_type_id) do
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
        eventually_correct: safe_div_fragment(sum(row.num_correct), sum(row.num_attempts)),
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
          order_by(query, [row], {^direction, row.eventually_correct})

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
          eventually_correct: safe_div_fragment(s.num_correct, s.num_attempts),
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
          rev.slug,
          rev.activity_type_id
        ])
        |> select([s, _, _, rev], %{
          id: fragment("gen_random_uuid()::text"),
          total_count: fragment("?::int", ^total_count),
          resource_id: s.resource_id,
          title: rev.title,
          slug: rev.slug,
          part_id: s.part_id,
          activity_type_id: rev.activity_type_id,
          num_correct: sum(s.num_correct),
          num_attempts: sum(s.num_attempts),
          num_hints: sum(s.num_hints),
          num_first_attempts: sum(s.num_first_attempts),
          num_first_attempts_correct: sum(s.num_first_attempts_correct),
          eventually_correct: safe_div_fragment(sum(s.num_correct), sum(s.num_attempts)),
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

        :eventually_correct ->
          order_by(
            query,
            [s],
            {^direction, safe_div_fragment(s.num_correct, s.num_attempts)}
          )

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

        :eventually_correct ->
          order_by(
            query,
            [s],
            {^direction, safe_div_fragment(sum(s.num_correct), sum(s.num_attempts))}
          )

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
end
