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
      map: %{
        section_1: section_1,
        unit1_container: unit1_container,
        revision1: revision1,
        revision2: revision2
      }
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section_1.slug))

      {:ok, view, _html} = live(conn)

      assert view |> element("##{unit1_container.revision.resource_id}") |> has_element?()
      assert view |> element("##{revision1.resource_id}") |> has_element?()
      assert view |> element("##{revision2.resource_id}") |> has_element?()
    end

    test "remix section navigation", %{
      conn: conn,
      map: %{
        section_1: section1,
        unit1_container: unit1_container,
        nested_revision1: nested_revision1,
        nested_revision2: nested_revision2
      }
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section1.slug))

      {:ok, view, _html} = live(conn)

      # navigate to a lower unit
      view
      |> element("##{unit1_container.revision.resource_id} button.entry-title")
      |> render_click()

      assert view |> element("##{unit1_container.revision.resource_id}") |> has_element?() ==
               false

      assert view |> element("##{nested_revision1.resource_id}") |> has_element?()
      assert view |> element("##{nested_revision2.resource_id}") |> has_element?()

      # navigate back to root container
      view
      |> element("#curriculum-back")
      |> render_click()

      assert view |> element("##{unit1_container.revision.resource_id}") |> has_element?()
    end

    test "remix section reorder and save", %{
      conn: conn,
      map: %{
        section_1: section
      }
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section.slug))

      {:ok, view, _html} = live(conn)

      view
      |> render_hook("reorder", %{"sourceIndex" => "0", "dropIndex" => "2"})

      view
      |> element("#save")
      |> render_click()

      assert_redirect(view, Routes.page_delivery_path(conn, :index, section.slug))
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
      Plug.Test.init_test_session(conn, lti_session: nil, section_slug: map.section_1.slug)
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
