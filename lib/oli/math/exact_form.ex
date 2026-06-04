defmodule Oli.Math.ExactForm do
  @moduledoc """
  Thin Elixir boundary around the public Gleam exact-form APIs.

  Gleam owns exact-form classification, semantic-before-form ordering, and
  stable result formatting. This module only translates developer prototype form
  values into generated Gleam config terms and calls the stable `torus_math`
  boundary.
  """

  @type gleam_config :: term()
  @type gleam_result :: term()
  @type form_error :: %{field: String.t(), message: String.t()}

  @doc "Return Gleam's default exact-form configuration."
  @spec default_config() :: gleam_config()
  def default_config do
    call_gleam(:default_exact_form_config, [])
  end

  @doc "Check a raw candidate string against an exact-form configuration."
  @spec check(String.t(), gleam_config()) :: gleam_result()
  def check(candidate, config) when is_binary(candidate) do
    call_gleam(:check_exact_form, [candidate, config])
  end

  @doc "Run algebraic equivalence first, then exact-form checking after semantic success."
  @spec check_algebraic(String.t(), String.t(), term(), gleam_config()) :: gleam_result()
  def check_algebraic(expected, candidate, equivalence_config, form_config)
      when is_binary(expected) and is_binary(candidate) do
    call_gleam(:check_algebraic_equivalence_with_form, [
      expected,
      candidate,
      equivalence_config,
      form_config
    ])
  end

  @doc "Format a standalone exact-form result with Gleam's stable developer diagnostics."
  @spec result_debug(gleam_result()) :: String.t()
  def result_debug(result) do
    call_gleam(:form_check_result_to_debug_string, [result])
  end

  @doc "Format a form-aware algebraic result with Gleam's stable developer diagnostics."
  @spec form_aware_result_debug(gleam_result()) :: String.t()
  def form_aware_result_debug(result) do
    call_gleam(:form_aware_algebraic_result_to_debug_string, [result])
  end

  @doc """
  Convert Math Prototype exact-form params into a Gleam exact-form config.

  The conversion intentionally whitelists known selector strings and returns
  structured field errors. It does not create atoms from user input and does not
  duplicate any Gleam exact-form classification behavior.
  """
  @spec config_from_form(map()) :: {:ok, gleam_config()} | {:error, [form_error()]}
  def config_from_form(params) when is_map(params) do
    params
    |> value("form_constraint", "none")
    |> normalize_selector()
    |> exact_form_config(params)
  end

  defp exact_form_config("none", _params), do: {:ok, :no_form_constraint}
  defp exact_form_config("", _params), do: {:ok, :no_form_constraint}
  defp exact_form_config("integer", _params), do: {:ok, :require_integer}
  defp exact_form_config("fraction", _params), do: {:ok, :require_fraction}
  defp exact_form_config("simplified_fraction", _params), do: {:ok, :require_simplified_fraction}

  defp exact_form_config("decimal", params) do
    params
    |> value("decimal_precision_rule", "any")
    |> normalize_selector()
    |> decimal_precision_config(params)
    |> case do
      {:ok, precision} -> {:ok, {:require_decimal, precision}}
      {:error, errors} -> {:error, errors}
    end
  end

  defp exact_form_config(_other, _params) do
    {:error,
     [
       error(
         "form_constraint",
         "must be none, integer, fraction, simplified_fraction, or decimal"
       )
     ]}
  end

  defp decimal_precision_config("any", _params), do: {:ok, :any_decimal_places}
  defp decimal_precision_config("", _params), do: {:ok, :any_decimal_places}

  defp decimal_precision_config("exactly", params) do
    decimal_places(params, :exactly)
  end

  defp decimal_precision_config("at_least", params) do
    decimal_places(params, :at_least)
  end

  defp decimal_precision_config("at_most", params) do
    decimal_places(params, :at_most)
  end

  defp decimal_precision_config(_other, _params) do
    {:error, [error("decimal_precision_rule", "must be any, exactly, at_least, or at_most")]}
  end

  defp decimal_places(params, rule) do
    case non_negative_int_field(params, "decimal_precision_count", 0) do
      {:ok, count} -> {:ok, {:decimal_places, rule, count}}
      {:error, errors} -> {:error, errors}
    end
  end

  defp non_negative_int_field(params, key, default) do
    case value(params, key, default) do
      value when is_integer(value) ->
        non_negative_int(value, key)

      value when is_binary(value) ->
        case Integer.parse(String.trim(value)) do
          {integer, ""} -> non_negative_int(integer, key)
          _ -> {:error, [error(key, "must be a non-negative integer")]}
        end

      value ->
        {:error, [error(key, "must be a non-negative integer, got #{inspect(value)}")]}
    end
  end

  defp non_negative_int(value, _key) when value >= 0, do: {:ok, value}

  defp non_negative_int(_value, key) do
    {:error, [error(key, "must be a non-negative integer")]}
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

  defp value(params, key, default) when is_map(params) do
    Map.get(params, key, default)
  end

  defp error(field, message), do: %{field: field, message: message}

  defp call_gleam(function, args) do
    Oli.Math.Gleam.call(:torus_math, function, args)
  end
end
