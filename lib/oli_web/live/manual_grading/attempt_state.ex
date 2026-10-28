defmodule OliWeb.ManualGrading.AttemptState do
  @moduledoc """
  Loads what a scoring view needs for one activity attempt: its latest part attempts and the part
  definitions with the `out_of` each manual part is scored against.
  """

  alias Oli.Activities.AdaptiveParts
  alias Oli.Activities.Model
  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.ManualGrading

  @doc """
  Latest part attempts of the activity attempt, in authored order (`AdaptiveParts.ordered_part_ids/1`;
  parts missing from the authored lists come last, by part id).

  An adaptive activity keeps only the parts `AdaptiveParts.manual_gradeable_part_ids/1` allows
  (the scorable ones, plus persisted parts graded manually); any other activity keeps every part,
  automatic and already evaluated ones included. Callers pick the parts they score.
  """
  def part_attempts(%{attempt_guid: guid, activity_type_id: _, revision: revision} = attempt) do
    guid
    |> Core.get_latest_part_attempts()
    |> in_authored_order(revision)
    |> ManualGrading.filter_part_attempts_for_manual_grading(attempt)
  end

  defp in_authored_order(part_attempts, %{content: content}) do
    rank = content |> AdaptiveParts.ordered_part_ids() |> Enum.with_index() |> Map.new()

    Enum.sort_by(part_attempts, &{Map.get(rank, &1.part_id, map_size(rank)), &1.part_id})
  end

  defp in_authored_order(part_attempts, _revision), do: Enum.sort_by(part_attempts, & &1.part_id)

  @doc "Part definitions by part id, with the adaptive screen max score applied to manual parts."
  def parts_map(attempt, part_attempts) do
    {:ok, model} = Model.parse(attempt.revision.content)

    model.parts
    |> Map.new(&{&1.id, &1})
    |> apply_adaptive_manual_out_of(model, attempt, part_attempts)
  end

  @doc "The maximum score of a part attempt, 1.0 when the part does not declare one."
  def out_of(%{part_id: part_id}, parts_map) do
    case Map.get(parts_map, part_id) do
      %Part{out_of: out_of} when is_number(out_of) -> out_of
      _ -> 1.0
    end
  end

  # Adaptive stateful non-scorable parts (e.g. a manually graded janus-capi-iframe) do not carry a
  # meaningful part-level `out_of`; their score is authored at the screen level via
  # `custom.maxScore`, so that max is split evenly among the manual parts.
  defp apply_adaptive_manual_out_of(
         parts_map,
         model,
         %{activity_type_id: activity_type_id} = activity_attempt,
         part_attempts
       ) do
    with true <- AdaptiveParts.adaptive_activity?(%{activity_type_id: activity_type_id}),
         screen_max when is_number(screen_max) and screen_max > 0 <-
           adaptive_screen_max_score(model) do
      content = activity_attempt.revision.content

      manual_part_ids =
        part_attempts
        |> Enum.filter(&(&1.grading_approach == :manual))
        |> Enum.map(& &1.part_id)
        |> Enum.uniq()
        |> Enum.filter(&Map.has_key?(parts_map, &1))
        |> Enum.filter(fn part_id ->
          case AdaptiveParts.part_definition(content, part_id) do
            nil -> false
            part -> not AdaptiveParts.scorable_part?(part)
          end
        end)

      case manual_part_ids do
        [] ->
          parts_map

        ids ->
          per_part = screen_max / length(ids)

          Enum.reduce(ids, parts_map, fn part_id, acc ->
            Map.update!(acc, part_id, fn %Part{} = part -> %{part | out_of: per_part} end)
          end)
      end
    else
      _ -> parts_map
    end
  end

  defp adaptive_screen_max_score(%Model{delivery: delivery}) when is_map(delivery) do
    delivery
    |> Map.get("custom", %{})
    |> Map.get("maxScore")
    |> normalize_number()
  end

  defp adaptive_screen_max_score(_), do: nil

  defp normalize_number(value) when is_integer(value), do: value * 1.0
  defp normalize_number(value) when is_float(value), do: value

  defp normalize_number(value) when is_binary(value), do: parse_number(value)
  defp normalize_number(_), do: nil

  @doc """
  Parses a whole text as a float, or `nil` when it is not one. Never raises: `Float.parse/1`
  raises on an integer part too large for a float, which takes at least 309 characters, so a
  longer text is never converted.
  """
  def parse_number(text) when is_binary(text) and byte_size(text) <= 308 do
    case Float.parse(text) do
      {parsed, ""} -> parsed
      _ -> nil
    end
  end

  def parse_number(_), do: nil
end
