defmodule OliWeb.Sections.GatingAndSchedulingTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.{ConnTest, LiveViewTest}

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.{Gating, Sections}
  alias Oli.Seeder

  @endpoint OliWeb.Endpoint

  defp gating_condition_edit_route(section_slug, gating_condition_id),
    do:
      Routes.live_path(
        @endpoint,
        OliWeb.Sections.GatingAndScheduling.Edit,
        section_slug,
        gating_condition_id
      )

  defp gating_condition_new_route(section_slug),
    do:
      Routes.live_path(
        @endpoint,
        OliWeb.Sections.GatingAndScheduling.New,
        section_slug
      )

  describe "gating and scheduling live test admin" do
    setup [:setup_admin_session]

    test "mount listing for admin", %{conn: conn, section_1: section} do
      {:ok, _view, html} =
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug))

      assert html =~ "Admin"
      assert html =~ "Gating and Scheduling"
    end
  end

  describe "gating and scheduling live test instructor" do
    setup [:setup_instructor_session]

    test "mount listing for instructor", %{conn: conn, section_1: section} do
      {:ok, _view, html} =
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug))

      refute html =~ "Admin"
      assert html =~ "Gating and Scheduling"
    end

    test "mount new for instructor", %{conn: conn, section_1: section} do
      {:ok, _view, html} =
        live(
          conn,
          Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling.New, section.slug)
        )

      assert html =~ "Create Gating Condition"
    end

    test "mount edit for instructor", %{conn: conn, section_1: section, page1: page1} do
      gc = gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      {:ok, _view, html} =
        live(
          conn,
          Routes.live_path(
            @endpoint,
            OliWeb.Sections.GatingAndScheduling.Edit,
            section.slug,
            gc.id
          )
        )

      assert html =~ "Edit Gating Condition"
    end
  end

  describe "gating and scheduling edit live test" do
    setup [:setup_admin_session, :create_gating_condition]

    test "displays gating condition info correctly", %{
      conn: conn,
      section_1: section,
      gating_condition: gating_condition,
      revision: revision
    } do
      {:ok, view, html} =
        live(
          conn,
          gating_condition_edit_route(section.slug, gating_condition.id)
        )

      assert html =~ "Edit Gating Condition"
      assert has_element?(view, "input[value=\"#{revision.title}\"]")
      assert html =~ Date.to_string(gating_condition.data.start_datetime)
      assert html =~ Date.to_string(gating_condition.data.end_datetime)
    end

    test "displays a confirm modal before deleting a gating condition", %{
      conn: conn,
      section_1: section,
      gating_condition: gating_condition
    } do
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_edit_route(section.slug, gating_condition.id)
        )

      view
      |> element("button[phx-click=\"show-delete-gating-condition\"]")
      |> render_click()

      assert view
             |> element("#delete_gating_condition h5.modal-title")
             |> render() =~
               "Are you absolutely sure?"
    end

    test "deletes the gating condition and redirects to the index page", %{
      conn: conn,
      section_1: section,
      gating_condition: gating_condition
    } do
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_edit_route(section.slug, gating_condition.id)
        )

      view
      |> element("button[phx-click=\"show-delete-gating-condition\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"delete-gating-condition\"]")
      |> render_click()

      flash =
        assert_redirected(
          view,
          Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug)
        )

      assert flash["info"] == "Gating condition successfully deleted."

      assert_raise Ecto.NoResultsError,
                   ~r/^expected at least one result but got none in query/,
                   fn -> Gating.get_gating_condition!(gating_condition.id) end
    end

    test "displays error message when dates are not consistent", %{
      conn: conn,
      section_1: section,
      gating_condition: gating_condition
    } do
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_edit_route(section.slug, gating_condition.id)
        )

      render_hook(view, "schedule_start_date_changed", %{value: "2022-01-12T13:48"})
      render_hook(view, "schedule_end_date_changed", %{value: "2022-01-10T13:48"})

      view
      |> element("button[phx-click=\"update_gate\"]")
      |> render_click()

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Gating condition couldn&#39;t be updated."
    end

    test "updates the gating condition when dates are consistent", %{
      conn: conn,
      section_1: section,
      gating_condition: gating_condition
    } do
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_edit_route(section.slug, gating_condition.id)
        )

      render_hook(view, "schedule_start_date_changed", %{value: "2022-01-12T13:48"})
      render_hook(view, "schedule_end_date_changed", %{value: "2022-01-13T13:48"})

      view
      |> element("button[phx-click=\"update_gate\"]")
      |> render_click()

      flash =
        assert_redirected(
          view,
          Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug)
        )

      assert flash["info"] == "Gating condition successfully updated."
    end
  end

  describe "gating and scheduling new live test" do
    setup [:setup_admin_session]

    test "displays error message when dates are not consistent", %{
      conn: conn,
      section_1: section
    } do
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_new_route(section.slug)
        )

      view
      |> element("button[phx-click=\"show-resource-picker\"]")
      |> render_click()

      # Since Oli.Publishing.DeliveryResolver.find_in_hierarchy generates dynamic uuids every
      # time is called, and that is what is used to select one resource, is necessary to parse the
      # HTML element to get the actual uuid :(

      element_splitted =
        view
        |> element("div[phx-click=\"HierarchyPicker.select\"]", "Page one")
        |> render()
        |> String.split("\"")

      prev_uuid_index =
        Enum.with_index(element_splitted)
        |> Enum.find(fn elem -> elem(elem, 0) == " phx-value-uuid=" end)
        |> elem(1)

      uuid = Enum.at(element_splitted, prev_uuid_index + 1)

      render_hook(view, "select_resource", %{selection: "#{uuid}"})
      render_hook(view, "select-condition", %{value: "schedule"})
      render_hook(view, "schedule_start_date_changed", %{value: "2022-01-12T13:48"})
      render_hook(view, "schedule_end_date_changed", %{value: "2022-01-10T13:48"})

      view
      |> element("button[phx-click=\"create_gate\"]")
      |> render_click()

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Gating condition couldn&#39;t be created."
    end

    test "creates the gating condition when dates are consistent", %{
      conn: conn,
      section_1: section
    } do
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_new_route(section.slug)
        )

      view
      |> element("button[phx-click=\"show-resource-picker\"]")
      |> render_click()

      # Since Oli.Publishing.DeliveryResolver.find_in_hierarchy generates dynamic uuids every
      # time is called, and that is what is used to select one resource, is necessary to parse the
      # HTML element to get the actual uuid :(

      element_splitted =
        view
        |> element("div[phx-click=\"HierarchyPicker.select\"]", "Page one")
        |> render()
        |> String.split("\"")

      prev_uuid_index =
        Enum.with_index(element_splitted)
        |> Enum.find(fn elem -> elem(elem, 0) == " phx-value-uuid=" end)
        |> elem(1)

      uuid = Enum.at(element_splitted, prev_uuid_index + 1)

      render_hook(view, "select_resource", %{selection: "#{uuid}"})
      render_hook(view, "select-condition", %{value: "schedule"})
      render_hook(view, "schedule_start_date_changed", %{value: "2022-01-12T13:48"})
      render_hook(view, "schedule_end_date_changed", %{value: "2022-01-13T13:48"})

      view
      |> element("button[phx-click=\"create_gate\"]")
      |> render_click()

      flash =
        assert_redirected(
          view,
          Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug)
        )

      assert flash["info"] == "Gating condition successfully created."
    end
  end

  defp setup_admin_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource4()
    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().admin})

    Seeder.create_schedule_gating_condition(
      DateTime.add(yesterday(), -(60 * 60 * 24), :second),
      yesterday(),
      map.page1.id,
      map.section_1.id
    )

    conn =
      Plug.Test.init_test_session(conn, [])
      |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok, Map.merge(map, %{conn: conn, admin: admin})}
  end

  defp setup_instructor_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource4()

    instructor = user_fixture()
    Sections.enroll(instructor.id, map.section_1.id, [ContextRoles.get_role(:context_instructor)])

    Seeder.create_schedule_gating_condition(
      DateTime.add(yesterday(), -(60 * 60 * 24), :second),
      yesterday(),
      map.page1.id,
      map.section_1.id
    )

    conn =
      Plug.Test.init_test_session(conn, [])
      |> Pow.Plug.assign_current_user(instructor, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok, Map.merge(map, %{conn: conn, instructor: instructor})}
  end

  defp create_gating_condition(%{section_1: section}) do
    project = insert(:project)

    section_project_publication =
      insert(:section_project_publication, %{section: section, project: project})

    revision = insert(:revision)

    insert(:section_resource, %{
      section: section,
      project: project,
      resource_id: revision.resource.id
    })

    insert(:published_resource, %{
      resource: revision.resource,
      revision: revision,
      publication: section_project_publication.publication
    })

    gating_condition = insert(:gating_condition, %{section: section, resource: revision.resource})

    [gating_condition: gating_condition, revision: revision]
  end
end
