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

  def browse_insights(
        %Paging{limit: limit, offset: offset},
        %Sorting{} = sorting,
        %BrowseInsightsOptions{
          project_id: project_id,
          resource_type_id: resource_type_id,
          section_ids: section_ids,
          text_search: text_search
        } = options
      ) do
    where_by = build_where_by(options)
    aggregate_adaptive_activity_rows? = resource_type_id == ResourceType.id_for_activity()

    total_count =
      case aggregate_adaptive_activity_rows? do
        true -> 0
        false -> get_total_count(project_id, section_ids, where_by)
      end

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

    case aggregate_adaptive_activity_rows? do
      true ->
        query
        |> add_select(total_count, options)
        |> Repo.all()
        |> aggregate_adaptive_activity_rows(sorting, limit, offset)

      false ->
        query
        |> add_select(total_count, options)
        |> add_order_by(sorting, options)
        |> limit(^limit)
        |> offset(^offset)
        |> Repo.all()
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

  defp add_select(query, total_count, %BrowseInsightsOptions{section_ids: section_ids}) do
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
          # select id as a random GUID
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

  defp add_order_by(query, %Sorting{direction: direction, field: field}, %BrowseInsightsOptions{
         section_ids: []
       }) do
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

  defp add_order_by(query, %Sorting{direction: direction, field: field}, %BrowseInsightsOptions{
         section_ids: _
       }) do
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

  defp get_total_count(project_id, section_ids, where_by) do
    add_group_by = fn query, section_ids ->
      case section_ids do
        [] -> query
        _section_ids -> query |> group_by([s, _, _, _], [s.resource_id, s.part_id])
      end
    end

    # First, we compute the total count separately
    total_count_query =
      ResourceSummary
      |> join(:left, [s], pub in Publication, on: pub.project_id == ^project_id)
      |> join(:left, [s, pub], pr in PublishedResource, on: pr.publication_id == pub.id)
      |> where(^where_by)
      |> add_group_by.(section_ids)
      |> select([s, _], fragment("count(*) OVER() as total_count"))
      |> limit(1)

    Repo.one(total_count_query)
    |> case do
      nil -> 0
      count -> count
    end
  end

  defp aggregate_adaptive_activity_rows(rows, sorting, limit, offset) do
    adaptive_activity_type_id = Activities.get_registration_by_slug("oli_adaptive").id

    rows
    |> Enum.group_by(&adaptive_activity_group_key(&1, adaptive_activity_type_id))
    |> Enum.map(fn
      {{:adaptive, _resource_id}, grouped_rows} -> aggregate_adaptive_activity_row(grouped_rows)
      {{:standard, _row_id}, [row]} -> row
    end)
    |> sort_rows(sorting)
    |> paginate_rows(limit, offset)
  end

  defp adaptive_activity_group_key(row, adaptive_activity_type_id) do
    case row.activity_type_id do
      ^adaptive_activity_type_id -> {:adaptive, row.resource_id}
      _activity_type_id -> {:standard, row.id}
    end
  end

  defp aggregate_adaptive_activity_row([first_row | _rest] = rows) do
    {alpha, beta, gamma} = get_relative_difficulty_parameters()

    num_correct = Enum.sum_by(rows, & &1.num_correct)
    num_attempts = Enum.sum_by(rows, & &1.num_attempts)
    num_hints = Enum.sum_by(rows, & &1.num_hints)
    num_first_attempts = Enum.sum_by(rows, & &1.num_first_attempts)
    num_first_attempts_correct = Enum.sum_by(rows, & &1.num_first_attempts_correct)

    first_attempt_correct = safe_div(num_first_attempts_correct, num_first_attempts)
    eventually_correct = safe_div(num_correct, num_attempts)

    Map.merge(first_row, %{
      id: "adaptive-#{first_row.resource_id}",
      part_id: nil,
      num_correct: num_correct,
      num_attempts: num_attempts,
      num_hints: num_hints,
      num_first_attempts: num_first_attempts,
      num_first_attempts_correct: num_first_attempts_correct,
      first_attempt_correct: first_attempt_correct,
      eventually_correct: eventually_correct,
      relative_difficulty:
        alpha * (1.0 - first_attempt_correct) + beta * (1.0 - eventually_correct) +
          gamma * num_hints
    })
  end

  defp safe_div(_numerator, 0), do: 0.0
  defp safe_div(numerator, denominator), do: numerator / denominator

  defp sort_rows(rows, %Sorting{direction: direction, field: field}) do
    Enum.sort(rows, fn left, right ->
      case compare_values(Map.get(left, field), Map.get(right, field), direction) do
        :lt ->
          true

        :gt ->
          false

        :eq ->
          case compare_values(left.resource_id, right.resource_id, :asc) do
            :lt ->
              true

            :gt ->
              false

            :eq ->
              case compare_values(left.part_id, right.part_id, :asc) do
                :lt -> true
                :gt -> false
                :eq -> compare_values(stable_row_id(left), stable_row_id(right), :asc) != :gt
              end
          end
      end
    end)
  end

  defp compare_values(left, right, _direction) when left == right, do: :eq
  defp compare_values(nil, _right, :asc), do: :gt
  defp compare_values(_left, nil, :asc), do: :lt
  defp compare_values(nil, _right, :desc), do: :lt
  defp compare_values(_left, nil, :desc), do: :gt

  defp compare_values(left, right, :asc) when left < right, do: :lt
  defp compare_values(left, right, :asc) when left > right, do: :gt
  defp compare_values(left, right, :desc) when left < right, do: :gt
  defp compare_values(left, right, :desc) when left > right, do: :lt

  defp stable_row_id(row), do: to_string(row.id)

  defp paginate_rows(rows, limit, offset) do
    total_count = length(rows)

    rows
    |> Enum.drop(offset)
    |> Enum.take(limit)
    |> Enum.map(&Map.put(&1, :total_count, total_count))
  end
end
