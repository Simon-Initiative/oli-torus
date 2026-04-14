defmodule Oli.InstructorDashboard.SummaryRecommendationAdapter.Recommendations do
  @moduledoc """
  Summary-tile adapter backed by `Oli.InstructorDashboard.Recommendations`.
  """

  @behaviour Oli.InstructorDashboard.SummaryRecommendationAdapter

  alias Oli.Dashboard.OracleContext
  alias Oli.InstructorDashboard.Recommendations

  @impl true
  def request_regenerate(context, recommendation_id) do
    with {:ok, oracle_context} <- oracle_context(context),
         {:ok, _parsed_id} <- parse_recommendation_id(recommendation_id),
         {:ok, payload} <- Recommendations.regenerate_recommendation(oracle_context) do
      {:ok, %{recommendation: normalize_recommendation(payload)}}
    end
  end

  @impl true
  def submit_sentiment(context, recommendation_id, sentiment) do
    with {:ok, oracle_context} <- oracle_context(context),
         {:ok, parsed_id} <- parse_recommendation_id(recommendation_id),
         {:ok, feedback_type} <- feedback_type(sentiment),
         {:ok, _feedback} <-
           Recommendations.submit_feedback(oracle_context, parsed_id, %{feedback_type: feedback_type}),
         {:ok, payload} <- Recommendations.get_recommendation(oracle_context) do
      {:ok, %{recommendation: normalize_recommendation(payload)}}
    end
  end

  defp oracle_context(context) when is_map(context) do
    OracleContext.new(%{
      dashboard_context_type: :section,
      dashboard_context_id: Map.get(context, :section_id),
      user_id: Map.get(context, :user_id),
      scope: Map.get(context, :scope, %{})
    })
  end

  defp oracle_context(_context), do: {:error, :invalid_context}

  defp parse_recommendation_id(recommendation_id)
       when is_binary(recommendation_id) and recommendation_id != "" do
    case Integer.parse(recommendation_id) do
      {parsed, ""} when parsed > 0 -> {:ok, parsed}
      _ -> {:error, :invalid_recommendation}
    end
  end

  defp parse_recommendation_id(recommendation_id)
       when is_integer(recommendation_id) and recommendation_id > 0,
       do: {:ok, recommendation_id}

  defp parse_recommendation_id(_recommendation_id), do: {:error, :invalid_recommendation}

  defp feedback_type(:up), do: {:ok, :thumbs_up}
  defp feedback_type(:down), do: {:ok, :thumbs_down}
  defp feedback_type(_sentiment), do: {:error, :invalid_sentiment}

  defp normalize_recommendation(payload) when is_map(payload) do
    recommendation_id =
      payload
      |> Map.get(:recommendation_id, Map.get(payload, :id))
      |> normalize_recommendation_id()

    status =
      payload
      |> Map.get(:status, Map.get(payload, :state, :ready))
      |> normalize_status()

    feedback_summary = Map.get(payload, :feedback_summary, %{})
    sentiment_submitted? = Map.get(feedback_summary, :sentiment_submitted?, false)
    body = Map.get(payload, :body, Map.get(payload, :message))
    label = "AI Recommendation"

    %{
      status: status,
      recommendation_id: recommendation_id,
      label: label,
      body: body,
      aria_label: recommendation_aria_label(label, body),
      can_regenerate?: status in [:ready, :beginning_course] and is_binary(recommendation_id),
      can_submit_sentiment?:
        status in [:ready, :beginning_course] and is_binary(recommendation_id) and
          not sentiment_submitted?
    }
  end

  defp normalize_recommendation(_payload) do
    %{
      status: :unavailable,
      recommendation_id: nil,
      label: "AI Recommendation",
      body: nil,
      aria_label: "AI Recommendation",
      can_regenerate?: false,
      can_submit_sentiment?: false
    }
  end

  defp normalize_status(:generating), do: :thinking
  defp normalize_status(:thinking), do: :thinking
  defp normalize_status(:no_signal), do: :beginning_course
  defp normalize_status(:beginning_course), do: :beginning_course
  defp normalize_status(:beginning_course_state), do: :beginning_course
  defp normalize_status(:fallback), do: :ready
  defp normalize_status(:ready), do: :ready
  defp normalize_status(:expired), do: :unavailable
  defp normalize_status(:unavailable), do: :unavailable

  defp normalize_status(status) when is_binary(status) do
    case String.downcase(status) do
      "generating" -> :thinking
      "thinking" -> :thinking
      "no_signal" -> :beginning_course
      "beginning_course" -> :beginning_course
      "beginning_course_state" -> :beginning_course
      "fallback" -> :ready
      "ready" -> :ready
      "expired" -> :unavailable
      "unavailable" -> :unavailable
      _ -> :ready
    end
  end

  defp normalize_status(_status), do: :ready

  defp normalize_recommendation_id(recommendation_id)
       when is_integer(recommendation_id) and recommendation_id > 0,
       do: Integer.to_string(recommendation_id)

  defp normalize_recommendation_id(recommendation_id)
       when is_binary(recommendation_id) and recommendation_id != "",
       do: recommendation_id

  defp normalize_recommendation_id(_recommendation_id), do: nil

  defp recommendation_aria_label(label, body) when is_binary(body) and body != "",
    do: "#{label}: #{body}"

  defp recommendation_aria_label(label, _body), do: label
end
