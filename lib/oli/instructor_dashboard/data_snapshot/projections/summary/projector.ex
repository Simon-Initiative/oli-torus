defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Summary.Projector do
  @moduledoc false

  @recommendation_label "AI Recommendation"
  @proficiency_weights %{"Low" => 30.0, "Medium" => 60.0, "High" => 90.0}

  @spec build(map(), keyword()) :: map()
  def build(optional_oracles, opts \\ []) when is_map(optional_oracles) do
    progress_rows = Map.get(optional_oracles, :oracle_instructor_progress_proficiency, [])

    objective_rows =
      optional_oracles
      |> Map.get(:oracle_instructor_objectives_proficiency, %{})
      |> Map.get(:objective_rows, [])

    grades_rows =
      optional_oracles
      |> Map.get(:oracle_instructor_grades, %{})
      |> Map.get(:grades, [])

    scope_resources = Map.get(optional_oracles, :oracle_instructor_scope_resources, %{})
    oracle_statuses = Keyword.get(opts, :oracle_statuses, %{})
    recommendation_oracle_keys = Keyword.get(opts, :recommendation_oracle_keys, [])

    recommendation_source =
      recommendation_source(optional_oracles, oracle_statuses, recommendation_oracle_keys)

    cards =
      [
        class_proficiency_card(objective_rows),
        assessment_score_card(grades_rows),
        progress_card(progress_rows)
      ]
      |> Enum.reject(&is_nil/1)

    %{
      cards: cards,
      recommendation:
        recommendation_view_model(
          recommendation_source.payload,
          recommendation_source.status
        ),
      layout: layout_metadata(cards),
      available_slots:
        available_slots(progress_rows, objective_rows, grades_rows, recommendation_source),
      missing_slots:
        missing_slots(progress_rows, objective_rows, grades_rows, recommendation_source),
      scope_label: Map.get(scope_resources, :scope_label),
      course_title: Map.get(scope_resources, :course_title)
    }
  end

  defp progress_card([]), do: nil

  defp progress_card(progress_rows) do
    progress_rows
    |> Enum.map(&normalize_pct(Map.get(&1, :progress_pct)))
    |> average()
    |> card(:average_student_progress, "Average Student Progress")
  end

  defp class_proficiency_card(objective_rows) do
    objective_rows
    |> aggregate_objective_proficiency()
    |> card(:average_class_proficiency, "Average Class Proficiency")
  end

  defp assessment_score_card(grades_rows) do
    grades_rows
    |> Enum.map(&normalize_pct(Map.get(&1, :mean)))
    |> Enum.reject(&is_nil/1)
    |> average()
    |> card(:average_assessment_score, "Average Assessment Score")
  end

  defp card(nil, _id, _label), do: nil

  defp card(value, id, label) do
    %{
      id: id,
      label: label,
      value_number: value,
      value_text: percent_text(value),
      tooltip_key: id,
      status: :ready
    }
  end

  defp layout_metadata(cards) do
    visible_card_count = length(cards)

    %{
      visible_card_count: visible_card_count,
      card_grid_class: grid_class(visible_card_count)
    }
  end

  defp grid_class(1), do: "grid-cols-1"
  defp grid_class(2), do: "grid-cols-2"
  defp grid_class(3), do: "grid-cols-3"
  defp grid_class(_count), do: "grid-cols-1"

  defp available_slots(progress_rows, objective_rows, grades_rows, recommendation_source) do
    []
    |> maybe_add_slot(progress_rows != [], :progress)
    |> maybe_add_slot(objective_rows != [], :proficiency_progress)
    |> maybe_add_slot(grades_rows != [], :assessment)
    |> maybe_add_slot(recommendation_available?(recommendation_source), :recommendation)
  end

  defp missing_slots(progress_rows, objective_rows, grades_rows, recommendation_source) do
    []
    |> maybe_add_slot(progress_rows == [], :progress)
    |> maybe_add_slot(objective_rows == [], :proficiency_progress)
    |> maybe_add_slot(grades_rows == [], :assessment)
    |> maybe_add_slot(not recommendation_available?(recommendation_source), :recommendation)
  end

  defp maybe_add_slot(slots, true, slot), do: slots ++ [slot]
  defp maybe_add_slot(slots, false, _slot), do: slots

  defp recommendation_source(optional_oracles, oracle_statuses, recommendation_oracle_keys) do
    recommendation_oracle_keys
    |> Enum.reduce_while(%{payload: nil, status: nil}, fn oracle_key, _acc ->
      payload = Map.get(optional_oracles, oracle_key)
      status = get_in(oracle_statuses, [oracle_key, :status])

      if is_nil(payload) and is_nil(status) do
        {:cont, %{payload: nil, status: nil}}
      else
        {:halt, %{payload: payload, status: status}}
      end
    end)
  end

  defp recommendation_view_model(payload, oracle_status) do
    payload
    |> normalize_recommendation_payload(oracle_status)
    |> then(fn recommendation ->
      %{
        status: recommendation.status,
        recommendation_id: recommendation.recommendation_id,
        label: @recommendation_label,
        body: recommendation.body,
        aria_label: recommendation_aria_label(recommendation.body),
        can_regenerate?: recommendation.can_regenerate?,
        can_submit_sentiment?: recommendation.can_submit_sentiment?
      }
    end)
  end

  defp normalize_recommendation_payload(nil, oracle_status) do
    case oracle_status do
      status when status in [:loading, :pending, :requested, :in_progress] ->
        %{
          status: :thinking,
          recommendation_id: nil,
          body: nil,
          can_regenerate?: false,
          can_submit_sentiment?: false
        }

      _ ->
        %{
          status: :unavailable,
          recommendation_id: nil,
          body: nil,
          can_regenerate?: false,
          can_submit_sentiment?: false
        }
    end
  end

  defp normalize_recommendation_payload(%{recommendation: recommendation}, oracle_status)
       when is_map(recommendation) do
    normalize_recommendation_payload(recommendation, oracle_status)
  end

  defp normalize_recommendation_payload(payload, _oracle_status) when is_map(payload) do
    status =
      payload
      |> Map.get(:status, :ready)
      |> normalize_recommendation_status()

    recommendation_id =
      Map.get(payload, :recommendation_id) ||
        Map.get(payload, :id)

    body =
      Map.get(payload, :body) ||
        Map.get(payload, :message) ||
        Map.get(payload, :text)

    %{
      status: status,
      recommendation_id: recommendation_id,
      body: body,
      can_regenerate?: Map.get(payload, :can_regenerate?, status in [:ready, :beginning_course]),
      can_submit_sentiment?:
        Map.get(payload, :can_submit_sentiment?, status in [:ready, :beginning_course])
    }
  end

  defp normalize_recommendation_payload(_payload, oracle_status),
    do: normalize_recommendation_payload(nil, oracle_status)

  defp normalize_recommendation_status(status) when status in [:ready, :thinking, :unavailable],
    do: status

  defp normalize_recommendation_status(status)
       when status in [:beginning_course, :beginning_course_state],
       do: :beginning_course

  defp normalize_recommendation_status(status) when is_binary(status) do
    case String.downcase(status) do
      "thinking" -> :thinking
      "beginning_course" -> :beginning_course
      "beginning_course_state" -> :beginning_course
      "unavailable" -> :unavailable
      _ -> :ready
    end
  end

  defp normalize_recommendation_status(_status), do: :ready

  defp recommendation_available?(%{payload: payload, status: status}) do
    not is_nil(payload) or status in [:loading, :pending, :requested, :in_progress]
  end

  defp recommendation_aria_label(nil), do: @recommendation_label
  defp recommendation_aria_label(body), do: "#{@recommendation_label}: #{body}"

  defp aggregate_objective_proficiency(objective_rows) do
    objective_rows
    |> Enum.reduce({0.0, 0}, fn objective_row, {weighted_sum, total} ->
      proficiency_distribution =
        objective_row
        |> Map.get(:proficiency_distribution)
        |> normalize_proficiency_distribution()

      Enum.reduce(proficiency_distribution, {weighted_sum, total}, fn
        {label, count}, {current_weighted_sum, current_total} ->
          case Map.fetch(@proficiency_weights, label) do
            {:ok, weight} when is_number(count) and count > 0 ->
              {current_weighted_sum + weight * count, current_total + count}

            _ ->
              {current_weighted_sum, current_total}
          end
      end)
    end)
    |> case do
      {_weighted_sum, 0} -> nil
      {weighted_sum, total} -> weighted_sum / total
    end
  end

  defp normalize_proficiency_distribution(proficiency_distribution)
       when proficiency_distribution in [%{}, nil],
       do: %{}

  defp normalize_proficiency_distribution(proficiency_distribution) do
    Enum.into(proficiency_distribution, %{}, fn {label, count} ->
      {normalize_proficiency_label(label), count}
    end)
  end

  defp normalize_proficiency_label(label) when is_binary(label) do
    case label |> String.trim() |> String.downcase() do
      "low" -> "Low"
      "medium" -> "Medium"
      "high" -> "High"
      "not enough data" -> "Not enough data"
      other -> other
    end
  end

  defp normalize_proficiency_label(label), do: label

  defp average([]), do: nil
  defp average(values), do: Enum.sum(values) / length(values)

  defp normalize_pct(nil), do: nil

  defp normalize_pct(value) when is_integer(value) or is_float(value) do
    cond do
      value <= 1.0 -> Float.round(value * 100.0, 1)
      true -> Float.round(value * 1.0, 1)
    end
  end

  defp normalize_pct(_value), do: nil

  defp percent_text(value) when is_number(value) do
    rounded = Float.round(value * 1.0, 1)

    if rounded == trunc(rounded) do
      "#{trunc(rounded)}%"
    else
      "#{rounded}%"
    end
  end
end
