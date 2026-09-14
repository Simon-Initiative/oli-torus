defmodule Oli.Delivery.Proficiency.Telemetry do
  @moduledoc """
  Emits bounded provider-read telemetry suitable for AppSignal aggregation.

  Only categorical model/operation/outcome values and aggregate counts are emitted.
  Section, learner, objective, attempt, and raw-content identifiers are deliberately
  excluded so operational diagnosis cannot expose learner-level data.
  """

  alias Oli.Delivery.Proficiency.{Aggregate, Estimate}

  @event [:oli, :delivery, :proficiency, :provider]
  @count_keys [:returned_count, :defined_count, :unavailable_count]

  def empty_counts, do: %{returned_count: 0, defined_count: 0, unavailable_count: 0}

  def count_score(counts, score) do
    counts
    |> Map.update!(:returned_count, &(&1 + 1))
    |> Map.update!(score_count(score), &(&1 + 1))
  end

  @doc "Runs a provider operation in a bounded, identifier-free telemetry span."
  def span(model, operation, requested_counts, fun) when is_function(fun, 0) do
    metadata =
      requested_counts
      |> Map.take([:requested_user_count, :requested_objective_count, :requested_scope_count])
      |> Map.merge(%{
        model: model,
        operation: operation,
        outcome: :error,
        returned_count: 0,
        defined_count: 0,
        unavailable_count: 0
      })

    :telemetry.span(@event, metadata, fn ->
      case fun.() do
        {:telemetry_result, result, extra_metadata} ->
          result_metadata = explicit_or_derived_metadata(result, extra_metadata)

          {result,
           metadata
           |> Map.merge(result_metadata)
           |> Map.merge(Map.drop(extra_metadata, @count_keys))}

        result ->
          {result, Map.merge(metadata, result_metadata(result))}
      end
    end)
  end

  defp explicit_or_derived_metadata(result, extra_metadata) do
    counts = Map.take(extra_metadata, @count_keys)

    case complete_counts?(counts) do
      true -> Map.put(counts, :outcome, outcome(result))
      false -> result_metadata(result)
    end
  end

  defp complete_counts?(%{
         returned_count: returned,
         defined_count: defined,
         unavailable_count: unavailable
       }) do
    Enum.all?([returned, defined, unavailable], &(is_integer(&1) and &1 >= 0)) and
      returned == defined + unavailable
  end

  defp complete_counts?(_counts), do: false

  defp outcome({:ok, _result}), do: :ok
  defp outcome({:error, _reason}), do: :error

  defp result_metadata({:ok, estimates}) when is_map(estimates) do
    counts =
      Enum.reduce(estimates, %{returned_count: 0, defined_count: 0, unavailable_count: 0}, fn
        {_key, %Aggregate{} = aggregate}, counts ->
          count_aggregate(counts, aggregate)

        {_key, by_user}, counts when is_map(by_user) ->
          Enum.reduce(by_user, counts, &count_estimate/2)
      end)

    Map.put(counts, :outcome, :ok)
  end

  defp result_metadata({:error, _reason}) do
    %{outcome: :error, returned_count: 0, defined_count: 0, unavailable_count: 0}
  end

  defp count_estimate({_user_id, %Estimate{score: score}}, counts) do
    count_score(counts, score)
  end

  defp count_aggregate(counts, %Aggregate{numeric_score: score}) do
    count_score(counts, score)
  end

  defp score_count(score) when is_number(score), do: :defined_count
  defp score_count(nil), do: :unavailable_count
end
