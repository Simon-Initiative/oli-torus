defmodule OliWeb.GradesLiveTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Phoenix.ConnTest
  import Oli.Factory
  import Mox

  alias Oli.Test.MockHTTP
  alias OliWeb.Router.Helpers, as: Routes
  # alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section

  defp live_view_grades_route(section_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradesLive, section_slug)
  end

  defp create_section(_conn) do
    jwk = jwk_fixture()

    registration =
      insert(:lti_registration, %{
        auth_token_url: "https://example.com",
        tool_jwk_id: jwk.id,
        client_id: "0001",
        auth_server: "https://example.com"
      })

    deployment = insert(:lti_deployment, %{registration: registration})

    {:ok, section: section, unit_one_revision: _unit_one_revision, page_revision: page_revision} =
      section_with_assessment(%{}, deployment)

    [section: section, page_revision: page_revision]
  end

  defp create_section_with_invalid_registration(_conn) do
    registration =
      insert(:lti_registration, %{
        client_id: "error"
      })

    deployment = insert(:lti_deployment, %{registration: registration})

    {:ok, section: section, unit_one_revision: _unit_one_revision, page_revision: _page_revision} =
      section_with_assessment(%{}, deployment)

    [section: section]
  end

  describe "user cannot access when is not logged in" do
    setup [:create_section]

    test "redirects to new session when accessing manage LMS grades view", %{
      conn: conn,
      section: %Section{slug: section_slug}
    } do
      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section_slug}%2Fgrades%2Flms&section=#{section_slug}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_grades_route(section_slug))
    end
  end

  describe "user cannot access when is logged in as an author but not as system admin" do
    setup [:author_conn, :create_section]

    test "redirects to new session when accessing manage LMS grades view", %{
      conn: conn,
      section: %Section{slug: section_slug}
    } do
      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section_slug}%2Fgrades%2Flms&section=#{section_slug}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_grades_route(section_slug))
    end
  end

  describe "user cannot access when is logged in as an LMS student" do
    setup [:user_conn, :create_section]

    test "redirects to unauthorized when accessing the manage LMS grades view", %{
      conn: conn,
      section: section,
      user: user
    } do
      enroll_user_to_section(user, section, :context_learner)

      redirect_path = "/unauthorized"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_grades_route(section.slug))
    end
  end

  describe "user cannot access when is logged in as an instructor but for other LMS" do
    setup [:lms_instructor_conn, :create_section]

    test "redirects to unauthorized when accessing the manage LMS grades view", %{
      conn: conn,
      section: section
    } do
      redirect_path = "/unauthorized"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_grades_route(section.slug))
    end
  end

  describe "user can access when is logged in as an LMS instructor" do
    setup [:lms_instructor_conn, :create_section]

    test "successfully to the manage LMS grades view", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      enroll_user_to_section(instructor, section, :context_instructor)

      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      assert has_element?(view, "h2", "Manage Grades")
    end
  end

  describe "fetching valid access token" do
    setup [:admin_conn, :create_section]
    @out_of 120.0

    test "test connection - shows success message when the connection is successful", %{
      conn: conn,
      section: section
    } do
      url_line_items = section.line_items_service_url <> "?limit=1000"

      expect(MockHTTP, :get, fn ^url_line_items, _headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             "[{ \"id\": \"id\", \"scoreMaximum\": \"scoreMaximum\", \"resourceId\": \"resourceId\", \"label\": \"label\" }]"
         }}
      end)

      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element("button[phx-click=\"test_connection\"]")
      |> render_click()

      assert has_element?(view, "samp", "Starting test")
      assert has_element?(view, "samp", "Requesting access token...")
      assert has_element?(view, "samp", "Received access token")
      assert has_element?(view, "samp", "Requesting line items...")
      assert has_element?(view, "samp", "Received line items")
      assert has_element?(view, "samp", "Success!")
    end

    @tag capture_log: true
    test "test connection - shows error message on failure to obtain line items", %{
      conn: conn,
      section: section
    } do
      url_line_items = section.line_items_service_url <> "?limit=1000"

      expect(MockHTTP, :get, fn ^url_line_items, _headers ->
        {:error, "Error retrieving all line items"}
      end)

      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element("button[phx-click=\"test_connection\"]")
      |> render_click()

      assert has_element?(view, "samp", "Starting test")
      assert has_element?(view, "samp", "Requesting access token...")
      assert has_element?(view, "samp", "Received access token")
      assert has_element?(view, "samp", "Requesting line items...")

      send(view.pid, {:test_status, "Error retrieving all line items", :failure, true})
      render(view)

      assert has_element?(view, "samp", "Error retrieving all line items")
    end

    test "update line items - shows an info message when line items are already up to date", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      url_line_items = section.line_items_service_url <> "?limit=1000"

      expect(MockHTTP, :get, fn ^url_line_items, _headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             "[{\"id\": \"1\", \"label\":\"#{page_revision.title}\", \"resourceId\":\"oli-torus-#{page_revision.resource_id}\", \"scoreMaximum\":1.0}]"
         }}
      end)

      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element(
        "a[phx-click=\"send_line_items\"]",
        "Update LMS Line Items"
      )
      |> render_click()

      assert has_element?(view, "div.alert.alert-info", "LMS line items already up to date")
    end

    test "update line items - shows an info message when line items are updated successfully", %{
      conn: conn,
      section: section
    } do
      url_line_items = section.line_items_service_url <> "?limit=1000"
      line_items_service_url = section.line_items_service_url

      expect(MockHTTP, :get, fn ^url_line_items, _headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             "[{ \"id\": \"id\", \"scoreMaximum\": \"scoreMaximum\", \"resourceId\": \"resourceId\", \"label\": \"label\" }]"
         }}
      end)

      expect(MockHTTP, :post, fn ^line_items_service_url, _body, _headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             "{\"id\": \"1\", \"label\":\"Progress test revision\", \"resourceId\":\"oli-torus-1744\", \"scoreMaximum\":1.0}"
         }}
      end)

      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element(
        "a[phx-click=\"send_line_items\"]",
        "Update LMS Line Items"
      )
      |> render_click()

      assert has_element?(view, "div.alert.alert-info", "LMS up to date")
    end

    @tag capture_log: true
    test "update line items - shows error message on failure to obtain line items", %{
      conn: conn,
      section: section
    } do
      url_line_items = section.line_items_service_url <> "?limit=1000"

      expect(MockHTTP, :get, fn ^url_line_items, _headers ->
        {:error, "Error retrieving all line items"}
      end)

      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element(
        "a[phx-click=\"send_line_items\"]",
        "Update LMS Line Items"
      )
      |> render_click()

      assert has_element?(view, "div.alert.alert-danger", "Error accessing LMS line items")
    end

    test "sync grades - shows results when no grade updates are pending", %{
      conn: conn,
      section: section
    } do
      user = insert(:user)
      enroll_user_to_section(user, section, :context_learner)

      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element(
        "a[phx-click=\"send_grades\"]",
        "Synchronize Grades"
      )
      |> render_click()

      assert has_element?(view, "p", "Pending grade updates: 0")
      assert has_element?(view, "p", "Succeeded: 0")
      assert has_element?(view, "p", "Failed: 0")
    end

    test "sync grades - shows the results when there are pending grade updates", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      user = insert(:user)
      enroll_user_to_section(user, section, :context_learner)

      resource_access =
        insert(:resource_access,
          user: user,
          resource: page_revision.resource,
          section: section,
          score: 100,
          out_of: 120
        )

      insert(:resource_attempt, resource_access: resource_access)

      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element(
        "a[phx-click=\"send_grades\"]",
        "Synchronize Grades"
      )
      |> render_click()

      assert has_element?(view, "p", "Pending grade updates: 1")
    end

    test "download gradebook - download file with grades succesfully", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      user_1 = insert(:user, name: "User1")
      user_2 = insert(:user, name: "User2")
      enroll_user_to_section(user_1, section, :context_learner)
      enroll_user_to_section(user_2, section, :context_learner)

      resource_access_1 =
        insert(:resource_access,
          user: user_1,
          section: section,
          resource: page_revision.resource,
          score: 90.1,
          out_of: @out_of
        )

      resource_access_2 =
        insert(:resource_access,
          user: user_2,
          section: section,
          resource: page_revision.resource,
          score: 120,
          out_of: @out_of
        )

      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element(
        "a[href=\"#{Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, section.slug)}\"]",
        "Download Gradebook"
      )
      |> render_click()

      conn =
        get(
          conn,
          Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, section.slug)
        )

      assert response(conn, 200) =~
               "Student,Progress test revision\r\n    Points Possible,#{@out_of}\r\n#{user_1.name} (#{user_1.email}),#{resource_access_1.score}\r\n#{user_2.name} (#{user_2.email}),#{resource_access_2.score}\r\n"
    end

    test "download gradebook - download file without grades succesfully", %{
      conn: conn,
      section: section
    } do
      user_1 = insert(:user, name: "User1")
      user_2 = insert(:user, name: "User2")
      enroll_user_to_section(user_1, section, :context_learner)
      enroll_user_to_section(user_2, section, :context_learner)

      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element(
        "a[href=\"#{Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, section.slug)}\"]",
        "Download Gradebook"
      )
      |> render_click()

      conn =
        get(
          conn,
          Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, section.slug)
        )

      assert response(conn, 200) =~
               "Student,Progress test revision\r\n    Points Possible,\r\n#{user_1.name} (#{user_1.email}),\r\n#{user_2.name} (#{user_2.email}),\r\n"
    end
  end

  describe "fetching invalid access token" do
    setup [:admin_conn, :create_section_with_invalid_registration]

    test "test connection - shows error on failure to obtain access token", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element("button[phx-click=\"test_connection\"]")
      |> render_click()

      assert has_element?(view, "samp", "Starting test")
      assert has_element?(view, "samp", "Requesting access token...")
      assert has_element?(view, "samp", "error fetching access token")
    end

    test "update line items - shows error on failure to obtain access token",
         %{
           conn: conn,
           section: section
         } do
      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element(
        "a[phx-click=\"send_line_items\"]",
        "Update LMS Line Items"
      )
      |> render_click()

      assert has_element?(view, "div.alert.alert-danger", "Error getting LMS access token")
    end

    test "sync grades - shows error on failure to obtain access token",
         %{
           conn: conn,
           section: section
         } do
      user = insert(:user)
      enroll_user_to_section(user, section, :context_learner)

      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element(
        "a[phx-click=\"send_grades\"]",
        "Synchronize Grades"
      )
      |> render_click()

      assert has_element?(view, "div.alert.alert-danger", "error fetching access token")
    end
  end
end
