defmodule Oli.Lti.LaunchErrors do
  @moduledoc """
  Stable user-facing classification and copy for LTI launch failures.
  """

  @type classification ::
          :embedded_storage_blocked
          | :expired_state
          | :independent_learner_not_allowed
          | :invalid_deployment
          | :invalid_registration
          | :invalid_state
          | :launch_handler_failure
          | :launch_validation_failed
          | :missing_context
          | :missing_state
          | :mismatched_state
          | :recovery_failure
          | :unknown_failure

  @spec classify(any(), map()) :: classification()
  def classify(reason, context \\ %{})

  def classify(:missing_state, _context), do: :missing_state
  def classify(:invalid_state, _context), do: :invalid_state
  def classify(:expired_state, _context), do: :expired_state
  def classify(:mismatched_state, _context), do: :mismatched_state
  def classify(:missing_context, _context), do: :missing_context
  def classify(:independent_learner_not_allowed, _context), do: :independent_learner_not_allowed
  def classify(:launch_handler_failure, _context), do: :launch_handler_failure

  def classify(%{reason: :invalid_registration}, _context), do: :invalid_registration
  def classify(%{reason: :invalid_deployment}, _context), do: :invalid_deployment
  def classify(%{reason: :invalid_oidc_state}, context), do: browser_state_failure(context)
  def classify(%{reason: :invalid_message}, _context), do: :launch_validation_failed
  def classify(%{reason: :invalid_message_type}, _context), do: :launch_validation_failed
  def classify(%{reason: :missing_issuer}, _context), do: :launch_validation_failed
  def classify(%{reason: :missing_login_hint}, _context), do: :launch_validation_failed
  def classify(%{reason: _reason}, _context), do: :unknown_failure
  def classify(_reason, _context), do: :unknown_failure

  @spec details(classification()) :: map()
  def details(classification) do
    case classification do
      :embedded_storage_blocked ->
        %{
          title: "Browser Privacy Settings Blocked the Launch",
          message: "Torus could not complete the sign-in handshake for this embedded LMS launch.",
          guidance:
            "Allow cookies for this launch if your browser permits it, or ask your LMS administrator to configure Torus to open in a new tab."
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

      :invalid_state ->
        %{
          title: "Launch State Could Not Be Verified",
          message: "Torus could not verify the sign-in handshake for this launch.",
          guidance: "Return to your LMS and relaunch the course."
        }

      :launch_handler_failure ->
        %{
          title: "Launch Completed but Course Access Failed",
          message: "Torus could not finish preparing the course access for this launch.",
          guidance: "Try the launch again. If the issue persists, contact support."
        }

      :launch_validation_failed ->
        %{
          title: "LTI Launch Could Not Be Validated",
          message: "The LMS launch request was not accepted by Torus.",
          guidance: "Ask your LMS or Torus administrator to verify the launch configuration."
        }

      :missing_context ->
        %{
          title: "Launch Context Was Missing",
          message: "The LMS launch did not include the course context Torus needs.",
          guidance: "Ask your LMS or Torus administrator to verify the launch configuration."
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

      :recovery_failure ->
        %{
          title: "Recovery Could Not Complete the Launch",
          message: "Torus could not recover this embedded launch.",
          guidance:
            "Allow cookies for this launch if your browser permits it, or ask your LMS administrator to configure Torus to open in a new tab."
        }

      :unknown_failure ->
        %{
          title: "LTI Launch Failed",
          message: "Torus could not complete this LMS launch.",
          guidance: "Try the launch again. If the issue persists, contact support."
        }
    end
  end

  defp browser_state_failure(%{storage_supported: true}), do: :embedded_storage_blocked
  defp browser_state_failure(_context), do: :missing_state
end
