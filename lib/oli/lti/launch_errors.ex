defmodule Oli.Lti.LaunchErrors do
  @moduledoc """
  Stable user-facing classifications for LTI launch failures.
  """

  @type classification ::
          :consumed_state
          | :expired_state
          | :independent_learner_not_allowed
          | :invalid_deployment
          | :invalid_registration
          | :launch_handler_failure
          | :missing_state
          | :mismatched_state
          | :post_auth_landing_failure
          | :storage_blocked
          | :validation_failure
          | :unknown_failure

  @spec details(classification()) :: %{
          title: String.t(),
          message: String.t(),
          guidance: String.t()
        }
  def details(classification) do
    case classification do
      :consumed_state ->
        %{
          title: "This Launch Request Was Already Used",
          message: "Torus has already finished processing this LMS launch.",
          guidance: "Return to your LMS and launch Torus again."
        }

      :expired_state ->
        %{
          title: "This Launch Request Expired",
          message: "The sign-in handshake took too long and is no longer valid.",
          guidance: "Return to your LMS and launch Torus again."
        }

      :independent_learner_not_allowed ->
        %{
          title: "Course Must Be Accessed Through the LMS",
          message: "This course is configured for LMS launches only.",
          guidance: "Return to your LMS and relaunch the course from there."
        }

      :invalid_deployment ->
        %{
          title: "LTI Deployment Is Not Configured",
          message: "The LMS launch reached Torus, but the deployment is not registered here yet.",
          guidance: "Ask your LMS or Torus administrator to verify the deployment configuration."
        }

      :invalid_registration ->
        %{
          title: "LTI Registration Is Not Configured",
          message: "The LMS launch could not be matched to a Torus registration.",
          guidance:
            "Ask your LMS or Torus administrator to verify the registration configuration."
        }

      :launch_handler_failure ->
        %{
          title: "Launch Completed but Course Access Failed",
          message: "Torus could not finish preparing the course access for this launch.",
          guidance: "Try the launch again. If the issue persists, contact support."
        }

      :missing_state ->
        %{
          title: "Launch State Was Missing",
          message:
            "Torus did not receive the state needed to complete the LMS sign-in handshake.",
          guidance:
            "Allow cookies for this launch if your browser permits it, or ask your LMS administrator to configure Torus to open in a new tab."
        }

      :mismatched_state ->
        %{
          title: "Launch State Did Not Match",
          message: "Torus received a different launch state than it expected for this request.",
          guidance: "Return to your LMS and relaunch the course."
        }

      :post_auth_landing_failure ->
        %{
          title: "Course Landing Could Not Be Resolved",
          message:
            "Torus authenticated the launch but could not finish landing you in the course.",
          guidance: "Try the launch again. If the issue persists, contact support."
        }

      :storage_blocked ->
        %{
          title: "Browser Privacy Settings Blocked the Launch",
          message: "Torus could not complete the sign-in handshake for this embedded LMS launch.",
          guidance:
            "Allow cookies for this launch if your browser permits it, or ask your LMS administrator to configure Torus to open in a new tab."
        }

      :validation_failure ->
        %{
          title: "LTI Launch Could Not Be Validated",
          message: "The LMS launch request was not accepted by Torus.",
          guidance: "Ask your LMS or Torus administrator to verify the launch configuration."
        }

      :unknown_failure ->
        %{
          title: "LTI Launch Failed",
          message: "Torus could not complete this LMS launch.",
          guidance: "Try the launch again. If the issue persists, contact support."
        }
    end
  end
end
