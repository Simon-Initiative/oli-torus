defmodule OliWeb.SelectSourceTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.Publication
  alias OliWeb.Common.LtiSession

  import Phoenix.LiveViewTest
  import Oli.Factory

  @live_view_admin_route Routes.select_source_path(OliWeb.Endpoint, :admin)
  @live_view_independent_learner_route Routes.select_source_path(OliWeb.Endpoint, :independent_learner)
  @live_view_from_lms_route Routes.select_source_path(OliWeb.Endpoint, :from_lms)

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the admin view", %{conn: conn} do
      {:error,
       {:redirect, %{to: "/authoring/session/new?request_path=%2Fadmin%2Fopen_and_free%2Fcreate"}}} =
        live(conn, @live_view_admin_route)
    end

    test "redirects to new session when accessing the independent instructor view", %{conn: conn} do
      {:error,
       {:redirect, %{to: "/session/new?request_path=%2Fsections%2Findependent%2Fcreate"}}} =
        live(conn, @live_view_independent_learner_route)
    end

    test "redirects to new session when accessing the lms instructor view", %{conn: conn} do
      {:error,
       {:redirect, %{to: "/session/new?request_path=%2Fcourse%2Fselect_project"}}} =
        live(conn, @live_view_from_lms_route)
    end
  end

  describe "admin index" do
    setup [:admin_conn]

    test "loads correctly when there are no sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_admin_route)

      assert has_element?(view, "p", "None exist")
    end

    test "loads correctly when there are sections in table view", %{conn: conn} do
      section = insert(:section, open_and_free: true)

      {:ok, view, _html} = live(conn, @live_view_admin_route)

      assert has_element?(view, "button[phx-click=\"selected\"]")
      refute has_element?(view, "img[alt=\"course image\"]")
      assert has_element?(view, "a[href=\"#{details_view(section)}\"]")
      assert view
             |> element("tr:first-child > td:first-child + td")
             |> render() =~ "#{section.title}"
    end

    test "applies searching", %{conn: conn} do
      s1 = insert(:section, %{title: "Testing", open_and_free: true})
      s2 = insert(:section, open_and_free: true)

      {:ok, view, _html} = live(conn, @live_view_admin_route)

      view
      |> element("input[phx-blur=\"change_search\"]")
      |> render_blur(%{value: "testing"})

      view
      |> element("button[phx-click=\"apply_search\"]")
      |> render_click()

      assert has_element?(view, "a[href=\"#{details_view(s1)}\"]")
      refute has_element?(view, "a[href=\"#{details_view(s2)}\"]")

      view
      |> element("button[phx-click=\"reset_search\"]")
      |> render_click()

      assert has_element?(view, "a[href=\"#{details_view(s1)}\"]")
      assert has_element?(view, "a[href=\"#{details_view(s2)}\"]")
    end

    test "applies sorting", %{conn: conn} do
      insert(:section, %{title: "Testing A", open_and_free: true})
      insert(:section, %{title: "Testing B", open_and_free: true})

      {:ok, view, _html} = live(conn, @live_view_admin_route)

      view
      |> element("th[phx-click=\"sort\"]:first-of-type")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element("tr:first-child > td:first-child + td")
             |> render() =~ "Testing A"

      view
      |> element("th[phx-click=\"sort\"]:first-of-type")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element("tr:first-child > td:first-child + td")
             |> render() =~ "Testing B"
    end

    test "applies paging", %{conn: conn} do
      [first_s | tail] = insert_list(21, :section, open_and_free: true) |> Enum.sort_by(& &1.inserted_at)
      last_s = List.last(tail)

      {:ok, view, _html} = live(conn, @live_view_admin_route)

      view
      |> element("th[phx-click=\"sort\"]:first-of-type")
      |> render_click(%{sort_by: "inserted_at"})

      assert has_element?(view, "a[href=\"#{details_view(first_s)}\"]")
      refute has_element?(view, "a[href=\"#{details_view(last_s)}\"]")

      view
      |> element("a[phx-click=\"page_change\"]", "2")
      |> render_click()

      refute has_element?(view, "a[href=\"#{details_view(first_s)}\"]")
      assert has_element?(view, "a[href=\"#{details_view(last_s)}\"]")
    end

    test "selects one section correctly", %{conn: conn} do
      section = insert(:section, open_and_free: true)

      {:ok, view, _html} = live(conn, @live_view_admin_route)

      view
      |> element("button[phx-click=\"selected\"]")
      |> render_click()

      assert_redirected(
          view,
          Routes.admin_open_and_free_path(OliWeb.Endpoint, :new, source_id: "product:#{section.id}")
        )
    end
  end

  describe "independent instructor index" do
    setup [:instructor_conn]

    test "loads correctly when there are no sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      assert has_element?(view, "p", "None exist")
    end

    test "loads correctly when there are sections in cards view", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      section = insert(:section, %{base_project: project})

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      refute has_element?(view, "button[phx-click=\"selected\"]")
      assert has_element?(view, "img[alt=\"course image\"]")
      refute has_element?(view, "a[href=\"#{details_view(section)}\"]")
      assert has_element?(view, "h5", "#{section.title}")
    end

    test "applies searching", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      s1 = insert(:section, %{base_project: project, title: "Testing"})
      s2 = insert(:section, %{base_project: project})

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      view
      |> element("input[phx-blur=\"change_search\"]")
      |> render_blur(%{value: "testing"})

      view
      |> element("button[phx-click=\"apply_search\"]")
      |> render_click()

      assert has_element?(view, "h5", "#{s1.title}")
      refute has_element?(view, "h5", "#{s2.title}")

      view
      |> element("button[phx-click=\"reset_search\"]")
      |> render_click()

      assert has_element?(view, "h5", "#{s1.title}")
      assert has_element?(view, "h5", "#{s2.title}")
    end

    test "applies sorting", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      insert(:section, %{base_project: project, title: "Testing A"})
      insert(:section, %{base_project: project, title: "Testing B"})

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      view
      |> element("form[phx-change=\"sort\"")
      |> render_change(%{sort_by: "title"})

      assert view
             |> element(".card-deck:last-child")
             |> render() =~ "Testing B"

      view
      |> element("form[phx-change=\"sort\"")
      |> render_change(%{sort_by: "title"})

      assert view
             |> element(".card-deck:last-child")
             |> render() =~ "Testing A"
    end

    test "applies paging", %{conn: conn} do
      %Publication{id: publication_id, project: project} = insert(:publication)
      [_first_s | tail] = insert_list(21, :section, base_project: project) |> Enum.sort_by(& &1.title)
      last_s = List.last(tail)

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      view
      |> element("form[phx-change=\"sort\"")
      |> render_change(%{sort_by: "title"})

      assert has_element?(view, "a[phx-value-id=\"publication:#{publication_id}\"]")
      refute has_element?(view, "a[phx-value-id=\"product:#{last_s.id}\"]")

      view
      |> element("a[phx-click=\"page_change\"]", "2")
      |> render_click()

      refute has_element?(view, "a[phx-value-id=\"publication:#{publication_id}\"]")
      assert has_element?(view, "a[phx-value-id=\"product:#{last_s.id}\"]")
    end

    test "selects one section correctly", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      section = insert(:section, base_project: project)

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      view
      |> element("a[phx-value-id=\"product:#{section.id}\"]")
      |> render_click()

      assert_redirected(
          view,
          Routes.independent_sections_path(OliWeb.Endpoint, :new, source_id: "product:#{section.id}")
        )
    end
  end

  describe "lms instructor index" do
    setup [:lms_instructor_conn]

    test "loads correctly when there are no sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_from_lms_route)

      assert has_element?(view, "p", "None exist")
    end

    test "loads correctly when there are sections in cards view", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      section = insert(:section, %{base_project: project})

      {:ok, view, _html} = live(conn, @live_view_from_lms_route)

      refute has_element?(view, "button[phx-click=\"selected\"]")
      assert has_element?(view, "img[alt=\"course image\"]")
      refute has_element?(view, "a[href=\"#{details_view(section)}\"]")
      assert has_element?(view, "h5", "#{section.title}")
    end

    test "applies searching", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      s1 = insert(:section, %{base_project: project, title: "Testing"})
      s2 = insert(:section, %{base_project: project})

      {:ok, view, _html} = live(conn, @live_view_from_lms_route)

      view
      |> element("input[phx-blur=\"change_search\"]")
      |> render_blur(%{value: "testing"})

      view
      |> element("button[phx-click=\"apply_search\"]")
      |> render_click()

      assert has_element?(view, "h5", "#{s1.title}")
      refute has_element?(view, "h5", "#{s2.title}")

      view
      |> element("button[phx-click=\"reset_search\"]")
      |> render_click()

      assert has_element?(view, "h5", "#{s1.title}")
      assert has_element?(view, "h5", "#{s2.title}")
    end

    test "applies sorting", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      insert(:section, %{base_project: project, title: "Testing A"})
      insert(:section, %{base_project: project, title: "Testing B"})

      {:ok, view, _html} = live(conn, @live_view_from_lms_route)

      view
      |> element("form[phx-change=\"sort\"")
      |> render_change(%{sort_by: "title"})

      assert view
             |> element(".card-deck:last-child")
             |> render() =~ "Testing B"

      view
      |> element("form[phx-change=\"sort\"")
      |> render_change(%{sort_by: "title"})

      assert view
             |> element(".card-deck:last-child")
             |> render() =~ "Testing A"
    end

    test "applies paging", %{conn: conn} do
      %Publication{id: publication_id, project: project} = insert(:publication)
      [_first_s | tail] = insert_list(21, :section, base_project: project) |> Enum.sort_by(& &1.title)
      last_s = List.last(tail)

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      view
      |> element("form[phx-change=\"sort\"")
      |> render_change(%{sort_by: "title"})

      assert has_element?(view, "a[phx-value-id=\"publication:#{publication_id}\"]")
      refute has_element?(view, "a[phx-value-id=\"product:#{last_s.id}\"]")

      view
      |> element("a[phx-click=\"page_change\"]", "2")
      |> render_click()

      refute has_element?(view, "a[phx-value-id=\"publication:#{publication_id}\"]")
      assert has_element?(view, "a[phx-value-id=\"product:#{last_s.id}\"]")
    end

    test "selects one section correctly", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      section = insert(:section, base_project: project)
      section_resource = insert(:section_resource, %{section: section})
      Sections.update_section(section, %{
        root_section_resource_id: section_resource.id
      })

      {:ok, view, _html} = live(conn, @live_view_from_lms_route)

      view
      |> element("a[phx-value-id=\"product:#{section.id}\"]")
      |> render_click()

      assert_redirected(view, Routes.delivery_path(OliWeb.Endpoint, :index))
      assert Sections.get_section_by(%{blueprint_id: section.id})
    end
  end

  defp details_view(%Section{type: :blueprint} = section),
    do: Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, section.slug)

  defp details_view(section),
    do: Routes.project_path(OliWeb.Endpoint, :overview, section.project.slug)

  defp instructor_conn(%{conn: conn}) do
    {:ok, instructor} =
      Accounts.update_user_platform_roles(
        insert(:user, %{can_create_sections: true, independent_learner: true}),
        [
          Lti_1p3.Tool.PlatformRoles.get_role(:institution_instructor)
        ]
      )

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(instructor, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok, conn: conn}
  end

  defp lms_instructor_conn(%{conn: conn}) do
    institution = insert(:institution)
    tool_jwk = jwk_fixture()
    registration = insert(:lti_registration, %{tool_jwk_id: tool_jwk.id})
    deployment = insert(:lti_deployment, %{institution: institution, registration: registration})

    instructor = insert(:user)

    conn = Plug.Test.init_test_session(conn, lti_session: nil)

    lti_param_ids = %{
      instructor:
        cache_lti_params(
          %{
            "iss" => registration.issuer,
            "aud" => registration.client_id,
            "sub" => instructor.sub,
            "exp" => Timex.now() |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix(),
            "https://purl.imsglobal.org/spec/lti/claim/context" => %{
              "id" => "some_id",
              "title" => "some_title"
            },
            "https://purl.imsglobal.org/spec/lti/claim/roles" => [
              "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"
            ],
            "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id
          },
          instructor.id
        )
    }

    conn =
      conn
      |> Pow.Plug.assign_current_user(instructor, OliWeb.Pow.PowHelpers.get_pow_config(:user))
      |> LtiSession.put_session_lti_params(lti_param_ids.instructor)

    {:ok, conn: conn}
  end
end
