defmodule OliWeb.LtiRedirectTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias OliWeb.LtiRedirect

  @telemetry_prefix [:oli, :lti]

  describe "redirect_from_lti_params/3" do
    test "emits redirect resolution telemetry with transport method", %{conn: conn} do
      handler_id = attach_handler([@telemetry_prefix ++ [:redirect_resolution]])

      user = insert(:user, independent_learner: false)
      deployment = insert(:lti_deployment)

      section =
        insert(:section,
          lti_1p3_deployment: deployment,
          context_id: "telemetry-context"
        )

      lti_params = %{
        "iss" => deployment.registration.issuer,
        "aud" => [deployment.registration.client_id],
        "https://purl.imsglobal.org/spec/lti/claim/context" => %{"id" => section.context_id},
        "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id,
        "https://purl.imsglobal.org/spec/lti/claim/roles" => [
          "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"
        ]
      }

      conn =
        conn
        |> assign(:current_user, user)
        |> LtiRedirect.redirect_from_lti_params(lti_params,
          source: :current_launch,
          transport_method: :session_storage
        )

      assert redirected_to(conn) == "/sections/#{section.slug}"

      assert_receive {:telemetry_event, [:oli, :lti, :redirect_resolution], %{count: 1}, meta}
      assert meta.transport_method == :session_storage
      assert meta.outcome == :section_home
      assert meta.source == :current_launch

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

      lti_params = %{
        "iss" => deployment.registration.issuer,
        "aud" => [deployment.registration.client_id],
        "https://purl.imsglobal.org/spec/lti/claim/context" => %{"id" => section.context_id},
        "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id,
        "https://purl.imsglobal.org/spec/lti/claim/roles" => [
          "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"
        ]
      }

      conn =
        conn
        |> assign(:current_user, user)
        |> LtiRedirect.redirect_from_lti_params(lti_params, source: :current_launch)

      assert redirected_to(conn) == "/sections/#{section.slug}"
    end

    test "launch destination falls back to section creation when the current context has no section",
         %{conn: conn} do
      user = insert(:user, independent_learner: false)
      deployment = insert(:lti_deployment)

      lti_params = %{
        "iss" => deployment.registration.issuer,
        "aud" => [deployment.registration.client_id],
        "https://purl.imsglobal.org/spec/lti/claim/context" => %{"id" => "deleted-context"},
        "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id,
        "https://purl.imsglobal.org/spec/lti/claim/roles" => [
          "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"
        ]
      }

      conn =
        conn
        |> assign(:current_user, user)
        |> LtiRedirect.redirect_from_lti_params(lti_params,
          allow_new_section_creation: true,
          source: :current_launch
        )

      assert redirected_to(conn) == "/sections/new/deleted-context"
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
