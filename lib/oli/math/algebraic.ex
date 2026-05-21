defmodule Oli.Math.Algebraic do
  @moduledoc """
  Thin Elixir boundary around the public Gleam algebraic equivalence API.

  Gleam owns equivalence semantics, sampling, evaluation, tolerance, and result
  formatting. This module only translates prototype form values into generated
  Gleam config terms and calls the stable `torus_math` boundary.
  """

  @type gleam_config :: term()
  @type gleam_result :: term()
  @type form_error :: %{field: String.t(), message: String.t()}

  @doc "Return Gleam's default algebraic equivalence configuration."
  @spec default_config() :: gleam_config()
  def default_config do
    call_gleam(:default_algebraic_equivalence_config, [])
  end

  @doc "Check two raw expression strings through the public Gleam algebraic equivalence API."
  @spec check(String.t(), String.t(), gleam_config()) :: gleam_result()
  def check(expected, candidate, config) when is_binary(expected) and is_binary(candidate) do
    call_gleam(:check_algebraic_equivalence, [expected, candidate, config])
  end

  @doc "Format an algebraic result with Gleam's stable developer diagnostic formatter."
  @spec result_debug(gleam_result()) :: String.t()
  def result_debug(result) do
    call_gleam(:algebraic_equivalence_result_to_debug_string, [result])
  end

  @doc """
  Convert Math Prototype form params into a Gleam algebraic equivalence config.

  The returned errors describe form-shape and scalar parsing problems. Gleam
  remains responsible for final semantic validation of the generated config.
  """
  @spec config_from_form(map()) :: {:ok, gleam_config()} | {:error, [form_error()]}
  def config_from_form(params) when is_map(params) do
    base = default_config()

    allowed_variables_result = allowed_variables_from_form(params)
    sampling_result = sampling_from_form(params, elem(base, 4))
    tolerance_result = tolerance_from_form(params, elem(base, 6))
    domains_result = domains_from_form(params)

    errors =
      collect_errors([
        allowed_variables_result,
        sampling_result,
        tolerance_result,
        domains_result
      ])

    case errors do
      [] ->
        {:ok, allowed_variables} = allowed_variables_result
        {:ok, sampling} = sampling_result
        {:ok, tolerance} = tolerance_result
        {:ok, domains} = domains_result

        {:ok,
         {:algebraic_equivalence_config, allowed_variables, elem(base, 2), domains, sampling,
          elem(base, 5), tolerance, elem(base, 7), elem(base, 8)}}

      _ ->
        {:error, errors}
    end
  end

  defp allowed_variables_from_form(params) do
    case split_values(value(params, "allowed_variables", "")) do
      [] -> {:ok, :infer_from_expected}
      variables -> {:ok, {:explicit_allowed_variables, variables}}
    end
  end

  defp sampling_from_form(
         params,
         {:sampling_config, default_seed, default_count, default_attempts, default_special_points}
       ) do
    seed_result = int_field(params, "seed", default_seed)

    count_result =
      int_field(params, "desired_count", value(params, "sample_count", default_count))

    attempts_result = int_field(params, "max_attempts", default_attempts)
    special_points = boolean_field(params, "include_special_points", default_special_points)

    errors = collect_errors([seed_result, count_result, attempts_result, special_points])

    case errors do
      [] ->
        {:ok,
         {:sampling_config, unwrap(seed_result), unwrap(count_result), unwrap(attempts_result),
          unwrap(special_points)}}

      _ ->
        {:error, errors}
    end
  end

  defp tolerance_from_form(params, default_tolerance) do
    case params |> value("tolerance_type", "default") |> to_string() |> String.downcase() do
      "" ->
        {:ok, default_tolerance}

      "default" ->
        {:ok, default_tolerance}

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

  defp domains_from_form(params) do
    rows = value(params, "domains", value(params, "domain_rows", []))

    rows
    |> normalize_rows()
    |> Enum.with_index()
    |> Enum.reduce({[], []}, fn {row, index}, {domains, errors} ->
      case domain_from_form(row, index) do
        {:ok, nil} -> {domains, errors}
        {:ok, domain} -> {[domain | domains], errors}
        {:error, row_errors} -> {domains, errors ++ row_errors}
      end
    end)
    |> case do
      {domains, []} -> {:ok, {:domain_config, Enum.reverse(domains)}}
      {_domains, errors} -> {:error, errors}
    end
  end

  defp domain_from_form(row, index) when is_map(row) do
    name = row |> value("name", "") |> to_string() |> String.trim()

    cond do
      empty_domain_row?(row) ->
        {:ok, nil}

      name == "" ->
        {:error, [error(domain_field(index, "name"), "is required")]}

      true ->
        lower_result = bound_from_form(row, index, "lower", "lower_inclusive", true)
        upper_result = bound_from_form(row, index, "upper", "upper_inclusive", true)

        integer_only_result =
          boolean_field(row, "integer_only", false, domain_field(index, "integer_only"))

        exclusions_result = float_list_field(row, "exclusions", domain_field(index, "exclusions"))

        preferred_result =
          float_list_field(row, "preferred_values", domain_field(index, "preferred_values"))

        errors =
          collect_errors([
            lower_result,
            upper_result,
            integer_only_result,
            exclusions_result,
            preferred_result
          ])

        case errors do
          [] ->
            {:ok,
             {:variable_domain, name, unwrap(lower_result), unwrap(upper_result),
              unwrap(exclusions_result), unwrap(integer_only_result), unwrap(preferred_result)}}

          _ ->
            {:error, errors}
        end
    end
  end

  defp domain_from_form(_row, index) do
    {:error, [error(domain_field(index, "row"), "must be a domain row")]}
  end

  defp bound_from_form(row, index, value_key, inclusive_key, default_inclusive) do
    with {:ok, value} <- float_field(row, value_key, nil, domain_field(index, value_key)),
         {:ok, inclusive?} <-
           inclusivity_from_form(row, index, value_key, inclusive_key, default_inclusive) do
      {:ok, {bound_tag(inclusive?), value}}
    end
  end

  defp inclusivity_from_form(row, index, value_key, inclusive_key, default_inclusive) do
    bound_key = "#{value_key}_bound"

    cond do
      Map.has_key?(row, inclusive_key) ->
        boolean_field(row, inclusive_key, default_inclusive, domain_field(index, inclusive_key))

      Map.has_key?(row, bound_key) ->
        row
        |> value(bound_key, "")
        |> to_string()
        |> String.downcase()
        |> case do
          "inclusive" -> {:ok, true}
          "exclusive" -> {:ok, false}
          _ -> {:error, [error(domain_field(index, bound_key), "must be inclusive or exclusive")]}
        end

      true ->
        {:ok, default_inclusive}
    end
  end

  defp bound_tag(true), do: :inclusive
  defp bound_tag(false), do: :exclusive

  defp empty_domain_row?(row) do
    ["name", "lower", "upper", "exclusions", "preferred_values"]
    |> Enum.all?(fn key -> value(row, key, "") |> blank?() end)
  end

  defp normalize_rows(rows) when is_list(rows), do: rows

  defp normalize_rows(rows) when is_map(rows) do
    rows
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map(fn {_key, value} -> value end)
  end

  defp normalize_rows(_rows), do: []

  defp int_field(params, key, default, field \\ nil) do
    field = field || key

    case value(params, key, default) do
      value when is_integer(value) ->
        {:ok, value}

      value when is_binary(value) ->
        case Integer.parse(String.trim(value)) do
          {integer, ""} -> {:ok, integer}
          _ -> {:error, [error(field, "must be an integer")]}
        end

      value ->
        {:error, [error(field, "must be an integer, got #{inspect(value)}")]}
    end
  end

  defp float_field(params, key, default, field \\ nil) do
    field = field || key

    case value(params, key, default) do
      nil ->
        {:error, [error(field, "is required")]}

      value when is_integer(value) ->
        {:ok, value * 1.0}

      value when is_float(value) ->
        {:ok, value}

      value when is_binary(value) ->
        case Float.parse(String.trim(value)) do
          {float, ""} -> {:ok, float}
          _ -> {:error, [error(field, "must be a number")]}
        end

      value ->
        {:error, [error(field, "must be a number, got #{inspect(value)}")]}
    end
  end

  defp boolean_field(params, key, default, field \\ nil) do
    field = field || key

    case value(params, key, default) do
      value when is_boolean(value) ->
        {:ok, value}

      value when value in [0, 1] ->
        {:ok, value == 1}

      value when is_binary(value) ->
        case String.downcase(String.trim(value)) do
          value when value in ["true", "1", "on", "yes"] -> {:ok, true}
          value when value in ["false", "0", "off", "no", ""] -> {:ok, false}
          _ -> {:error, [error(field, "must be true or false")]}
        end

      value ->
        {:error, [error(field, "must be true or false, got #{inspect(value)}")]}
    end
  end

  defp float_list_field(params, key, field) do
    params
    |> value(key, "")
    |> split_values()
    |> Enum.reduce_while({:ok, []}, fn raw, {:ok, values} ->
      case Float.parse(raw) do
        {float, ""} -> {:cont, {:ok, [float | values]}}
        _ -> {:halt, {:error, [error(field, "must contain only numbers")]}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, errors} -> {:error, errors}
    end
  end

  defp split_values(value) when is_binary(value) do
    value
    |> String.split([",", "\n", "\r", "\t", " "], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp split_values(values) when is_list(values), do: Enum.map(values, &to_string/1)
  defp split_values(_value), do: []

  defp value(params, key, default) when is_map(params) do
    Map.get(params, key, default)
  end

  defp value(_params, _key, default), do: default

  defp collect_errors(results) do
    Enum.flat_map(results, fn
      {:ok, _value} -> []
      {:error, errors} -> errors
    end)
  end

  defp unwrap({:ok, value}), do: value

  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(nil), do: true
  defp blank?(_value), do: false

  defp domain_field(index, field), do: "domains[#{index}].#{field}"

  defp error(field, message), do: %{field: field, message: message}

  defp call_gleam(function, args) do
    Oli.Math.Gleam.call(:torus_math, function, args)
  end
end
