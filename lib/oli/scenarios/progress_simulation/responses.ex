defmodule Oli.Scenarios.ProgressSimulation.Responses do
  @moduledoc """
  Builds UI-valid native activity responses from the current transformed model.

  A requested correctness probability selects an answer strategy; Torus evaluation
  remains authoritative for the resulting score.
  """

  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Delivery.Evaluation.{EvaluationContext, Rule}
  alias Oli.Scenarios.ProgressSimulation.Policy

  @supported_activity_types [
    "oli_multiple_choice",
    "oli_ordering",
    "oli_check_all_that_apply",
    "oli_short_answer",
    "oli_multi_input"
  ]

  @doc "Returns the native activity slugs supported by the response adapters."
  @spec supported_activity_types() :: [String.t()]
  def supported_activity_types, do: @supported_activity_types

  @doc "Builds a valid response for a specific attempt part, or reports unsupported content."
  @spec for_part(String.t() | nil, String.t(), map(), number(), term()) ::
          {:ok, StudentInput.t()} | {:unsupported, term()}
  def for_part(slug, part_id, activity, correctness, seed_key)
      when slug in @supported_activity_types do
    content = transformed_content(activity)

    with parts when is_list(parts) <- get_in(content, ["authoring", "parts"]),
         part when not is_nil(part) <- Enum.find(parts, &(&1["id"] == part_id)),
         responses when is_list(responses) and responses != [] <- part["responses"] do
      correct? = Policy.sample({seed_key, :correctness}) < correctness

      case response_value(slug, content, part_id, responses, correct?, seed_key) do
        nil -> {:unsupported, {:response_rule, slug, part_id}}
        value -> {:ok, %StudentInput{input: value}}
      end
    else
      _ -> {:unsupported, {:activity_model, slug, part_id}}
    end
  end

  def for_part(slug, _part_id, _activity, _correctness, _seed_key),
    do: {:unsupported, {:activity_type, slug || "unknown"}}

  defp transformed_content(%{transformed_model: transformed}) when is_map(transformed),
    do: transformed

  defp transformed_content(%{revision: revision}), do: transformed_content(revision)
  defp transformed_content(%{content: content}) when is_map(content), do: content
  defp transformed_content(content) when is_map(content), do: content

  defp response_value(
         "oli_multi_input" = slug,
         %{"inputs" => inputs} = content,
         part_id,
         responses,
         correct?,
         seed_key
       )
       when is_list(inputs) do
    case Enum.find(inputs, &(&1["partId"] == part_id)) do
      %{"inputType" => "dropdown"} = input ->
        dropdown_response(content, input, responses, correct?)

      _ ->
        native_response_value(slug, content, part_id, responses, correct?, seed_key)
    end
  end

  defp response_value(slug, content, part_id, responses, correct?, seed_key),
    do: native_response_value(slug, content, part_id, responses, correct?, seed_key)

  defp native_response_value(slug, content, part_id, responses, correct?, seed_key) do
    selected = select_response(responses, correct?, seed_key)

    case {slug, correct?, selected} do
      {_slug, true, response} ->
        parse_supported_rule(response && response["rule"])

      {"oli_multiple_choice", false, _} ->
        incorrect_choice(content, responses)

      {"oli_ordering", false, _} ->
        incorrect_order(content, responses)

      {"oli_check_all_that_apply", false, _} ->
        incorrect_subset(content, responses)

      {"oli_short_answer", false, _} ->
        incorrect_text(responses, seed_key)

      {"oli_multi_input", false, _} ->
        incorrect_multi_input(content, part_id, responses, seed_key)

      _ ->
        nil
    end
  end

  defp dropdown_response(%{"choices" => choices}, %{"choiceIds" => ids}, responses, correct?)
       when is_list(choices) and is_list(ids) do
    with {:ok, rules} <- supported_correct_rules(responses) do
      available = MapSet.new(choices, & &1["id"])

      Enum.find(ids, fn id ->
        is_binary(id) and MapSet.member?(available, id) and
          case correct? do
            true -> Enum.any?(rules, &(evaluate_rule(&1, id) == {:ok, true}))
            false -> Enum.all?(rules, &(evaluate_rule(&1, id) == {:ok, false}))
          end
      end)
    else
      :error -> nil
    end
  end

  defp dropdown_response(_content, _input, _responses, _correct?), do: nil

  defp select_response(responses, correct?, seed_key) do
    candidates =
      Enum.filter(responses, fn response ->
        positive? = number(response["score"]) > 0
        positive? == correct?
      end)

    case candidates do
      [] -> nil
      values -> Enum.at(values, trunc(Policy.sample({seed_key, :response}) * length(values)))
    end
  end

  defp incorrect_choice(%{"choices" => choices}, responses) when is_list(choices) do
    with {:ok, values} <- supported_correct_rule_values(responses) do
      correct = MapSet.new(values)

      Enum.find_value(choices, fn choice ->
        id = choice["id"]
        if is_binary(id) and not MapSet.member?(correct, id), do: id
      end)
    else
      :error -> nil
    end
  end

  defp incorrect_choice(_content, _responses), do: nil

  defp incorrect_order(%{"choices" => choices}, responses) when is_list(choices) do
    ids = Enum.map(choices, & &1["id"]) |> Enum.filter(&is_binary/1)
    reversed = ids |> Enum.reverse() |> Enum.join(" ")
    rotated = ids |> rotate() |> Enum.join(" ")

    with {:ok, correct_values} <- supported_correct_rule_values(responses) do
      cond do
        length(ids) < 2 -> nil
        reversed not in correct_values -> reversed
        rotated not in correct_values -> rotated
        true -> nil
      end
    else
      :error -> nil
    end
  end

  defp incorrect_order(_content, _responses), do: nil

  defp incorrect_subset(%{"choices" => choices}, responses) when is_list(choices) do
    ids = Enum.map(choices, & &1["id"]) |> Enum.filter(&is_binary/1)

    with {:ok, [first | _]} <- supported_correct_rule_values(responses) do
      correct = split_values(first)

      case Enum.find(ids, &(&1 not in correct)) do
        nil when ids == [] -> nil
        nil -> ids |> List.delete_at(-1) |> Enum.join(" ")
        id -> id
      end
    else
      _ -> nil
    end
  end

  defp incorrect_subset(_content, _responses), do: nil

  defp incorrect_text(responses, seed_key) do
    with {:ok, rules} <- supported_correct_rules(responses) do
      incorrect_candidate(rules, seed_key, :text)
    else
      :error -> nil
    end
  end

  defp incorrect_multi_input(%{"inputs" => inputs}, part_id, responses, seed_key)
       when is_list(inputs) do
    input_type =
      Enum.find_value(inputs, fn input ->
        if input["partId"] == part_id, do: input["inputType"]
      end)

    with {:ok, rules} <- supported_correct_rules(responses) do
      incorrect_candidate(rules, seed_key, input_type)
    else
      :error -> nil
    end
  end

  defp incorrect_multi_input(_content, _part_id, _responses, _seed_key), do: nil

  defp incorrect_candidate(rules, seed_key, input_type) do
    hash = :erlang.phash2({seed_key, :incorrect}, 1_000_000_000)

    candidates =
      case input_type do
        "numeric" -> ["-#{hash + 1}", "#{hash + 1}.123456789", "-999999999999"]
        _ -> ["__oli_incorrect_#{hash}__", "__no_match_#{hash + 1}__", ""]
      end

    Enum.find(candidates, fn candidate ->
      Enum.all?(rules, &(evaluate_rule(&1, candidate) == {:ok, false}))
    end)
  end

  defp supported_correct_rules(responses) do
    rules =
      responses
      |> Enum.filter(&(number(&1["score"]) > 0))
      |> Enum.map(& &1["rule"])

    case rules != [] and
           Enum.all?(rules, &(is_binary(&1) and is_binary(parse_supported_rule(&1)))) do
      true -> {:ok, rules}
      false -> :error
    end
  end

  defp evaluate_rule(rule, input) do
    context = %EvaluationContext{
      resource_attempt_number: 1,
      activity_attempt_number: 1,
      part_attempt_number: 1,
      part_attempt_guid: "scenario",
      activity_attempt_guid: "scenario",
      page_id: 0,
      input: input
    }

    Rule.parse_and_evaluate(rule, context)
  end

  defp supported_correct_rule_values(responses) do
    values =
      responses
      |> Enum.filter(&(number(&1["score"]) > 0))
      |> Enum.map(&parse_supported_rule(&1["rule"]))

    case values != [] and Enum.all?(values, &is_binary/1) do
      true -> {:ok, values}
      false -> :error
    end
  end

  defp parse_supported_rule(rule) when is_binary(rule) do
    Enum.find_value(
      [~r/^input (?:like|contains|=) \{([^}]+)\}$/],
      fn pattern ->
        case Regex.run(pattern, rule) do
          [_match, ".*"] ->
            nil

          [_match, response] ->
            case evaluate_rule(rule, response) do
              {:ok, true} -> response
              _ -> nil
            end

          _ ->
            nil
        end
      end
    )
  end

  defp parse_supported_rule(_), do: nil

  defp rotate([first | rest]), do: rest ++ [first]
  defp rotate(values), do: values

  defp split_values(nil), do: []
  defp split_values(value), do: String.split(value)

  defp number(value) when is_number(value), do: value
  defp number(_), do: 0
end
