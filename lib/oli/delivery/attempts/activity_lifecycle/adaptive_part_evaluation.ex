defmodule Oli.Delivery.Attempts.ActivityLifecycle.AdaptivePartEvaluation do
  @moduledoc false

  alias Oli.Activities.AdaptiveParts
  alias Oli.Activities.Model.Feedback
  alias Oli.Delivery.Attempts.ActivityLifecycle.RuleEvaluator
  alias Oli.Delivery.Attempts.Core.ClientEvaluation

  @type evaluation_summary :: %{
          client_evaluations: list(map()),
          score: float(),
          out_of: float(),
          correct: boolean()
        }

  def evaluate(activity_model, rules, scoring_context, state, part_inputs, part_attempts) do
    part_attempts_by_guid = Map.new(part_attempts, &{&1.attempt_guid, &1})
    part_attempts_by_part_id = Map.new(part_attempts, &{&1.part_id, &1})

    part_results =
      Enum.flat_map(part_inputs, fn part_input ->
        case resolve_part_attempt(part_input, part_attempts_by_guid, part_attempts_by_part_id) do
          nil ->
            []

          part_attempt ->
            part = AdaptiveParts.part_definition(activity_model, part_attempt.part_id)

            rule_scored_compatibility_part =
              AdaptiveParts.rule_scored_part?(activity_model, part_attempt.part_id)

            [
              %{
                attempt_guid: part_attempt.attempt_guid,
                part_id: part_attempt.part_id,
                input: part_input.input.input,
                rule_scored_compatibility_part: rule_scored_compatibility_part,
                result: evaluate_part(part, rules, scoring_context, state)
              }
            ]
        end
      end)

    total_score =
      part_results
      |> Enum.reduce(0.0, fn
        %{rule_scored_compatibility_part: true}, acc -> acc
        %{result: %{score: score}}, acc -> acc + score
      end)

    total_out_of =
      part_results
      |> Enum.reduce(0.0, fn
        %{rule_scored_compatibility_part: true}, acc -> acc
        %{result: %{out_of: out_of}}, acc -> acc + out_of
      end)

    screen_out_of = normalize_screen_out_of(scoring_context, total_out_of)

    screen_score =
      if total_out_of > 0 do
        screen_out_of * total_score / total_out_of
      else
        0.0
      end
      |> clamp(0.0, screen_out_of)

    %{
      client_evaluations:
        Enum.map(part_results, fn %{attempt_guid: attempt_guid, input: input, result: result} ->
          %{
            attempt_guid: attempt_guid,
            client_evaluation: %ClientEvaluation{
              input: input,
              score: result.score,
              out_of: result.out_of,
              feedback: result.feedback
            }
          }
        end),
      rule_scored_attempt_guids:
        part_results
        |> Enum.filter(& &1.rule_scored_compatibility_part)
        |> Enum.map(& &1.attempt_guid)
        |> MapSet.new(),
      score: screen_score,
      out_of: screen_out_of,
      correct: total_out_of > 0 and total_score >= total_out_of
    }
  end

  def override_rule_scored_client_evaluations(
        client_evaluations,
        part_attempts,
        rule_scored_attempt_guids,
        screen_score,
        screen_out_of,
        screen_result
      ) do
    if MapSet.size(rule_scored_attempt_guids) == 0 or not is_number(screen_out_of) or
         screen_out_of <= 0 do
      client_evaluations
    else
      feedback =
        default_feedback_for_rule_result(
          rule_feedback(screen_result),
          nil,
          screen_score,
          screen_out_of
        )

      attempt_guids =
        part_attempts
        |> Enum.map(& &1.attempt_guid)
        |> MapSet.new()

      Enum.map(client_evaluations, fn %{attempt_guid: attempt_guid} = evaluation ->
        cond do
          not MapSet.member?(attempt_guids, attempt_guid) ->
            evaluation

          not MapSet.member?(rule_scored_attempt_guids, attempt_guid) ->
            evaluation

          true ->
            %ClientEvaluation{} = client_evaluation = evaluation.client_evaluation

            Map.put(evaluation, :client_evaluation, %ClientEvaluation{
              client_evaluation
              | score: screen_score,
                out_of: screen_out_of,
                feedback: feedback
            })
        end
      end)
    end
  end

  defp resolve_part_attempt(part_input, part_attempts_by_guid, part_attempts_by_part_id) do
    Map.get(part_attempts_by_guid, part_input.attempt_guid) ||
      Map.get(part_attempts_by_part_id, part_input.attempt_guid)
  end

  defp evaluate_part(nil, _rules, _scoring_context, _state) do
    %{score: 0.0, out_of: 1.0, feedback: Feedback.from_text("Incorrect")}
  end

  defp evaluate_part(part, rules, scoring_context, state) do
    case evaluate_with_part_rules(part, rules, scoring_context, state) do
      {:ok, result} ->
        result

      :no_part_rules ->
        evaluate_with_native_correctness(part, state)
    end
  end

  defp evaluate_with_part_rules(part, rules, scoring_context, state) do
    part_rules =
      Enum.filter(rules, fn rule ->
        rule_references_only_part?(rule, Map.get(part, "id"))
      end)

    if part_rules == [] do
      :no_part_rules
    else
      part_out_of = normalize_part_out_of(part)

      part_scoring_context = %{
        scoring_context
        | maxScore: part_out_of,
          isManuallyGraded: false
      }

      case RuleEvaluator.do_eval(state, part_rules, part_scoring_context) do
        {:ok, %{"score" => score, "out_of" => out_of} = result} ->
          case normalize_number(score) do
            value when is_number(value) ->
              normalized_out_of =
                out_of
                |> normalize_number()
                |> case do
                  out_of_value when is_number(out_of_value) and out_of_value > 0 -> out_of_value
                  _ -> part_out_of
                end

              normalized_score = clamp(value, 0.0, normalized_out_of)

              feedback =
                result
                |> rule_feedback()
                |> default_feedback_for_rule_result(part, normalized_score, normalized_out_of)

              {:ok, %{score: normalized_score, out_of: normalized_out_of, feedback: feedback}}

            _ ->
              :no_part_rules
          end

        _ ->
          :no_part_rules
      end
    end
  end

  defp evaluate_with_native_correctness(part, state) do
    config = part_config(part)
    part_id = Map.get(part, "id")

    {score, out_of, feedback} =
      case Map.get(part, "type") do
        "janus-dropdown" ->
          correct_index = normalize_integer(Map.get(config, "correctAnswer"))
          selected_index = normalize_integer(stage_value(state, part_id, "selectedIndex"))

          correct =
            is_integer(correct_index) and is_integer(selected_index) and selected_index > 0 and
              selected_index == correct_index

          feedback =
            feedback_for_choice(config, correct)
            |> default_feedback_for_score(part, if(correct, do: 1.0, else: 0.0), 1.0)

          score = if(correct, do: 1.0, else: 0.0)
          {score, 1.0, feedback}

        "janus-mcq" ->
          selected =
            case stage_value(state, part_id, "selectedChoices") do
              values when is_list(values) and values != [] ->
                values
                |> Enum.map(&normalize_integer/1)
                |> Enum.reject(&is_nil/1)
                |> Enum.reject(&(&1 <= 0))
                |> MapSet.new()

              _ ->
                case normalize_integer(stage_value(state, part_id, "selectedChoice")) do
                  value when is_integer(value) and value > 0 -> MapSet.new([value])
                  _ -> MapSet.new()
                end
            end

          correct =
            if truthy?(Map.get(config, "anyCorrectAnswer")) do
              MapSet.size(selected) > 0
            else
              authored_correct_indexes(config)
              |> MapSet.equal?(selected)
            end

          feedback =
            feedback_for_choice(config, correct)
            |> default_feedback_for_score(part, if(correct, do: 1.0, else: 0.0), 1.0)

          score = if(correct, do: 1.0, else: 0.0)
          {score, 1.0, feedback}

        "janus-input-text" ->
          text = normalize_string(stage_value(state, part_id, "text"))
          answer = Map.get(config, "correctAnswer", %{})
          minimum_length = normalize_integer(Map.get(answer, "minimumLength")) || 0

          required_terms =
            answer
            |> Map.get("mustContain", "")
            |> split_terms()

          forbidden_terms =
            answer
            |> Map.get("mustNotContain", "")
            |> split_terms()

          normalized = String.downcase(text)

          correct =
            String.length(text) >= minimum_length and
              Enum.all?(required_terms, &String.contains?(normalized, String.downcase(&1))) and
              Enum.all?(forbidden_terms, &(not String.contains?(normalized, String.downcase(&1))))

          feedback =
            default_feedback_for_score(
              Map.get(config, if(correct, do: "correctFeedback", else: "incorrectFeedback")),
              part,
              if(correct, do: 1.0, else: 0.0),
              1.0
            )

          score = if(correct, do: 1.0, else: 0.0)
          {score, 1.0, feedback}

        "janus-multi-line-text" ->
          text_length = normalize_integer(stage_value(state, part_id, "textLength")) || 0
          minimum_length = normalize_integer(Map.get(config, "minimumLength")) || 0
          correct = text_length >= minimum_length

          feedback =
            default_feedback_for_score(
              Map.get(config, if(correct, do: "correctFeedback", else: "incorrectFeedback")),
              part,
              if(correct, do: 1.0, else: 0.0),
              1.0
            )

          score = if(correct, do: 1.0, else: 0.0)
          {score, 1.0, feedback}

        "janus-input-number" ->
          numeric_part_result(part, stage_value(state, part_id, "value"))

        "janus-slider" ->
          numeric_part_result(part, stage_value(state, part_id, "value"))

        "janus-text-slider" ->
          numeric_part_result(part, stage_value(state, part_id, "value"))

        "janus-hub-spoke" ->
          required_spokes =
            config
            |> Map.get("requiredSpoke")
            |> normalize_integer()
            |> case do
              value when is_integer(value) and value >= 0 -> value
              _ -> length(Map.get(config, "spokeItems", []))
            end

          completed =
            stage_value(state, part_id, "spokeCompleted")
            |> normalize_integer()
            |> Kernel.||(0)

          correct = completed >= required_spokes

          feedback =
            default_feedback_for_score(
              Map.get(config, if(correct, do: "correctFeedback", else: "incorrectFeedback")),
              part,
              if(correct, do: 1.0, else: 0.0),
              1.0
            )

          score = if(correct, do: 1.0, else: 0.0)
          {score, 1.0, feedback}

        "janus-fill-blanks" ->
          correct =
            case fill_blanks_correctness(part, state) do
              {:ok, value} ->
                value

              :fallback ->
                case stage_value(state, part_id, "correct") do
                  value when not is_nil(value) -> truthy?(value)
                  _ -> false
                end
            end

          feedback =
            default_feedback_for_score(
              Map.get(config, if(correct, do: "correctFeedback", else: "incorrectFeedback")),
              part,
              if(correct, do: 1.0, else: 0.0),
              1.0
            )

          score = if(correct, do: 1.0, else: 0.0)
          {score, 1.0, feedback}

        _ ->
          {0.0, 1.0, Feedback.from_text("Incorrect")}
      end

    %{score: score, out_of: out_of, feedback: feedback}
  end

  defp numeric_part_result(part, submitted_value) do
    config = part_config(part)
    answer = Map.get(config, "answer", %{})
    value = normalize_number(submitted_value)

    correct =
      if is_nil(value) do
        false
      else
        if truthy?(Map.get(answer, "range")) do
          correct_min = normalize_number(Map.get(answer, "correctMin"))
          correct_max = normalize_number(Map.get(answer, "correctMax"))

          is_number(correct_min) and is_number(correct_max) and value >= correct_min and
            value <= correct_max
        else
          correct_answer = normalize_number(Map.get(answer, "correctAnswer"))
          is_number(correct_answer) and value == correct_answer
        end
      end

    feedback =
      cond do
        correct ->
          Map.get(config, "correctFeedback")

        is_number(value) ->
          advanced_numeric_feedback(config, value) || Map.get(config, "incorrectFeedback")

        true ->
          Map.get(config, "incorrectFeedback")
      end
      |> default_feedback_for_score(part, if(correct, do: 1.0, else: 0.0), 1.0)

    score = if(correct, do: 1.0, else: 0.0)
    {score, 1.0, feedback}
  end

  defp advanced_numeric_feedback(config, value) do
    config
    |> Map.get("advancedFeedback", [])
    |> Enum.find_value(fn entry ->
      case Map.get(entry, "answer") do
        %{"answerType" => answer_type} = answer ->
          if advanced_numeric_match?(answer_type, answer, value),
            do: Map.get(entry, "feedback"),
            else: nil

        _ ->
          nil
      end
    end)
  end

  defp advanced_numeric_match?(6, answer, value) do
    correct_min = normalize_number(Map.get(answer, "correctMin"))
    correct_max = normalize_number(Map.get(answer, "correctMax"))

    is_number(correct_min) and is_number(correct_max) and value >= correct_min and
      value <= correct_max
  end

  defp advanced_numeric_match?(0, answer, value),
    do: value == normalize_number(Map.get(answer, "correctAnswer"))

  defp advanced_numeric_match?(2, answer, value),
    do: value > normalize_number(Map.get(answer, "correctAnswer"))

  defp advanced_numeric_match?(3, answer, value),
    do: value >= normalize_number(Map.get(answer, "correctAnswer"))

  defp advanced_numeric_match?(4, answer, value),
    do: value < normalize_number(Map.get(answer, "correctAnswer"))

  defp advanced_numeric_match?(5, answer, value),
    do: value <= normalize_number(Map.get(answer, "correctAnswer"))

  defp advanced_numeric_match?(_, _, _), do: false

  defp normalize_screen_out_of(scoring_context, total_out_of) do
    max_score =
      scoring_context
      |> Map.get(:maxScore, 0)
      |> normalize_number()
      |> Kernel.||(0.0)

    cond do
      max_score > 0 -> max_score
      total_out_of > 0 -> total_out_of
      true -> 0.0
    end
  end

  defp authored_correct_indexes(config) do
    config
    |> Map.get("correctAnswer", [])
    |> Enum.with_index(1)
    |> Enum.reduce(MapSet.new(), fn {correct?, index}, acc ->
      if truthy?(correct?), do: MapSet.put(acc, index), else: acc
    end)
  end

  defp feedback_for_choice(config, correct) do
    key = if(correct, do: "correctFeedback", else: "incorrectFeedback")
    Map.get(config, key)
  end

  defp default_feedback_for_rule_result(nil, part, score, out_of) do
    authored_feedback =
      case part do
        %{} ->
          cond do
            score >= out_of and out_of > 0 ->
              part
              |> part_config()
              |> Map.get("correctFeedback")

            score <= 0 ->
              part
              |> part_config()
              |> Map.get("incorrectFeedback")

            true ->
              nil
          end

        _ ->
          nil
      end

    default_feedback_for_score(authored_feedback, part, score, out_of)
  end

  defp default_feedback_for_rule_result(feedback, part, score, out_of),
    do: default_feedback_for_score(feedback, part, score, out_of)

  defp default_feedback_for_score(nil, _part, score, out_of),
    do: default_feedback_for_score("", nil, score, out_of)

  defp default_feedback_for_score(feedback, _part, score, out_of) when is_binary(feedback) do
    case String.trim(feedback) do
      "" ->
        cond do
          score >= out_of and out_of > 0 -> Feedback.from_text("Correct")
          score <= 0 -> Feedback.from_text("Incorrect")
          true -> Feedback.from_text("Partially correct")
        end

      text ->
        Feedback.from_text(text)
    end
  end

  defp default_feedback_for_score(feedback, _part, _score, _out_of) when is_map(feedback),
    do: feedback

  defp default_feedback_for_score(_feedback, _part, score, out_of),
    do: default_feedback_for_score("", nil, score, out_of)

  defp rule_feedback(%{"results" => results}) when is_list(results) do
    Enum.find_value(results, fn result ->
      result
      |> get_in(["params", "actions"])
      |> Kernel.||([])
      |> Enum.find_value(fn action ->
        if Map.get(action, "type") == "feedback",
          do: get_in(action, ["params", "feedback"]),
          else: nil
      end)
    end)
  end

  defp rule_feedback(_), do: nil

  defp rule_references_only_part?(rule, part_id) do
    stage_part_ids =
      rule
      |> field("conditions")
      |> Kernel.||(%{})
      |> collect_stage_part_ids()
      |> Enum.uniq()

    stage_part_ids == [part_id] and not truthy?(field(rule, "default"))
  end

  defp collect_stage_part_ids(%{"all" => conditions}) when is_list(conditions) do
    Enum.flat_map(conditions, &collect_stage_part_ids/1)
  end

  defp collect_stage_part_ids(%{"any" => conditions}) when is_list(conditions) do
    Enum.flat_map(conditions, &collect_stage_part_ids/1)
  end

  defp collect_stage_part_ids(%{"fact" => fact}) when is_binary(fact) do
    case Regex.run(~r/^stage\.([^.]+)\./, fact) do
      [_, part_id] -> [part_id]
      _ -> []
    end
  end

  defp collect_stage_part_ids(_), do: []

  defp stage_value(state, part_id, field) do
    Map.get(state, "stage.#{part_id}.#{field}")
  end

  defp fill_blanks_correctness(part, state) do
    config = part_config(part)
    part_id = Map.get(part, "id")
    elements = Map.get(config, "elements", [])

    if is_list(elements) and elements != [] do
      comparisons =
        elements
        |> Enum.with_index(1)
        |> Enum.map(fn {element, index} ->
          submission = normalize_string(stage_value(state, part_id, "Input #{index}.Value"))
          evaluate_fill_blank_element(submission, element, config)
        end)

      if comparisons != [] and Enum.any?(comparisons, & &1.has_authored_correct?) do
        {:ok, Enum.all?(comparisons, & &1.correct?)}
      else
        :fallback
      end
    else
      :fallback
    end
  end

  defp evaluate_fill_blank_element(submission, element, config) do
    correct = normalize_fill_blank_answer(Map.get(element, "correct"))

    alternates =
      element
      |> Map.get("alternateCorrect")
      |> normalize_fill_blank_alternates(Map.get(config, "alternateCorrectDelimiter"))

    accepted_answers =
      [correct | alternates]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    %{
      has_authored_correct?: accepted_answers != [],
      correct?:
        submission != "" and
          fill_blank_answer_match?(
            submission,
            accepted_answers,
            truthy?(Map.get(config, "caseSensitiveAnswers", true))
          )
    }
  end

  defp fill_blank_answer_match?(_submission, [], _case_sensitive), do: false

  defp fill_blank_answer_match?(submission, accepted_answers, true),
    do: Enum.any?(accepted_answers, &(&1 == submission))

  defp fill_blank_answer_match?(submission, accepted_answers, false) do
    normalized_submission = String.downcase(submission)
    Enum.any?(accepted_answers, &(String.downcase(&1) == normalized_submission))
  end

  defp normalize_fill_blank_answer(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_fill_blank_answer(value) when is_number(value), do: to_string(value)
  defp normalize_fill_blank_answer(_), do: nil

  defp normalize_fill_blank_alternates(values, _delimiter) when is_list(values) do
    values
    |> Enum.map(&normalize_fill_blank_answer/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_fill_blank_alternates(values, delimiter) when is_binary(values) do
    effective_delimiter = if is_binary(delimiter) and delimiter != "", do: delimiter, else: ","

    values
    |> String.split(effective_delimiter)
    |> Enum.map(&normalize_fill_blank_answer/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_fill_blank_alternates(_values, _delimiter), do: []

  defp part_config(part) do
    Map.get(part, "custom", part)
  end

  defp normalize_part_out_of(part) do
    authored_out_of =
      part
      |> Map.get("outOf")
      |> normalize_number()

    custom_out_of =
      part
      |> part_config()
      |> Map.get("maxScore")
      |> normalize_number()

    cond do
      is_number(authored_out_of) and authored_out_of > 0 -> authored_out_of
      is_number(custom_out_of) and custom_out_of > 0 -> custom_out_of
      true -> 1.0
    end
  end

  defp field(rule, key) when is_map(rule) do
    Map.get(rule, key) || Map.get(rule, String.to_atom(key))
  end

  defp split_terms(text) when is_binary(text) do
    text
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp split_terms(_), do: []

  defp truthy?(value) when value in [true, "true", 1, 1.0], do: true
  defp truthy?(_), do: false

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_float(value), do: trunc(value)

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} -> parsed
      _ -> nil
    end
  end

  defp normalize_integer(_), do: nil

  defp normalize_number(value) when is_integer(value), do: value * 1.0
  defp normalize_number(value) when is_float(value), do: value

  defp normalize_number(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {parsed, ""} -> parsed
      _ -> nil
    end
  end

  defp normalize_number(_), do: nil

  defp normalize_string(nil), do: ""
  defp normalize_string(value) when is_binary(value), do: value
  defp normalize_string(value), do: to_string(value)

  defp clamp(value, min_value, _max_value) when value < min_value, do: min_value
  defp clamp(value, _min_value, max_value) when value > max_value, do: max_value
  defp clamp(value, _min_value, _max_value), do: value
end
