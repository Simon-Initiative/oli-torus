defmodule Oli.FeatureTelemetry do
  @moduledoc """
  Consistent wrapper for emitting feature execution spans.

  Use `span/5` to surround any operation whose adoption you want to measure,
  ensuring AppSignal receives `feature`, `stage`, and `action` tags alongside
  success/failure metadata.
  """

  @event [:torus, :feature, :exec]

  @type feature_name :: atom() | String.t()
  @type stage :: String.t()
  @type action :: String.t()
  @type span_fun :: (-> term())

  @doc """
  Wraps an operation in a telemetry span and annotates it with the feature rollout
  stage and action name.

  The wrapped `fun` may return `:ok`, `{:ok, value}`, `:error`, `{:error, reason}`,
  or any other value (treated as success). Exceptions are re-raised after emitting
  the corresponding `:exception` telemetry event.
  """
  @spec span(feature_name, stage, action, span_fun, map() | keyword()) :: term()
  def span(feature, stage, action, fun, extra_meta \\ %{})
      when is_function(fun, 0) do
    base_meta =
      %{
        feature: normalize_feature(feature),
        stage: normalize_stage(stage),
        action: normalize_action(action)
      }
      |> Map.merge(normalize_meta(extra_meta))

    :telemetry.span(@event, base_meta, fn ->
      result =
        try do
          fun.()
        rescue
          exception ->
            :telemetry.execute(
              @event ++ [:exception],
              %{},
              Map.put(base_meta, :exception, exception)
            )

            reraise(exception, __STACKTRACE__)
        end

      {result, Map.put(base_meta, :ok?, ok_result?(result))}
    end)
  end

  defp normalize_feature(feature) when is_atom(feature), do: Atom.to_string(feature)
  defp normalize_feature(feature) when is_binary(feature), do: feature
  defp normalize_feature(feature), do: to_string(feature)

  defp normalize_stage(nil), do: "unknown"
  defp normalize_stage(stage) when is_atom(stage), do: Atom.to_string(stage)
  defp normalize_stage(stage) when is_binary(stage), do: stage
  defp normalize_stage(stage), do: to_string(stage)

  defp normalize_action(nil), do: "unknown"
  defp normalize_action(action) when is_atom(action), do: Atom.to_string(action)
  defp normalize_action(action) when is_binary(action), do: action
  defp normalize_action(action), do: to_string(action)

  defp normalize_meta(meta) when is_map(meta), do: meta
  defp normalize_meta(meta) when is_list(meta), do: Map.new(meta)
  defp normalize_meta(_meta), do: %{}

  defp ok_result?({:ok, _}), do: true
  defp ok_result?(:ok), do: true
  defp ok_result?({:error, _}), do: false
  defp ok_result?(:error), do: false
  defp ok_result?(_), do: true
end
