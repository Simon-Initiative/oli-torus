defmodule OliWeb.RemixSectionLiveTest do
  use OliWeb.ConnCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Oli.Seeder
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Accounts

  describe "remix section live test" do
    setup [:setup_session]

    test "remix section mount as open and free", %{
      conn: conn,
      admin: admin,
      map: %{
        oaf_section_1: oaf_section_1,
        unit1_container: unit1_container,
        revision1: revision1,
        revision2: revision2
      }
    } do
      conn =
        Plug.Test.init_test_session(conn, %{})
        |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

      conn =
        get(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, oaf_section_1.slug)
        )

      {:ok, view, _html} = live(conn)

      assert view |> element("##{unit1_container.revision.resource_id}") |> has_element?()
      assert view |> element("##{revision1.resource_id}") |> has_element?()
      assert view |> element("##{revision2.resource_id}") |> has_element?()
    end

    test "remix section mount as instructor", %{
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

    test "remix section mount as product manager", %{
      conn: conn
    } do
      # create a product
      %{
        prod1: prod1,
        author: product_author,
        publication: publication,
        revision1: revision1,
        revision2: revision2
      } =
        Seeder.base_project_with_resource2()
        |> Seeder.create_product(%{title: "My 1st product", amount: Money.new(:USD, 100)}, :prod1)

      {:ok, _prod} = Sections.create_section_resources(prod1, publication)

      conn =
        Plug.Test.init_test_session(conn, %{})
        |> Pow.Plug.assign_current_user(
          product_author,
          OliWeb.Pow.PowHelpers.get_pow_config(:author)
        )

      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, prod1.slug))

      {:ok, view, _html} = live(conn)

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

    {:ok, instructor} =
      Accounts.update_user_platform_roles(
        user_fixture(%{can_create_sections: true, independent_learner: true}),
        [
          Lti_1p3.Tool.PlatformRoles.get_role(:institution_instructor)
        ]
      )

    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().admin})

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
     admin: admin,
     author: map.author,
     institution: map.institution,
     project: map.project,
     publication: map.publication}
  end
end
