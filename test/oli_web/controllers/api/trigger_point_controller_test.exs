defmodule OliWeb.Api.TriggerPointControllerTest do
  use OliWeb.ConnCase

  alias Oli.Seeder
  alias OliWeb.Router.Helpers, as: Routes

  describe "standard cases" do
    setup [:setup_session]

    test "handle when user not enrolled", %{
      conn: conn,
      map: map
    } do
      trigger = %{
        "trigger_type" => "content_block",
        "resource_id" => "resource_id",
        "data" => %{},
        "prompt" => "prompt"
      }

      conn =
        post(
          conn,
          Routes.trigger_point_path(conn, :invoke, map.section.slug),
          %{"trigger" => trigger}
        )

      assert %{
               "type" => "failure",
               "reason" => "User does not have permission to invoke trigger point"
             } = json_response(conn, 200)
    end

    test "handle when user enrolled, but triggers disabled", %{
      conn: conn,
      map: map
    } do
      Oli.Delivery.Sections.enroll(
        map.user1.id,
        map.section.id,
        [Lti_1p3.Tool.ContextRoles.get_role(:context_learner)],
        :enrolled
      )

      trigger = %{
        "trigger_type" => "content_block",
        "resource_id" => "resource_id",
        "data" => %{},
        "prompt" => "prompt"
      }

      conn =
        post(
          conn,
          Routes.trigger_point_path(conn, :invoke, map.section.slug),
          %{"trigger" => trigger}
        )

      assert %{
               "type" => "failure",
               "reason" => "User does not have permission to invoke trigger point"
             } = json_response(conn, 200)
    end

    test "handle when user enrolled, and triggers and agent enabled", %{
      conn: conn,
      map: map
    } do
      Oli.Delivery.Sections.enroll(
        map.user1.id,
        map.section.id,
        [Lti_1p3.Tool.ContextRoles.get_role(:context_learner)],
        :enrolled
      )

      Oli.Delivery.Sections.update_section!(map.section, %{
        triggers_enabled: true,
        assistant_enabled: true
      })

      trigger = %{
        "trigger_type" => "content_block",
        "resource_id" => "resource_id",
        "data" => %{},
        "prompt" => "prompt"
      }

      conn =
        post(
          conn,
          Routes.trigger_point_path(conn, :invoke, map.section.slug),
          %{"trigger" => trigger}
        )

      assert %{"type" => "submitted"} = json_response(conn, 200)
    end
  end

  defp setup_session(%{conn: conn}) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)

    Seeder.ensure_published(map.publication.id)

    map =
      Seeder.create_section_resources(map)

    user = map.user1

    Oli.Lti.TestHelpers.all_default_claims()
    |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], map.section.slug)
    |> cache_lti_params(user.id)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> log_in_user(user)

    {:ok, conn: conn, map: map}
  end
end
