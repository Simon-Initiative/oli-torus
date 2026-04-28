defmodule Oli.InstructorDashboard.SummaryRecommendationAdapter do
  @moduledoc """
  Boundary for summary-tile recommendation interactions.

  The summary tile owns LiveView control flow and projection-ready rendering state.
  The concrete regenerate/feedback backend contract is expected to settle in
  `MER-5305`, so this behaviour keeps that integration isolated behind a narrow
  adapter.
  """

  @type scope ::
          %{container_type: :course}
          | %{container_type: :container, container_id: pos_integer()}

  @type context :: %{
          required(:section_id) => pos_integer(),
          required(:section_slug) => String.t(),
          required(:user_id) => pos_integer(),
          required(:scope_selector) => String.t(),
          required(:scope) => scope()
        }

  @type recommendation :: %{
          required(:status) => :ready | :thinking | :beginning_course | :unavailable,
          required(:label) => String.t(),
          required(:body) => String.t() | nil,
          required(:aria_label) => String.t(),
          required(:can_regenerate?) => boolean(),
          required(:can_submit_sentiment?) => boolean(),
          optional(:recommendation_id) => String.t() | nil
        }

  @type regenerate_result :: {:ok, %{recommendation: recommendation()}} | {:error, term()}
  @type sentiment :: :up | :down
  @type sentiment_result :: :ok | {:ok, %{recommendation: recommendation()}} | {:error, term()}
  @type additional_feedback_result :: {:ok, term()} | {:error, term()}

  @callback request_regenerate(context(), String.t()) :: regenerate_result()
  @callback submit_sentiment(context(), String.t(), sentiment()) :: sentiment_result()
  @callback submit_additional_feedback(context(), String.t(), String.t()) ::
              additional_feedback_result()
end
