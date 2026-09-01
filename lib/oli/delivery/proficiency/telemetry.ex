defmodule Oli.Delivery.Proficiency.Telemetry do
  @moduledoc false

  alias Oli.Delivery.Proficiency.{Aggregate, Estimate}

  @event [:oli, :delivery, :proficiency, :provider]

  @doc "Runs a provider operation in a bounded, identifier-free telemetry span."
  def span(model, operation, requested_counts, fun) when is_function(fun, 0) do
    metadata =
      requested_counts
      |> Map.take([:requested_user_count, :requested_objective_count])
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
          {result, metadata |> Map.merge(result_metadata(result)) |> Map.merge(extra_metadata)}

        result ->
          {result, Map.merge(metadata, result_metadata(result))}
      end
    end)
  end

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
    counts
    |> Map.update!(:returned_count, &(&1 + 1))
    |> Map.update!(score_count(score), &(&1 + 1))
  end

  defp count_aggregate(counts, %Aggregate{numeric_score: score}) do
    counts
    |> Map.update!(:returned_count, &(&1 + 1))
    |> Map.update!(score_count(score), &(&1 + 1))
  end

  defp score_count(score) when is_number(score), do: :defined_count
  defp score_count(nil), do: :unavailable_count
end
