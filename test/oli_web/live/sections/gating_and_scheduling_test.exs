defmodule OliWeb.Sections.GatingAndSchedulingTest do
  use OliWeb.ConnCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Seeder
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.{Gating, Sections}

  @endpoint OliWeb.Endpoint

  defp gating_condition_edit_route(section_slug, gating_condition_id),
    do:
      Routes.live_path(
        @endpoint,
        OliWeb.Sections.GatingAndScheduling.Edit,
        section_slug,
        gating_condition_id
      )

  describe "gating and scheduling live test admin" do
    setup [:setup_admin_session]

    test "mount listing for admin", %{conn: conn, section_1: section} do
      {:ok, _view, html} =
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug))

      assert html =~ "Gating and Scheduling"
    end
  end

  describe "gating and scheduling live test instructor" do
    setup [:setup_instructor_session]

    test "mount listing for instructor", %{conn: conn, section_1: section} do
      {:ok, _view, html} =
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug))

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
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_edit_route(section.slug, gating_condition.id)
        )

      assert view
             |> render() =~
               "Edit Gating Condition"

      assert has_element?(view, "input[value=\"#{revision.title}\"]")

      assert view
             |> render() =~ Date.to_string(gating_condition.data.start_datetime)

      assert view
             |> render() =~ Date.to_string(gating_condition.data.end_datetime)
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
  end

  defp setup_admin_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource4()
    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().admin})

    conn =
      Plug.Test.init_test_session(conn, [])
      |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok, Map.merge(map, %{conn: conn, admin: admin})}
  end

  defp setup_instructor_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource4()

    instructor = user_fixture()
    Sections.enroll(instructor.id, map.section_1.id, [ContextRoles.get_role(:context_instructor)])

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
