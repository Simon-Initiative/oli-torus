defmodule Oli.TorusDoc.Activities.MathExpressionSupport do
  @moduledoc false

  alias Oli.TorusDoc.ActivityConverter

  @math_expression_subtypes [
    "numeric",
    "algebraic",
    "number_with_units",
    "expression_with_units",
    "integer",
    "decimal",
    "fraction",
    "simplified_fraction",
    "latex_direct"
  ]

  def math_expression_subtypes, do: @math_expression_subtypes

  def math_expression_input?(%{"math_expression" => config}) when is_map(config), do: true

  def math_expression_input?(%{"input_type" => input_type}) when is_binary(input_type) do
    input_type in ["math_expression" | @math_expression_subtypes]
  end

  def math_expression_input?(_), do: false

  def subtype(%{"math_expression" => %{} = config}) do
    normalize_subtype(config["subtype"] || config["type"] || config["mode"])
  end

  def subtype(%{"input_type" => input_type}) when input_type in @math_expression_subtypes do
    {:ok, input_type}
  end

  def subtype(%{"input_type" => "math_expression"}), do: {:ok, "algebraic"}
  def subtype(_), do: {:ok, "algebraic"}

  def math_expression_model_config(config) when is_map(config) do
    config
    |> build_question_config()
    |> drop_empty()
  end

  def math_expression_model_config(_), do: %{}

  def item_config(subtype, config) do
    model_config = math_expression_model_config(config)

    %{"version" => 1, "type" => "math_expression", "subtype" => subtype}
    |> put_if_not_empty("config", model_config)
  end

  def responses(data, default_config, opts \\ []) do
    default_correct_feedback = Keyword.get(opts, :correct_feedback, "Correct")
    default_incorrect_feedback = Keyword.get(opts, :incorrect_feedback, "Incorrect")

    response_data =
      case data["responses"] do
        responses when is_list(responses) ->
          responses

        _ ->
          [%{"answer" => data["answer"] || "", "score" => 1, "correct" => true}]
      end

    with {:ok, responses} <-
           response_data
           |> Enum.reduce_while({:ok, []}, fn response, {:ok, acc} ->
             case response(response, default_config, default_correct_feedback) do
               {:ok, converted} -> {:cont, {:ok, [converted | acc]}}
               {:error, reason} -> {:halt, {:error, reason}}
             end
           end) do
      responses = Enum.reverse(responses)

      if Enum.any?(responses, &catch_all?/1) do
        {:ok, responses}
      else
        {:ok, responses ++ [catch_all_response(default_incorrect_feedback)]}
      end
    end
  end

  def response(%{"catch_all" => true} = data, _default_config, default_feedback) do
    {:ok,
     %{
       "id" => data["id"] || ActivityConverter.generate_id(),
       "matchConfig" => %{"version" => 1, "type" => "always"},
       "score" => data["score"] || 0,
       "correct" => data["correct"] || false,
       "feedback" => feedback(data, default_feedback)
     }}
  end

  def response(%{} = data, default_config, default_feedback) do
    response_config =
      default_config
      |> response_scoped_defaults()
      |> Map.merge(data["math_expression"] || data["match"] || %{})

    with {:ok, subtype} <- subtype(%{"math_expression" => response_config}) do
      expected = data["answer"] || data["expected"] || response_config["expected"] || ""

      {:ok,
       %{
         "id" => data["id"] || ActivityConverter.generate_id(),
         "matchConfig" => match_config(subtype, expected, response_config, data),
         "score" => data["score"] || 1,
         "correct" => data["correct"] || false,
         "feedback" => feedback(data, default_feedback)
       }}
    end
  end

  def response(_data, _default_config, _default_feedback) do
    {:error, "math expression responses must be maps"}
  end

  def catch_all_response(default_feedback) do
    %{
      "id" => ActivityConverter.generate_id(),
      "matchConfig" => %{"version" => 1, "type" => "always"},
      "score" => 0,
      "correct" => false,
      "feedback" => feedback(%{}, default_feedback)
    }
  end

  def input_ref(id) do
    %{"type" => "input_ref", "id" => id, "children" => [%{"text" => ""}]}
  end

  def stem_with_input_refs(stem_md, input_ids) do
    input_id_set = MapSet.new(input_ids)
    token_regex = ~r/\{\{\s*([A-Za-z0-9_-]+)\s*\}\}/

    children =
      token_regex
      |> Regex.split(stem_md, include_captures: true, trim: false)
      |> Enum.flat_map(fn segment ->
        case Regex.run(~r/^\{\{\s*([A-Za-z0-9_-]+)\s*\}\}$/, segment) do
          [_, id] ->
            if MapSet.member?(input_id_set, id) do
              [input_ref(id)]
            else
              [%{"text" => segment}]
            end

          _ ->
            if segment == "", do: [], else: [%{"text" => segment}]
        end
      end)

    referenced =
      Regex.scan(token_regex, stem_md)
      |> Enum.map(fn [_, id] -> id end)
      |> MapSet.new()

    missing = Enum.reject(input_ids, &MapSet.member?(referenced, &1))

    if missing == [] do
      {:ok,
       %{
         "id" => ActivityConverter.generate_id(),
         "content" => [
           %{
             "type" => "p",
             "children" => if(children == [], do: [%{"text" => ""}], else: children)
           }
         ]
       }}
    else
      {:error,
       "Multi-input stem_md must include placeholders for each input id. Missing: #{Enum.join(missing, ", ")}"}
    end
  end

  def preview_text(stem_md) do
    Regex.replace(~r/\{\{\s*([A-Za-z0-9_-]+)\s*\}\}/, stem_md, "_____")
  end

  defp normalize_subtype(subtype) when subtype in @math_expression_subtypes, do: {:ok, subtype}

  defp normalize_subtype("algebraic_expression"), do: {:ok, "algebraic"}
  defp normalize_subtype("number"), do: {:ok, "numeric"}
  defp normalize_subtype("units"), do: {:ok, "number_with_units"}
  defp normalize_subtype(nil), do: {:ok, "algebraic"}

  defp normalize_subtype(subtype) do
    {:error,
     "Unsupported math_expression subtype #{inspect(subtype)}. Expected one of: #{Enum.join(@math_expression_subtypes, ", ")}"}
  end

  defp numeric_value_field(operator)
       when operator in [
              "greater_than",
              "greater_than_or_equal",
              "less_than",
              "less_than_or_equal"
            ],
       do: "threshold"

  defp numeric_value_field(_operator), do: "expected"

  defp numeric_value_fields(operator, expected, config)
       when operator in ["between", "not_between"] do
    %{
      "lower" => config["lower"] || expected,
      "upper" => config["upper"] || expected,
      "bounds" => config["bounds"] || "inclusive"
    }
  end

  defp numeric_value_fields(operator, expected, _config),
    do: %{numeric_value_field(operator) => expected}

  defp match_config(subtype, expected, config, response_data) do
    %{
      "version" => 1,
      "type" => "math_expression",
      "math" => math_spec(subtype, expected, config, response_data)
    }
  end

  defp math_spec("numeric", expected, config, _response_data) do
    operator = config["operator"] || "equal"

    %{
      "mode" => "numeric",
      "operator" => operator,
      numeric_value_field(operator) => expected
    }
    |> put_if_not_empty("tolerance", tolerance(config))
  end

  defp math_spec("latex_direct", expected, _config, _response_data) do
    %{"mode" => "latex_direct", "expected" => expected}
  end

  defp math_spec("number_with_units", expected, %{"operator" => operator} = config, response_data) do
    %{
      "mode" => "unit_aware",
      "expected" => expected,
      "operator" => operator
    }
    |> Map.merge(numeric_value_fields(operator, expected, config))
    |> put_if_not_empty("unitPolicy", maybe_unit_policy(config))
    |> put_if_not_empty("tolerance", tolerance(config))
    |> maybe_put_match_wrong_units(config, response_data)
    |> maybe_put_match_missing_unit(config, response_data)
  end

  defp math_spec(subtype, expected, config, response_data)
       when subtype in ["number_with_units", "expression_with_units"] do
    %{
      "mode" => "unit_aware",
      "expected" => expected
    }
    |> put_if_not_empty("unitPolicy", maybe_unit_policy(config))
    |> put_if_not_empty("validation", validation(config))
    |> put_if_not_empty("sampling", sampling(config))
    |> put_if_not_empty("tolerance", tolerance(config))
    |> maybe_put_expression_match(subtype, config, response_data)
    |> maybe_put_match_wrong_units(config, response_data)
    |> maybe_put_match_missing_unit(config, response_data)
  end

  defp math_spec(subtype, expected, config, _response_data)
       when subtype in ["integer", "decimal", "fraction", "simplified_fraction"] do
    %{
      "mode" => "algebraic_equivalence",
      "expected" => expected,
      "form" => %{"type" => subtype}
    }
    |> put_if_not_empty("validation", validation(config))
    |> put_if_not_empty("sampling", sampling(config))
  end

  defp math_spec("algebraic", expected, config, response_data) do
    %{"mode" => "algebraic_equivalence", "expected" => expected}
    |> put_if_not_empty("validation", validation(config))
    |> put_if_not_empty("sampling", sampling(config))
    |> maybe_put_expression_match("algebraic", config, response_data)
  end

  defp build_question_config(config) do
    %{}
    |> put_if_not_empty("validation", validation(config))
    |> put_if_not_empty("sampling", sampling(config))
    |> put_if_not_empty("unitPolicy", maybe_unit_policy(config))
  end

  defp response_scoped_defaults(config) do
    Map.take(config, [
      "subtype",
      "type",
      "mode",
      "operator",
      "tolerance",
      "lower",
      "upper",
      "bounds",
      "sampling",
      "expression_match",
      "expressionMatch"
    ])
  end

  defp maybe_unit_policy(config) do
    if config["unit_policy"] || config["unitPolicy"] || config["units"] || config["unit"] do
      unit_policy(config)
    else
      %{}
    end
  end

  defp unit_policy(config) do
    policy = config["unit_policy"] || config["unitPolicy"] || %{}
    type = policy["type"] || config["unit_policy_type"] || "convertible_units"

    case type do
      "ignored" ->
        %{"type" => "ignored"}

      "strict_unit" ->
        %{"type" => "strict_unit", "unit" => policy["unit"] || config["unit"] || ""}

      type when type in ["accepted_units", "convertible_units"] ->
        units = policy["units"] || config["units"] || []
        %{"type" => type, "units" => units}

      _ ->
        %{"type" => type}
    end
  end

  defp validation(config) do
    validation = config["validation"] || %{}

    allowed_variables =
      validation["allowed_variables"] || validation["allowedVariables"] ||
        config["allowed_variables"]

    domains = validation["domains"] || config["domains"] || []

    %{}
    |> maybe_put("allowedVariables", allowed_variables)
    |> put_if_not_empty("domains", Enum.map(domains, &domain/1))
  end

  defp sampling(config) do
    sampling = config["sampling"] || %{}

    %{}
    |> maybe_put("seed", sampling["seed"] || config["seed"])
    |> maybe_put(
      "desiredCount",
      sampling["desiredCount"] || sampling["desired_count"] || sampling["sampleCount"] ||
        sampling["sample_count"] || config["desired_count"] || config["sample_count"]
    )
    |> maybe_put(
      "maxAttempts",
      sampling["maxAttempts"] || sampling["max_attempts"] || config["max_attempts"]
    )
    |> maybe_put(
      "includeSpecialPoints",
      sampling["includeSpecialPoints"] || sampling["include_special_points"] ||
        config["include_special_points"]
    )
  end

  defp domain(%{} = data) do
    name = data["name"] || data["variable"]

    %{
      "name" => name,
      "lower" => bound(data, "lower", true),
      "upper" => bound(data, "upper", true)
    }
    |> maybe_put("integerOnly", data["integer_only"] || data["integerOnly"])
    |> maybe_put("exclusions", data["exclusions"])
    |> maybe_put("preferredValues", data["preferred_values"] || data["preferredValues"])
  end

  defp domain(other), do: other

  defp bound(data, key, default_inclusive) do
    inclusive_key = "#{key}_inclusive"
    camel_key = "#{key}Inclusive"

    case data[key] do
      %{} = bound ->
        %{
          "value" => bound["value"],
          "inclusive" => Map.get(bound, "inclusive", default_inclusive)
        }

      value ->
        %{
          "value" => value,
          "inclusive" => Map.get(data, inclusive_key, Map.get(data, camel_key, default_inclusive))
        }
    end
  end

  defp tolerance(config) do
    case config["tolerance"] do
      %{"absolute" => absolute, "relative" => relative} ->
        %{"type" => "absolute_or_relative", "absolute" => absolute, "relative" => relative}

      other when is_map(other) ->
        other

      _ ->
        %{}
    end
  end

  defp maybe_put_match_wrong_units(math, config, response_data) do
    match_wrong_units =
      response_data["match_wrong_units"] || response_data["matchWrongUnits"] ||
        config["match_wrong_units"] || config["matchWrongUnits"]

    if match_wrong_units == true do
      Map.put(math, "matchWrongUnits", true)
    else
      math
    end
  end

  defp maybe_put_match_missing_unit(math, config, response_data) do
    match_missing_unit =
      response_data["match_missing_unit"] || response_data["matchMissingUnit"] ||
        config["match_missing_unit"] || config["matchMissingUnit"]

    if match_missing_unit == true do
      Map.put(math, "matchMissingUnit", true)
    else
      math
    end
  end

  defp maybe_put_expression_match(math, subtype, config, response_data)
       when subtype in ["algebraic", "expression_with_units"] do
    expression_match =
      response_data["expression_match"] || response_data["expressionMatch"] ||
        config["expression_match"] || config["expressionMatch"]

    case expression_match do
      "exact" -> Map.put(math, "expressionMatch", "exact")
      :exact -> Map.put(math, "expressionMatch", "exact")
      true -> Map.put(math, "expressionMatch", "exact")
      _ -> math
    end
  end

  defp maybe_put_expression_match(math, _subtype, _config, _response_data), do: math

  defp feedback(data, default_text) do
    text = data["feedback_md"] || data["feedback"] || default_text

    {:ok, feedback} = ActivityConverter.convert_feedback(text)

    case data["feedback_id"] do
      nil -> feedback
      id -> Map.put(feedback, "id", id)
    end
  end

  defp catch_all?(%{"matchConfig" => %{"type" => "always"}}), do: true
  defp catch_all?(_), do: false

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, []), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp put_if_not_empty(map, _key, value) when value in [nil, %{}, []], do: map
  defp put_if_not_empty(map, key, value), do: Map.put(map, key, value)

  defp drop_empty(map) do
    Enum.reduce(map, %{}, fn
      {_key, value}, acc when value in [nil, %{}, []] -> acc
      {key, value}, acc -> Map.put(acc, key, value)
    end)
  end
end
