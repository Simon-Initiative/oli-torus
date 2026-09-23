defmodule Oli.Delivery.SecureAssessments.Review do
  @moduledoc "Feedback-safe dependency serialization for finalized learner attempts."
  alias Oli.Delivery.SecureAssessments, as: Policy

  @doc "Filters persisted adaptive evaluation fields before serializing the initial review page."
  def page_state(state, true), do: state

  def page_state(state, false) do
    state
    |> Enum.reject(fn {key, _} ->
      key
      |> String.split(".")
      |> List.last()
      |> then(
        &(&1 in [
            "score",
            "outOf",
            "out_of",
            "tutorialScore",
            "currentQuestionScore",
            "feedback",
            "feedbacks",
            "correct",
            "isCorrect"
          ])
      )
    end)
    |> Map.new()
    |> project(false)
  end

  @doc "Determines feedback visibility for a bounded set of already-authorized activity attempts."
  def visibility(guids) do
    with {:ok, targets} <- Policy.resolve_attempts(:activity, guids),
         finalized <- Enum.filter(targets, &(&1.lifecycle_state in [:submitted, :evaluated])),
         {:ok, settings} <- Policy.review_settings(finalized) do
      Map.new(finalized, fn t ->
        {t.activity_attempt_guid,
         Oli.Delivery.Settings.show_feedback?(settings[t.resource_attempt_guid])}
      end)
    else
      _ -> Map.new(guids, &{&1, false})
    end
  end

  @doc "Removes feedback/score fields when visibility is delayed or disabled; submitted responses remain intact."
  def project(value, true), do: value
  def project(%DateTime{} = value, false), do: value
  def project(%NaiveDateTime{} = value, false), do: value
  def project(%_{} = value, false), do: value |> Map.from_struct() |> project(false)

  def project(value, false) when is_map(value) do
    Map.new(value, fn {key, child} ->
      cond do
        key in [
          :feedback,
          :score,
          :outOf,
          :out_of,
          :correct,
          "feedback",
          "score",
          "outOf",
          "out_of",
          "correct"
        ] ->
          {key, nil}

        key in [:response, "response"] ->
          {key, child}

        true ->
          {key, project(child, false)}
      end
    end)
  end

  def project(value, false) when is_list(value), do: Enum.map(value, &project(&1, false))
  def project(value, false), do: value
end
