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

  alias Oli.Delivery.Proficiency.{Estimate, Telemetry}
  alias Oli.Delivery.Sections.{Section, SectionResourceDepot}
  alias Oli.LearningModel.LearningState
  alias Oli.Repo

  @minimum_attempts 3

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

        estimates =
          Map.new(objective_ids, fn objective_id ->
            sources = Map.fetch!(objective_sources, objective_id)

            {objective_id,
             Map.new(user_ids, fn user_id ->
               estimate = build_estimate(section_id, user_id, objective_id, sources, states)
               {user_id, estimate}
             end)}
          end)

        result = {:ok, estimates}
        {:telemetry_result, result, %{operation: operation_for(objective_sources)}}
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
