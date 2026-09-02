defmodule Oli.Delivery.Proficiency.LktAoa do
  @moduledoc """
  Read-only proficiency provider over materialized LKT-AOA learner state.

  Direct objectives require three attempts on that objective. Parent objectives
  instead derive from effective children and require three attempts in total;
  an individual child below three never suppresses an otherwise eligible parent.
  Parent rows are deliberately ignored because derived state would become stale
  whenever any child changes.
  """

  import Ecto.Query

  alias Oli.Delivery.Proficiency.{Aggregate, Estimate, ScopeMembership, Telemetry}
  alias Oli.Delivery.Sections.{Section, SectionResourceDepot}
  alias Oli.LearningModel.LearningState
  alias Oli.Repo

  @minimum_attempts 3

  def objective_ids_for_scope(%Section{} = section, scope) do
    with {:ok, %{^scope => objective_ids}} <-
           ScopeMembership.objectives_for_scopes(section, [scope]) do
      {:ok, MapSet.to_list(objective_ids)}
    end
  end

  def page_ids(%Section{id: section_id}) do
    {:ok,
     section_id
     |> SectionResourceDepot.get_lessons()
     |> Enum.map(& &1.resource_id)}
  end

  def user_ids_for_objectives(%Section{id: section_id}, objective_ids) do
    ids =
      from(state in LearningState,
        where: state.section_id == ^section_id and state.learning_objective_id in ^objective_ids,
        select: state.user_id,
        distinct: true
      )
      |> Repo.all()

    {:ok, ids}
  end

  def user_ids_for_scopes(%Section{id: section_id} = section, scopes, _opts) do
    with {:ok, membership} <- ScopeMembership.objectives_for_scopes(section, scopes) do
      objective_ids = membership |> Map.values() |> Enum.reduce(MapSet.new(), &MapSet.union/2)

      ids =
        from(state in LearningState,
          where:
            state.section_id == ^section_id and
              state.learning_objective_id in ^MapSet.to_list(objective_ids),
          select: state.user_id,
          distinct: true
        )
        |> Repo.all()

      {:ok, ids}
    end
  end

  def labels_for_pages(%Section{} = section, page_ids, user_ids) do
    scopes = Enum.map(page_ids, &{:page, &1})

    with {:ok, aggregates} <- scope_aggregates(section, scopes, user_ids: user_ids) do
      {:ok,
       Map.new(aggregates, fn {{:page, page_id}, aggregate} ->
         {page_id, mode_label(aggregate.distribution)}
       end)}
    end
  end

  def label_for_score(_section, score, attempt_count),
    do: score |> direct_label(attempt_count) |> label_string()

  @doc "Bulk-reads learner estimates for page, container, and course scopes."
  def estimates_for_scopes(%Section{id: section_id} = section, user_ids, scopes, _opts) do
    user_ids = normalize_ids(user_ids)
    scopes = Enum.uniq(scopes)

    Telemetry.span(
      :lkt_aoa,
      :learner_scope,
      %{requested_user_count: length(user_ids), requested_scope_count: length(scopes)},
      fn ->
        with {:ok, membership} <- ScopeMembership.objectives_for_scopes(section, scopes) do
          objective_ids = membership |> Map.values() |> Enum.reduce(MapSet.new(), &MapSet.union/2)
          states = read_states(section_id, user_ids, MapSet.to_list(objective_ids))

          {estimates, counts} =
            build_estimate_map(scopes, user_ids, fn scope, user_id ->
              scope_estimate(section_id, user_id, membership[scope], states)
            end)

          result = {:ok, estimates}
          {:telemetry_result, result, counts}
        end
      end
    )
  end

  @doc "Aggregates direct objective estimates across the requested learners."
  def objective_aggregates(%Section{} = section, objective_ids, opts) do
    with {:ok, user_ids} <- user_ids_from(opts),
         {:ok, estimates} <- estimates_for_objectives(section, user_ids, objective_ids, opts) do
      {:ok,
       Map.new(estimates, fn {id, learner_estimates} -> {id, aggregate(learner_estimates)} end)}
    end
  end

  @doc "Aggregates scope estimates across the requested learners with equal learner weight."
  def scope_aggregates(%Section{} = section, scopes, opts) do
    Telemetry.span(
      :lkt_aoa,
      :class_scope,
      %{requested_scope_count: length(Enum.uniq(scopes))},
      fn ->
        with {:ok, user_ids} <- user_ids_from(opts),
             {:ok, membership} <- ScopeMembership.objectives_for_scopes(section, scopes) do
          case read_scope_aggregates(section.id, user_ids, Enum.uniq(scopes), membership) do
            {:ok, aggregates, counts} -> {:telemetry_result, {:ok, aggregates}, counts}
            {:error, _reason} = error -> error
          end
        end
      end
    )
  end

  defp read_scope_aggregates(section_id, user_ids, scopes, membership) do
    scope_payload =
      scopes
      |> Enum.with_index()
      |> Enum.map(fn {scope, index} ->
        %{
          "scope_index" => index,
          "objective_ids" => membership |> Map.fetch!(scope) |> MapSet.to_list()
        }
      end)

    sql = """
    WITH requested_scopes AS (
      SELECT scope_index, objective_ids
      FROM jsonb_to_recordset($1::jsonb)
        AS requested(scope_index integer, objective_ids bigint[])
    ),
    scope_objectives AS (
      SELECT requested.scope_index, objective_id
      FROM requested_scopes AS requested
      CROSS JOIN LATERAL unnest(requested.objective_ids) AS objective_id
    ),
    learner_scopes AS (
      SELECT
        membership.scope_index,
        state.user_id,
        avg(state.aoa)::float8 AS score,
        sum(state.attempt_count)::bigint AS attempt_count
      FROM scope_objectives AS membership
      JOIN learning_states AS state
        ON state.learning_objective_id = membership.objective_id
      WHERE state.section_id = $2
        AND state.user_id = ANY($3::bigint[])
      GROUP BY membership.scope_index, state.user_id
    )
    SELECT
      requested.scope_index,
      avg(learner.score) FILTER (WHERE learner.attempt_count >= 3)::float8 AS numeric_score,
      count(learner.user_id) FILTER (
        WHERE learner.attempt_count >= 3 AND learner.score < 0.4
      )::bigint AS low_count,
      count(learner.user_id) FILTER (
        WHERE learner.attempt_count >= 3 AND learner.score >= 0.4 AND learner.score <= 0.8
      )::bigint AS medium_count,
      count(learner.user_id) FILTER (
        WHERE learner.attempt_count >= 3 AND learner.score > 0.8
      )::bigint AS high_count,
      count(learner.user_id) FILTER (WHERE learner.attempt_count >= 3)::bigint AS defined_count
    FROM requested_scopes AS requested
    LEFT JOIN learner_scopes AS learner ON learner.scope_index = requested.scope_index
    GROUP BY requested.scope_index
    ORDER BY requested.scope_index
    """

    case Repo.query(sql, [scope_payload, section_id, user_ids]) do
      {:ok, %{rows: rows}} ->
        total_count = length(user_ids)
        scopes_by_index = List.to_tuple(scopes)

        {aggregates, counts} =
          Enum.reduce(rows, {%{}, Telemetry.empty_counts()}, fn
            [index, numeric_score, low, medium, high, defined], {aggregates, counts} ->
              distribution =
                %{
                  low: low,
                  medium: medium,
                  high: high,
                  not_enough_information: total_count - defined
                }
                |> Enum.reject(fn {_label, count} -> count == 0 end)
                |> Map.new()

              {:ok, aggregate} =
                Aggregate.new(%{
                  numeric_score: numeric_score,
                  distribution: distribution,
                  contributing_count: defined,
                  eligible_count: defined,
                  total_count: total_count,
                  coverage: %{defined: defined, total: total_count}
                })

              aggregates = Map.put(aggregates, elem(scopes_by_index, index), aggregate)
              {aggregates, Telemetry.count_score(counts, aggregate.numeric_score)}
          end)

        {:ok, aggregates, counts}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Bulk-reads direct and effective-parent estimates using one learning-state query."
  def estimates_for_objectives(%Section{id: section_id}, user_ids, objective_ids, _opts) do
    user_ids = normalize_ids(user_ids)
    objective_ids = normalize_ids(objective_ids)

    Telemetry.span(
      :lkt_aoa,
      :objective_read,
      %{requested_user_count: length(user_ids), requested_objective_count: length(objective_ids)},
      fn ->
        objective_sources = objective_sources(section_id, objective_ids)
        state_objective_ids = objective_sources |> Map.values() |> List.flatten() |> Enum.uniq()
        states = read_states(section_id, user_ids, state_objective_ids)

        {estimates, counts} =
          build_estimate_map(objective_ids, user_ids, fn objective_id, user_id ->
            sources = Map.fetch!(objective_sources, objective_id)
            build_estimate(section_id, user_id, objective_id, sources, states)
          end)

        result = {:ok, estimates}
        {:telemetry_result, result, Map.put(counts, :operation, operation_for(objective_sources))}
      end
    )
  end

  defp objective_sources(_section_id, []), do: %{}

  defp objective_sources(section_id, objective_ids) do
    effective_children =
      section_id
      |> SectionResourceDepot.objectives_with_effective_children_for(objective_ids)
      |> Map.new(&{&1.resource_id, normalize_ids(List.wrap(&1.children))})

    Map.new(objective_ids, fn objective_id ->
      case Map.get(effective_children, objective_id, []) do
        [] -> {objective_id, [objective_id]}
        child_ids -> {objective_id, child_ids}
      end
    end)
  end

  defp operation_for(objective_sources) do
    case Enum.any?(objective_sources, fn {objective_id, sources} -> sources != [objective_id] end) do
      true -> :parent_objective
      false -> :direct_objective
    end
  end

  defp build_estimate_map(keys, user_ids, build_estimate) do
    Enum.reduce(keys, {%{}, Telemetry.empty_counts()}, fn key, {entries, counts} ->
      {learner_entries, counts} =
        Enum.reduce(user_ids, {%{}, counts}, fn user_id, {learner_entries, counts} ->
          estimate = build_estimate.(key, user_id)
          learner_entries = Map.put(learner_entries, user_id, estimate)
          {learner_entries, Telemetry.count_score(counts, estimate.score)}
        end)

      {Map.put(entries, key, learner_entries), counts}
    end)
  end

  defp read_states(_section_id, [], _objective_ids), do: %{}
  defp read_states(_section_id, _user_ids, []), do: %{}

  defp read_states(section_id, user_ids, objective_ids) do
    from(state in LearningState,
      where:
        state.section_id == ^section_id and state.user_id in ^user_ids and
          state.learning_objective_id in ^objective_ids,
      select: %{
        user_id: state.user_id,
        learning_objective_id: state.learning_objective_id,
        aoa: state.aoa,
        confidence: state.confidence,
        attempt_count: state.attempt_count,
        unique_activity_part_count: state.unique_activity_part_count
      }
    )
    |> Repo.all()
    |> Map.new(&{{&1.user_id, &1.learning_objective_id}, &1})
  end

  defp build_estimate(section_id, user_id, objective_id, [objective_id], states) do
    direct_estimate(section_id, user_id, objective_id, Map.get(states, {user_id, objective_id}))
  end

  defp build_estimate(section_id, user_id, objective_id, child_ids, states) do
    child_states = Enum.flat_map(child_ids, &List.wrap(Map.get(states, {user_id, &1})))
    parent_estimate(section_id, user_id, objective_id, child_states)
  end

  defp direct_estimate(section_id, user_id, objective_id, nil) do
    new_estimate!(section_id, user_id, objective_id, nil, :not_enough_information, nil, 0, 0)
  end

  defp direct_estimate(section_id, user_id, objective_id, state) do
    label = direct_label(state.aoa, state.attempt_count)
    score = if label == :not_enough_information, do: nil, else: state.aoa

    new_estimate!(
      section_id,
      user_id,
      objective_id,
      score,
      label,
      state.confidence,
      state.attempt_count,
      state.unique_activity_part_count
    )
  end

  defp parent_estimate(section_id, user_id, objective_id, states) do
    attempt_count = Enum.sum(Enum.map(states, & &1.attempt_count))
    unique_part_count = Enum.sum(Enum.map(states, & &1.unique_activity_part_count))

    # Parent AOA is evidence-weighted by tagged opportunities. Confidence stays
    # separate and uses the same weights so it never alters proficiency itself.
    score = weighted_average(states, :aoa, attempt_count)
    confidence = weighted_average(states, :confidence, attempt_count)
    label = parent_label(score, attempt_count)
    visible_score = if label == :not_enough_information, do: nil, else: score

    new_estimate!(
      section_id,
      user_id,
      objective_id,
      visible_score,
      label,
      confidence,
      attempt_count,
      unique_part_count
    )
  end

  defp scope_estimate(section_id, user_id, objective_ids, states) do
    available_states =
      objective_ids
      |> Enum.flat_map(&List.wrap(Map.get(states, {user_id, &1})))

    attempt_count = Enum.sum(Enum.map(available_states, & &1.attempt_count))
    unique_part_count = Enum.sum(Enum.map(available_states, & &1.unique_activity_part_count))

    # Scope eligibility uses total evidence, while its score gives every distinct
    # available LO equal weight. An unattempted LO therefore cannot suppress a scope.
    score = mean(available_states, :aoa)
    confidence = mean(available_states, :confidence)
    label = parent_label(score, attempt_count)
    visible_score = if label == :not_enough_information, do: nil, else: score

    new_estimate!(
      section_id,
      user_id,
      nil,
      visible_score,
      label,
      confidence,
      attempt_count,
      unique_part_count
    )
  end

  defp aggregate(learner_estimates) do
    estimates = Map.values(learner_estimates)
    defined = Enum.filter(estimates, &is_number(&1.score))
    numeric_score = mean(defined, :score)

    distribution = Enum.frequencies_by(estimates, & &1.label)

    {:ok, aggregate} =
      Aggregate.new(%{
        numeric_score: numeric_score,
        distribution: distribution,
        contributing_count: length(defined),
        eligible_count: length(defined),
        total_count: length(estimates),
        coverage: %{defined: length(defined), total: length(estimates)}
      })

    aggregate
  end

  defp mean([], _field), do: nil

  defp mean(values, field),
    do: Enum.sum(Enum.map(values, &Map.fetch!(&1, field))) / length(values)

  defp user_ids_from(opts) do
    case Keyword.fetch(opts, :user_ids) do
      {:ok, user_ids} when is_list(user_ids) -> {:ok, normalize_ids(user_ids)}
      _ -> {:error, {:invalid_option, :user_ids}}
    end
  end

  defp weighted_average(_states, _field, 0), do: nil

  defp weighted_average(states, field, total_attempts) do
    Enum.reduce(states, 0.0, fn state, total ->
      total + Map.fetch!(state, field) * state.attempt_count
    end) / total_attempts
  end

  # Unlike the naive model, exactly 0.4 belongs to Medium in LKT-AOA.
  defp direct_label(_score, attempts) when attempts < @minimum_attempts,
    do: :not_enough_information

  defp direct_label(score, _attempts), do: numeric_label(score)

  defp parent_label(_score, attempts) when attempts < @minimum_attempts,
    do: :not_enough_information

  defp parent_label(score, _attempts), do: numeric_label(score)

  defp numeric_label(score) when score < 0.4, do: :low
  defp numeric_label(score) when score <= 0.8, do: :medium
  defp numeric_label(_score), do: :high

  defp label_string(:low), do: "Low"
  defp label_string(:medium), do: "Medium"
  defp label_string(:high), do: "High"
  defp label_string(_label), do: "Not enough data"

  defp mode_label(distribution) when map_size(distribution) == 0, do: "Not enough data"

  defp mode_label(distribution) do
    distribution
    |> Enum.map(fn {label, count} -> {label_string(label), count} end)
    |> Enum.sort_by(fn {label, _count} -> label_rank(label) end)
    |> Enum.max_by(fn {_label, count} -> count end)
    |> elem(0)
  end

  defp label_rank("Low"), do: 0
  defp label_rank("Medium"), do: 1
  defp label_rank("High"), do: 2
  defp label_rank(_label), do: 3

  defp new_estimate!(section_id, user_id, objective_id, score, label, confidence, attempts, parts) do
    {:ok, estimate} =
      Estimate.new(%{
        section_id: section_id,
        user_id: user_id,
        learning_objective_id: objective_id,
        score: score,
        label: label,
        confidence: confidence,
        attempt_count: attempts,
        unique_activity_part_count: parts,
        learning_model_version: :lkt_aoa
      })

    estimate
  end

  defp normalize_ids(ids), do: ids |> Enum.filter(&is_integer/1) |> Enum.uniq()
end
