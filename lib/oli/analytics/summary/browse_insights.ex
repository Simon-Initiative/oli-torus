defmodule Oli.Analytics.Summary.BrowseInsights do
  alias Oli.Publishing.Publications.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Analytics.Summary.BrowseInsightsOptions
  alias Oli.Analytics.Summary.ResourceSummary
  alias Oli.Resources.Revision
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
        %BrowseInsightsOptions{project_id: project_id, section_ids: section_ids} = options
      ) do

    where_by = build_where_by(options)
    total_count = get_total_count(project_id, section_ids, where_by)

    # Now build the main query with limit, offset, and aggregations
    query =
      ResourceSummary
      |> join(:left, [s], pub in Publication, on: pub.project_id == ^project_id)
      |> join(:left, [s, pub], pr in PublishedResource, on: pr.publication_id == pub.id)
      |> join(:left, [s, pub, pr], rev in Revision, on: rev.id == pr.revision_id)
      |> where(^where_by)
      |> add_select(total_count, options)
      |> add_order_by(sorting, options)
      |> limit(^limit)
      |> offset(^offset)

    Repo.all(query)
  end

  defp build_where_by(%BrowseInsightsOptions{project_id: project_id, resource_type_id: resource_type_id, section_ids: section_ids}) do
    case section_ids do
      [] ->
        dynamic([s, pub, pr, _],
          s.project_id == ^project_id and
            s.resource_id == pr.resource_id and
            is_nil(pub.published) and
            s.resource_type_id == ^resource_type_id and
            s.section_id == -1 and
            s.user_id == -1 and
            s.publication_id == -1
        )

      section_ids ->
        dynamic([s, pub, pr, _],
          s.project_id == ^project_id and
            s.resource_id == pr.resource_id and
            is_nil(pub.published) and
            s.resource_type_id == ^resource_type_id and
            s.section_id in ^section_ids and
            s.user_id == -1 and
            s.publication_id == -1
        )
    end
  end

  defp add_select(query, total_count, %BrowseInsightsOptions{section_ids: section_ids}) do

    {alpha, beta, gamma} = get_relative_difficulty_parameters()

    case section_ids do
      [] ->
        query
        |> select([s, pub, pr, rev], %{
          total_count: fragment("?::int", ^total_count),
          title: rev.title,
          slug: rev.slug,
          part_id: s.part_id,
          pub_id: pub.id,
          activity_type_id: rev.activity_type_id,
          pr_rev: pr.revision_id,
          pr_resource: pr.resource_id,
          num_attempts: s.num_attempts,
          num_first_attempts: s.num_first_attempts,
          eventually_correct: fragment("?::float8 / ?::float8", s.num_correct, s.num_attempts),
          first_attempt_correct: fragment("?::float8 / ?::float8", s.num_first_attempts_correct, s.num_first_attempts),
          relative_difficulty:
            fragment(
              "?::float8 * (1.0 - ?::float8) + ?::float8 * (1.0 - ?::float8) + ?::float8 * ?::float8",
              ^alpha,
              s.num_first_attempts_correct / s.num_first_attempts,
              ^beta,
              s.num_correct / s.num_attempts,
              ^gamma,
              s.num_hints
            )
        })

      _section_ids ->
        query
        |> group_by([s, _, _, rev], [s.resource_id, s.part_id, rev.title, rev.slug, rev.activity_type_id])
        |> select([s, _, _, rev], %{
          total_count: fragment("?::int", ^total_count),
          resource_id: s.resource_id,
          title: rev.title,
          slug: rev.slug,
          part_id: s.part_id,
          activity_type_id: rev.activity_type_id,
          num_attempts: sum(s.num_attempts),
          num_first_attempts: sum(s.num_first_attempts),
          eventually_correct: fragment("?::float8 / ?::float8", sum(s.num_correct), sum(s.num_attempts)),
          first_attempt_correct: fragment("?::float8 / ?::float8", sum(s.num_first_attempts_correct), sum(s.num_first_attempts)),
          relative_difficulty:
            fragment(
              "?::float8 * (1.0 - (?::float8)) + ?::float8 * (1.0 - (?::float8)) + ?::float8 * (?::float8)",
              ^alpha,
              sum(s.num_first_attempts_correct) / sum(s.num_first_attempts),
              ^beta,
              sum(s.num_correct) / sum(s.num_attempts),
              ^gamma,
              sum(s.num_hints)
            )
        })
    end

  end

  defp add_order_by(query, %Sorting{direction: direction, field: field},
    %BrowseInsightsOptions{section_ids: []}) do

    {alpha, beta, gamma} = get_relative_difficulty_parameters()

    query =
      case field do
        :title ->
          order_by(query, [_, _, _, rev], {^direction, rev.title})

        :num_attempts ->
          order_by(query, [s], {^direction, s.num_attempts})

        :num_first_attempts ->
          order_by(query, [s], {^direction, s.num_first_attempts})

        :eventually_correct ->
          order_by(query, [s], {^direction, fragment("?::float8 / ?::float8", s.num_correct, s.num_attempts)})

        :first_attempt_correct ->
          order_by(query, [s], {^direction, fragment("?::float8 / ?::float8", s.num_first_attempts_correct, s.num_first_attempts)})

        :relative_difficulty ->
          order_by(query, [s], {^direction, fragment(
            "?::float8 * (1.0 - ?::float8) + ?::float8 * (1.0 - ?::float8) + ?::float8 * ?::float8",
            ^alpha,
            s.num_first_attempts_correct / s.num_first_attempts,
            ^beta,
            s.num_correct / s.num_attempts,
            ^gamma,
            s.num_hints
          )})

        _ ->
          order_by(query, [_, _, _, rev], {^direction, field(rev, ^field)})
      end

    # Ensure there is always a stable sort order based on id
    order_by(query, [s], s.resource_id)
  end

  defp add_order_by(query, %Sorting{direction: direction, field: field},
    %BrowseInsightsOptions{section_ids: _}) do

    {alpha, beta, gamma} = get_relative_difficulty_parameters()

    query =
      case field do
        :title ->
          order_by(query, [_, _, _, rev], {^direction, rev.title})

        :num_attempts ->
          order_by(query, [s], {^direction, sum(s.num_attempts)})

        :num_first_attempts ->
          order_by(query, [s], {^direction, sum(s.num_first_attempts)})

        :eventually_correct ->
          order_by(query, [s], {^direction, fragment("?::float8 / ?::float8", sum(s.num_correct), sum(s.num_attempts))})

        :first_attempt_correct ->
          order_by(query, [s], {^direction, fragment("?::float8 / ?::float8", sum(s.num_first_attempts_correct), sum(s.num_first_attempts))})

        :relative_difficulty ->
          order_by(query, [s], {^direction, fragment(
            "?::float8 * (1.0 - (?::float8)) + ?::float8 * (1.0 - (?::float8)) + ?::float8 * (?::float8)",
            ^alpha,
            sum(s.num_first_attempts_correct) / sum(s.num_first_attempts),
            ^beta,
            sum(s.num_correct) / sum(s.num_attempts),
            ^gamma,
            sum(s.num_hints)
          )})

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

end
