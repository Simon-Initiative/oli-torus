defmodule Oli.Delivery.Proficiency.Naive do
  @moduledoc """
  Proficiency provider for the legacy first-attempt model.

  This module owns the `ResourceSummary` coupling, including the raw four-value
  tuple retained for compatibility. New callers receive canonical estimates;
  the tuple must never be interpreted as an LKT-AOA state.
  """

  import Ecto.Query

  alias Oli.Analytics.Summary.ResourceSummary
  alias Oli.Delivery.Proficiency.{Estimate, Telemetry}
  alias Oli.Delivery.Sections.Section
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  @minimum_attempts 3

  @doc "Bulk-reads canonical naive estimates for the requested learners and objectives."
  def estimates_for_objectives(%Section{id: section_id}, user_ids, objective_ids, _opts) do
    user_ids = normalize_ids(user_ids)
    objective_ids = normalize_ids(objective_ids)

    Telemetry.span(
      :naive,
      :direct_objective,
      %{requested_user_count: length(user_ids), requested_objective_count: length(objective_ids)},
      fn ->
        rows = read_summaries(section_id, user_ids, objective_ids)

        estimates =
          Map.new(objective_ids, fn objective_id ->
            {objective_id,
             Map.new(user_ids, fn user_id ->
               values = Map.get(rows, {user_id, objective_id})
               {user_id, estimate(section_id, user_id, objective_id, values)}
             end)}
          end)

        {:ok, estimates}
      end
    )
  end

  defp read_summaries(_section_id, [], _objective_ids), do: %{}
  defp read_summaries(_section_id, _user_ids, []), do: %{}

  defp read_summaries(section_id, user_ids, objective_ids) do
    objective_type_id = ResourceType.id_for_objective()

    from(summary in ResourceSummary,
      where:
        summary.section_id == ^section_id and summary.project_id == -1 and
          summary.resource_type_id == ^objective_type_id and summary.user_id in ^user_ids and
          summary.resource_id in ^objective_ids,
      select: {
        summary.user_id,
        summary.resource_id,
        summary.num_first_attempts_correct,
        summary.num_first_attempts
      }
    )
    |> Repo.all()
    |> Map.new(fn {user_id, objective_id, correct, first_attempts} ->
      {{user_id, objective_id}, {correct, first_attempts}}
    end)
  end

  @doc "Returns the exact legacy ResourceSummary tuple map used by Metrics adapters."
  def raw_proficiency_per_learning_objective(section_id, opts \\ []) do
    objective_type_id = ResourceType.id_for_objective()

    objective_filter =
      if opts[:objective_ids],
        do: dynamic([summary], summary.resource_id in ^opts[:objective_ids]),
        else: true

    student_filter =
      if opts[:student_id],
        do: dynamic([summary], summary.user_id == ^opts[:student_id]),
        else: dynamic([summary], summary.user_id == -1)

    from(summary in ResourceSummary,
      where:
        summary.section_id == ^section_id and summary.project_id == -1 and
          summary.resource_type_id == ^objective_type_id,
      where: ^objective_filter,
      where: ^student_filter,
      select: {
        summary.resource_id,
        {
          summary.num_first_attempts_correct,
          summary.num_first_attempts,
          summary.num_correct,
          summary.num_attempts
        }
      }
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc "Classifies a naive score using the legacy inclusive 0.4 and 0.8 boundaries."
  def proficiency_range(_score, attempts) when attempts < @minimum_attempts,
    do: "Not enough data"

  def proficiency_range(nil, _attempts), do: "Not enough data"
  def proficiency_range(score, _attempts) when score <= 0.4, do: "Low"
  def proficiency_range(score, _attempts) when score <= 0.8, do: "Medium"
  def proficiency_range(_score, _attempts), do: "High"

  defp estimate(section_id, user_id, objective_id, nil) do
    new_estimate!(section_id, user_id, objective_id, nil, :not_enough_information, 0)
  end

  defp estimate(section_id, user_id, objective_id, {correct, first_attempts}) do
    score =
      case first_attempts do
        0 -> nil
        count -> (correct + 0.2 * (count - correct)) / count
      end

    label = label(score, first_attempts)
    visible_score = if label == :not_enough_information, do: nil, else: score

    new_estimate!(section_id, user_id, objective_id, visible_score, label, first_attempts)
  end

  defp new_estimate!(section_id, user_id, objective_id, score, label, attempts) do
    {:ok, estimate} =
      Estimate.new(%{
        section_id: section_id,
        user_id: user_id,
        learning_objective_id: objective_id,
        score: score,
        label: label,
        confidence: nil,
        attempt_count: attempts,
        unique_activity_part_count: 0,
        learning_model_version: :naive
      })

    estimate
  end

  defp label(_score, attempts) when attempts < @minimum_attempts, do: :not_enough_information
  defp label(nil, _attempts), do: :not_enough_information
  defp label(score, _attempts) when score <= 0.4, do: :low
  defp label(score, _attempts) when score <= 0.8, do: :medium
  defp label(_score, _attempts), do: :high

  defp normalize_ids(ids), do: ids |> Enum.filter(&is_integer/1) |> Enum.uniq()
end
