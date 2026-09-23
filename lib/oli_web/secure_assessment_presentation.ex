defmodule OliWeb.SecureAssessmentPresentation do
  @moduledoc "Shared server-derived adaptive boundary for controller and LiveView renderers."
  alias Oli.Delivery.SecureAssessments.{Dependencies, Review}

  @doc "Projects adaptive state and navigation from the authenticated session and effective assessment policy."
  def adaptive_params(params, session, protected?, attempt, settings) do
    secure? = match?(%{scope: %{}}, session)
    assessment? = secure? or protected?

    state =
      case assessment? do
        true -> Dependencies.page_state(attempt, params.resourceAttemptState)
        false -> params.resourceAttemptState
      end

    params =
      Map.merge(params, %{
        secureDelivery: secure?,
        assessmentState: assessment?,
        showFeedback: Oli.Delivery.Settings.show_feedback?(settings),
        assessmentURL: "/sections/#{params.sectionSlug}/page/#{params.pageSlug}",
        resourceAttemptState:
          Review.page_state(
            state,
            not params.reviewMode or Oli.Delivery.Settings.show_feedback?(settings)
          )
      })

    case secure? do
      true ->
        Map.merge(params, %{
          overviewURL: nil,
          previousPageURL: nil,
          nextPageURL: nil,
          debuggerURL: nil,
          signoutUrl: nil,
          screenIdleTimeOutInSeconds: 0,
          isInstructor: false,
          isAuthor: false,
          isAdmin: false,
          previewMode: false,
          content: Map.delete(params.content, "backUrl")
        })

      false ->
        params
    end
  end
end
