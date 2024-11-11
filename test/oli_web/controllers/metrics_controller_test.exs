defmodule OliWeb.MetricsControllerTest do
  use OliWeb.ConnCase

  alias Oli.Seeder
  alias Lti_1p3.Tool.ContextRoles

  setup [:setup_session]

  describe "verify download of container progress" do
    test "retrieves the download", %{
      conn: conn,
      section: section,
      unit1_container: unit1
    } do
      conn =
        get(
          conn,
          Routes.metrics_path(conn, :download_container_progress, section.slug, unit1.resource.id)
        )

      Enum.any?(conn.resp_headers, fn h ->
        h ==
          {"content-disposition",
           "attachment; filename=\"progress_#{section.slug}_#{unit1.resource.id}_.csv\""}
      end)

      Enum.any?(conn.resp_headers, fn h -> h == {"content-type", "text/csv"} end)
      assert response(conn, 200)
    end
  end

  defp setup_session(%{conn: conn}) do
    user = user_fixture()
    instructor = user_fixture()

    map =
      Seeder.base_project_with_resource3()
      |> Seeder.ensure_published()
      |> Seeder.create_section()
      |> Seeder.create_section_resources()

    Oli.Delivery.Sections.enroll(user.id, map.section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Oli.Delivery.Sections.enroll(instructor.id, map.section.id, [
      ContextRoles.get_role(:context_instructor)
    ])

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> assign_current_author(map.author)
      |> assign_current_user(instructor)

    {:ok, conn: conn, map: map, section: map.section, unit1_container: map.unit1_container}
  end
end
