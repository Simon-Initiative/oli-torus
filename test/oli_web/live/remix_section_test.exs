defmodule OliWeb.RemixSectionLiveTest do
  use OliWeb.ConnCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Oli.Seeder
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  describe "remix section live test" do
    setup [:setup_session]

    test "remix section mount", %{
      conn: conn,
      project: project,
      map: %{
        section_1: section_1,
        unit1_container: unit1_container,
        revision1: revision1,
        revision2: revision2
      }
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section_1.slug))

      {:ok, view, _} = live(conn)

      assert view |> element("##{unit1_container.revision.resource_id}") |> has_element?()
      assert view |> element("##{revision1.resource_id}") |> has_element?()
      assert view |> element("##{revision2.resource_id}") |> has_element?()
    end
  end

  defp setup_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource4()
    instructor = user_fixture()

    {:ok, _enrollment} =
      Sections.enroll(instructor.id, map.section_1.id, [
        ContextRoles.get_role(:context_instructor)
      ])

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(instructor, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok,
     conn: conn,
     map: map,
     author: map.author,
     institution: map.institution,
     project: map.project,
     publication: map.publication}
  end
end
