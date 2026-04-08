defmodule OliWeb.LtiRedirectTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias OliWeb.LtiRedirect

  @telemetry_prefix [:oli, :lti]

  describe "redirect_from_launch/3" do
    test "emits redirect resolution telemetry with transport method", %{conn: conn} do
      handler_id = attach_handler([@telemetry_prefix ++ [:redirect_resolution]])

      user = insert(:user, independent_learner: false)
      section = insert(:section)

      attempt =
        insert(:lti_launch_attempt,
          context_id: section.context_id,
          lifecycle_state: :launch_succeeded,
          resolved_section_id: section.id,
          roles: ["http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"],
          transport_method: :session_storage
        )

      conn =
        conn
        |> assign(:current_user, user)
        |> LtiRedirect.redirect_from_launch(attempt)

      assert redirected_to(conn) == "/sections/#{section.slug}"

      assert_receive {:telemetry_event, [:oli, :lti, :redirect_resolution], %{count: 1}, meta}
      assert meta.attempt_id == attempt.id
      assert meta.transport_method == :session_storage
      assert meta.outcome == :section_home

      detach_handler(handler_id)
    end
  end

  defp attach_handler(events) do
    handler_id = "lti-redirect-test-#{System.unique_integer([:positive])}"
    parent = self()

    :telemetry.attach_many(
      handler_id,
      events,
      fn event_name, measurements, metadata, _ ->
        send(parent, {:telemetry_event, event_name, measurements, metadata})
      end,
      %{}
    )

    handler_id
  end

  defp detach_handler(handler_id), do: :telemetry.detach(handler_id)
end
