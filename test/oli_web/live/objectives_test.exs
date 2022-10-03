defmodule OliWeb.ObjectivesLiveTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Oli.Seeder
  alias Oli.Resources.Revision

  defp live_view_route(project_slug),
    do: Routes.live_path(OliWeb.Endpoint, OliWeb.Objectives.Objectives, project_slug)

  defp create_project(_conn) do
    project = insert(:project)

    [project: project]
  end

  describe "user cannot access when is not logged in" do
    setup [:create_project]

    test "redirects to new session when accessing the objectives view", %{conn: conn, project: project} do
      redirect_path =
        "/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fobjectives"

      {:error, {:redirect, %{to: ^redirect_path}}} = live(conn, live_view_route(project.slug))
    end
  end

  describe "user cannot access when is logged in as an author but is not an author of the project" do
    setup [:author_conn, :create_project]

    test "redirects to projects view when accessing the objectives view", %{conn: conn, project: project} do
      redirect_path = "/authoring/projects"

      {:error, {:redirect, %{to: ^redirect_path}}} = live(conn, live_view_route(project.slug))
    end
  end

  describe "sub-ojectives" do
    setup [:setup_session]

    test "modal displays the sub-objectives correctly", %{
      conn: conn,
      project: project,
      map: %{
        objective2: %{revision: %Revision{slug: objective2_slug}},
        subobjective2A: %{revision: %Revision{slug: subobjective2A_slug}},
        subobjective2B: %{revision: %Revision{slug: subobjective2B_slug}},
        subobjective3A: %{revision: %Revision{slug: subobjective3A_slug}}
      }
    } do
      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      view
      |> element("button[phx-click=\"show_select_existing_sub_modal\"][phx-value-slug=#{objective2_slug}]")
      |> render_click(%{slug: objective2_slug})

      refute view
        |> element("button[phx-click=\"add_existing_sub\"][phx-value-slug=#{subobjective2A_slug}]", "Add")
        |> has_element?()

      refute view
        |> element("button[phx-click=\"add_existing_sub\"][phx-value-slug=#{subobjective2B_slug}]", "Add")
        |> has_element?()

      assert view
        |> element("button[phx-click=\"add_existing_sub\"][phx-value-slug=#{subobjective3A_slug}]", "Add")
        |> has_element?()
    end

    test "adds a sub-objective successfully", %{
      conn: conn,
      project: project,
      map: %{
        objective2: %{revision: %Revision{slug: objective2_slug}},
        objective3: %{revision: %Revision{slug: objective3_slug}},
        subobjective3A: %{revision: %Revision{slug: subobjective3A_slug}}
      }
    } do
      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      refute view |> element("##{objective2_slug}_#{subobjective3A_slug}") |> has_element?()

      view
      |> element("button[phx-click=\"show_select_existing_sub_modal\"][phx-value-slug=#{objective2_slug}]")
      |> render_click(%{slug: objective2_slug})

      view
      |> element("button[phx-click=\"add_existing_sub\"][phx-value-slug=#{subobjective3A_slug}]", "Add")
      |> render_click(%{slug: subobjective3A_slug, parent_slug: objective2_slug})

      assert view
        |> element("div.alert.alert-info")
        |> render() =~ "Sub-objective successfully added"

      assert view |> element("##{objective2_slug}_#{subobjective3A_slug}") |> has_element?()
      assert view |> element("##{objective3_slug}_#{subobjective3A_slug}") |> has_element?()
    end

    test "removes sub-objective with one parent successfully", %{
      conn: conn,
      project: project,
      map: %{
        objective3: %{revision: %Revision{slug: objective3_slug}},
        subobjective3A: %{revision: %Revision{slug: subobjective3A_slug}}
      }
    } do
      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      view
      |> element("button[phx-click=\"show_delete_modal\"][phx-value-slug=#{subobjective3A_slug}][phx-value-parent_slug=#{objective3_slug}]", "Remove")
      |> render_click(%{slug: subobjective3A_slug, parent_slug: objective3_slug})

      view
      |> element("button[phx-click=\"delete\"][phx-value-slug=#{subobjective3A_slug}][phx-value-parent_slug=#{objective3_slug}]", "Delete")
      |> render_click(%{slug: subobjective3A_slug, parent_slug: objective3_slug})

      refute view |> element("##{objective3_slug}_#{subobjective3A_slug}") |> has_element?()
    end

    test "removes sub-objective with more than one parent successfully", %{
      conn: conn,
      project: project,
      map: %{
        objective2: %{revision: %Revision{slug: objective2_slug}},
        objective3: %{revision: %Revision{slug: objective3_slug}},
        subobjective3A: %{revision: %Revision{slug: subobjective3A_slug}}
      }
    } do
      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      view
      |> element("button[phx-click=\"show_select_existing_sub_modal\"][phx-value-slug=#{objective2_slug}]")
      |> render_click(%{slug: objective2_slug})

      view
      |> element("button[phx-click=\"add_existing_sub\"][phx-value-slug=#{subobjective3A_slug}]", "Add")
      |> render_click(%{slug: subobjective3A_slug, parent_slug: objective2_slug})

      assert view
        |> element("div.alert.alert-info")
        |> render() =~ "Sub-objective successfully added"


      view
      |> element("button[phx-click=\"show_delete_modal\"][phx-value-slug=#{subobjective3A_slug}][phx-value-parent_slug=#{objective3_slug}]", "Remove")
      |> render_click(%{slug: subobjective3A_slug, parent_slug: objective3_slug})

      view
      |> element("button[phx-click=\"delete\"][phx-value-slug=#{subobjective3A_slug}][phx-value-parent_slug=#{objective3_slug}]", "Delete")
      |> render_click(%{slug: subobjective3A_slug, parent_slug: objective3_slug})

      assert view
        |> element("div.alert.alert-info")
        |> render() =~ "Objective successfully removed"

      assert view |> element("##{objective2_slug}_#{subobjective3A_slug}") |> has_element?()
      refute view |> element("##{objective3_slug}_#{subobjective3A_slug}") |> has_element?()
    end

    test "edit input shows just on the clicking sub-objective when having more than one parent", %{
      conn: conn,
      project: project,
      map: %{
        objective2: %{revision: %Revision{slug: objective2_slug}},
        objective3: %{revision: %Revision{slug: objective3_slug}},
        subobjective3A: %{revision: %Revision{slug: subobjective3A_slug}}
      }
    } do
      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      view
      |> element("button[phx-click=\"show_select_existing_sub_modal\"][phx-value-slug=#{objective2_slug}]")
      |> render_click(%{slug: objective2_slug})

      view
      |> element("button[phx-click=\"add_existing_sub\"][phx-value-slug=#{subobjective3A_slug}]", "Add")
      |> render_click(%{slug: subobjective3A_slug, parent_slug: objective2_slug})

      assert view
        |> element("div.alert.alert-info")
        |> render() =~ "Sub-objective successfully added"

      view
      |> element("button[phx-click=\"modify\"][phx-value-slug=#{subobjective3A_slug}][phx-value-parent_slug=#{objective3_slug}]", "Reword")
      |> render_click(%{slug: subobjective3A_slug, parent_slug: objective3_slug})

      assert view |> element("input[value=#{objective3_slug}") |> has_element?()
      assert view |> element("input[value=#{subobjective3A_slug}") |> has_element?()

      refute view |> element("input[value=#{objective2_slug}") |> has_element?()
    end
  end

  describe "objectives live test" do
    setup [:setup_session]

    test "objectives mount", %{conn: conn, project: project, map: map} do
      conn = get(conn, "/authoring/project/#{project.slug}/objectives")

      {:ok, view, _} = live(conn)

      objective1 = Map.get(map, :objective1)
      objective2 = Map.get(map, :objective2)

      # the container should have two objectives
      assert view |> element("##{objective1.revision.slug}") |> has_element?()
      assert view |> element("##{objective2.revision.slug}") |> has_element?()
    end

    test "can delete objective", %{conn: conn, project: project, map: map} do
      conn = get(conn, "/authoring/project/#{project.slug}/objectives")

      {:ok, view, _} = live(conn)

      objective1 = Map.get(map, :objective1)
      objective2 = Map.get(map, :objective2)

      # the container should have two objectives
      assert view |> element("##{objective1.revision.slug}") |> has_element?()
      assert view |> element("##{objective2.revision.slug}") |> has_element?()

      # delete the selected objective, which requires first clicking the delete button
      # which will display the modal, then we click the "Delete" button in the modal
      view
      |> element("#delete_#{objective1.revision.slug}")
      |> render_click()

      view
      |> element("button[phx-click=\"delete\"]")
      |> render_click()

      refute view |> element("##{objective1.revision.slug}") |> has_element?()
      assert view |> element("##{objective2.revision.slug}") |> has_element?()
    end
  end

  defp setup_session(%{conn: conn}) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.add_objective("sub objective 1", :subobjective2A)
      |> Seeder.add_objective("sub objective 2", :subobjective2B)
      |> Seeder.add_objective("sub objective 3", :subobjective3A)
      |> Seeder.add_objective("objective 1", :objective1)
      |> Seeder.add_objective_with_children("objective 2", [:subobjective2A, :subobjective2B], :objective2)
      |> Seeder.add_objective_with_children("objective 3", [:subobjective3A], :objective3)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(map.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok,
     conn: conn,
     map: map,
     author: map.author,
     institution: map.institution,
     project: map.project,
     publication: map.publication}
  end
end
