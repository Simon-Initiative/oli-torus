defmodule OliWeb.LtiRedirectTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias OliWeb.LtiRedirect

  @telemetry_prefix [:oli, :lti]

  describe "redirect_from_launch/3" do
    test "emits redirect resolution telemetry with transport method", %{conn: conn} do
      handler_id = attach_handler([@telemetry_prefix ++ [:redirect_resolution]])

      user = insert(:user, independent_learner: false)
      deployment = insert(:lti_deployment)

      section =
        insert(:section,
          lti_1p3_deployment: deployment,
          context_id: "telemetry-context"
        )

      attempt =
        insert(:lti_launch_attempt,
          context_id: section.context_id,
          lifecycle_state: :launch_succeeded,
          resolved_section_id: section.id,
          roles: ["http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"],
          transport_method: :session_storage,
          issuer: deployment.registration.issuer,
          client_id: deployment.registration.client_id
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

    test "launch destination resolves against current section state instead of stored section snapshot",
         %{conn: conn} do
      user = insert(:user, independent_learner: false)
      deployment = insert(:lti_deployment)

      section =
        insert(:section,
          lti_1p3_deployment: deployment,
          context_id: "live-context"
        )

      attempt =
        insert(:lti_launch_attempt,
          context_id: section.context_id,
          issuer: deployment.registration.issuer,
          client_id: deployment.registration.client_id,
          lifecycle_state: :launch_succeeded,
          resolved_section_id: nil,
          roles: ["http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"]
        )

      conn =
        conn
        |> assign(:current_user, user)
        |> LtiRedirect.redirect_from_launch(attempt)

      assert redirected_to(conn) == "/sections/#{section.slug}"
    end

    test "launch destination falls back to section creation when a previously resolved section no longer exists",
         %{conn: conn} do
      user = insert(:user, independent_learner: false)
      deployment = insert(:lti_deployment)

      deleted_section =
        insert(:section,
          lti_1p3_deployment: deployment,
          context_id: "deleted-context"
        )

      {:ok, _} = Oli.Delivery.Sections.delete_section(deleted_section)

      attempt =
        insert(:lti_launch_attempt,
          context_id: deleted_section.context_id,
          issuer: deployment.registration.issuer,
          client_id: deployment.registration.client_id,
          lifecycle_state: :launch_succeeded,
          resolved_section_id: deleted_section.id,
          roles: ["http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"]
        )

      conn =
        conn
        |> assign(:current_user, user)
        |> LtiRedirect.redirect_from_launch(attempt, allow_new_section_creation: true)

      assert redirected_to(conn) == "/sections/new/#{deleted_section.context_id}"
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
