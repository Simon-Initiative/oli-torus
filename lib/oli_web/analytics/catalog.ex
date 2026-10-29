defmodule OliWeb.Analytics.Catalog do
  @moduledoc """
  Compile-time view of `priv/analytics/event_catalog.json`, the Google Analytics event catalog
  shared with `assets/src/analytics/catalog.ts`.

  Context parameters (role, course, area, page type, entry point) are resolved by
  `OliWeb.Analytics` and applied by the browser writer, so emitters may only supply an event's
  catalogued event parameters.
  """

  @path Path.expand("../../../priv/analytics/event_catalog.json", __DIR__)
  @external_resource @path
  @catalog @path |> File.read!() |> Jason.decode!()

  @event_parameters @catalog["event_parameters"]
  @events @catalog["events"]

  @doc "Returns the decoded catalog."
  @spec catalog() :: map()
  def catalog, do: @catalog

  @doc "Returns the catalogued event names."
  @spec event_names() :: [String.t()]
  def event_names, do: Map.keys(@events)

  @doc """
  Keeps only the catalogued, valid event parameters an emitter may supply for `name`.

  Returns the kept parameters (string keys) and the sorted names of dropped parameters, or
  `:error` when the event is not catalogued. Context and derived parameters are always dropped
  because the writer resolves them.
  """
  @spec event_params(String.t(), map()) :: {:ok, map(), [String.t()]} | :error
  def event_params(name, params) when is_binary(name) and is_map(params) do
    case Map.fetch(@events, name) do
      {:ok, %{"parameters" => allowed}} ->
        {kept, dropped} =
          Enum.reduce(params, {%{}, []}, fn {key, value}, {kept, dropped} ->
            key = parameter_name(key)

            case Map.has_key?(allowed, key) and valid?(Map.get(@event_parameters, key), value) do
              true -> {Map.put(kept, key, value), dropped}
              false -> {kept, [key | dropped]}
            end
          end)

        {:ok, kept, Enum.sort(dropped)}

      :error ->
        :error
    end
  end

  def event_params(_name, _params), do: :error

  defp parameter_name(key) when is_atom(key), do: Atom.to_string(key)
  defp parameter_name(key) when is_binary(key), do: key
  defp parameter_name(key), do: inspect(key)

  defp valid?(%{"values" => values}, value) when is_binary(value), do: Map.has_key?(values, value)

  # dollar_endonly keeps "$" from matching before a trailing newline, as in JavaScript.
  defp valid?(%{"pattern" => pattern}, value) when is_binary(value),
    do: pattern |> Regex.compile!([:dollar_endonly]) |> Regex.match?(value)

  defp valid?(_definition, _value), do: false
end
