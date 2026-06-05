defmodule Oli.Math.Units do
  @moduledoc """
  Thin Elixir boundary around the public Gleam unit-aware math APIs.

  This module is currently used by the developer Math Prototype only. Gleam owns
  unit parsing, normalization, comparison, and diagnostic formatting.
  """

  @type gleam_config :: term()
  @type gleam_tolerance :: term()
  @type gleam_result :: term()
  @type form_error :: %{field: String.t(), message: String.t()}

  @doc "Compare expected and submitted quantity strings through the public Gleam unit API."
  @spec compare(String.t(), String.t(), gleam_config(), gleam_tolerance()) :: gleam_result()
  def compare(expected, submitted, config, tolerance)
      when is_binary(expected) and is_binary(submitted) do
    call_gleam(:compare_quantities, [expected, submitted, config, tolerance])
  end

  @doc "Format a unit comparison result with Gleam's stable developer diagnostics."
  @spec result_debug(gleam_result()) :: String.t()
  def result_debug(result) do
    call_gleam(:unit_comparison_result_to_debug_string, [result])
  end

  @doc "Convert Math Prototype unit params into a Gleam unit config."
  @spec config_from_form(map()) :: {:ok, gleam_config()} | {:error, [form_error()]}
  def config_from_form(params) when is_map(params) do
    mode_result = unit_mode_from_form(params)
    conversion_result = conversion_from_form(params)
    final_unit_result = final_unit_from_form(params)

    case collect_errors([mode_result, conversion_result, final_unit_result]) do
      [] ->
        {:ok,
         {:unit_config, unwrap(mode_result), accepted_units_from_form(params),
          unwrap(conversion_result), unwrap(final_unit_result)}}

      errors ->
        {:error, errors}
    end
  end

  @doc "Convert Math Prototype tolerance params into a Gleam tolerance value."
  @spec tolerance_from_form(map()) :: {:ok, gleam_tolerance()} | {:error, [form_error()]}
  def tolerance_from_form(params) when is_map(params) do
    case params |> value("tolerance_type", "default") |> normalize_selector() do
      "" ->
        {:ok, default_tolerance()}

      "default" ->
        {:ok, default_tolerance()}

      "none" ->
        {:ok, :no_tolerance}

      "absolute" ->
        with {:ok, abs} <- float_field(params, "abs_tolerance", 0.0) do
          {:ok, {:absolute_tolerance, abs}}
        end

      "relative" ->
        with {:ok, rel} <- float_field(params, "rel_tolerance", 0.0),
             {:ok, epsilon} <- float_field(params, "epsilon", 1.0e-12) do
          {:ok, {:relative_tolerance, rel, epsilon}}
        end

      "absolute_or_relative" ->
        with {:ok, abs} <- float_field(params, "abs_tolerance", 0.0),
             {:ok, rel} <- float_field(params, "rel_tolerance", 0.0),
             {:ok, epsilon} <- float_field(params, "epsilon", 1.0e-12) do
          {:ok, {:absolute_or_relative_tolerance, abs, rel, epsilon}}
        end

      other ->
        {:error, [error("tolerance_type", "unsupported tolerance type #{inspect(other)}")]}
    end
  end

  defp unit_mode_from_form(params) do
    case params |> value("unit_mode", "off") |> normalize_selector() do
      "ignore" ->
        {:ok, :ignore_units}

      "require" ->
        {:ok, :require_units}

      other ->
        {:error, [error("unit_mode", "must be ignore or require; got #{inspect(other)}")]}
    end
  end

  defp conversion_from_form(params) do
    case params |> value("conversion_policy", "allow") |> normalize_selector() do
      "allow" ->
        {:ok, :allow_conversion}

      "disallow" ->
        {:ok, :disallow_conversion}

      other ->
        {:error, [error("conversion_policy", "must be allow or disallow; got #{inspect(other)}")]}
    end
  end

  defp final_unit_from_form(params) do
    case params |> value("final_unit_policy", "any") |> normalize_selector() do
      "any" ->
        {:ok, :any_accepted_unit}

      "strict" ->
        {:ok, :strict_accepted_unit}

      other ->
        {:error, [error("final_unit_policy", "must be any or strict; got #{inspect(other)}")]}
    end
  end

  defp accepted_units_from_form(params) do
    params
    |> value("accepted_units", "")
    |> to_string()
    |> String.split([",", "\n", "\t", " "], trim: true)
  end

  defp default_tolerance do
    {:absolute_or_relative_tolerance, 0.0001, 0.0001, 1.0e-12}
  end

  defp float_field(params, key, default) do
    case value(params, key, default) do
      value when is_float(value) ->
        {:ok, value}

      value when is_integer(value) ->
        {:ok, value / 1}

      value when is_binary(value) ->
        case Float.parse(String.trim(value)) do
          {float, ""} -> {:ok, float}
          _ -> {:error, [error(key, "must be a number")]}
        end

      value ->
        {:error, [error(key, "must be a number, got #{inspect(value)}")]}
    end
  end

  defp normalize_selector(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_selector(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> normalize_selector()
  end

  defp normalize_selector(_value), do: "__unsupported__"

  defp collect_errors(results) do
    Enum.flat_map(results, fn
      {:ok, _value} -> []
      {:error, errors} -> errors
    end)
  end

  defp unwrap({:ok, value}), do: value

  defp value(params, key, default) when is_map(params) do
    Map.get(params, key, default)
  end

  defp error(field, message), do: %{field: field, message: message}

  defp call_gleam(function, args) do
    Oli.Math.Gleam.call(:torus_math, function, args)
  end
end
