defmodule OliWeb.GradesLiveTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Phoenix.ConnTest
  import Oli.Factory
  import Mox

  alias Oli.Test.MockHTTP
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Utils
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Resources.ResourceType
  alias OliWeb.Delivery.Student.Utils, as: StudentUtils

  defp live_view_grades_route(section_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradesLive, section_slug)
  end

  # A small two-unit hierarchy for suppression tests. `insert(:section, ...)` already wires
  # up a working LTI deployment/registration by default (see `section_factory/0` in
  # `test/support/factory.ex`), so `GradesLive.mount/3`'s deployment/registration lookup
  # succeeds without any extra LTI fixture setup.
  defp create_section_with_hierarchy(%{conn: conn, user: user}) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        title: "Page 1",
        graded: true
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        title: "Page 2",
        graded: true
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        title: "Page 3",
        graded: true
      )

    module_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        children: [page_1_revision.resource_id],
        title: "Module 1"
      )

    module_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        children: [page_2_revision.resource_id, page_3_revision.resource_id],
        title: "Module 2"
      )

    unit_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        children: [module_1_revision.resource_id],
        title: "Unit 1"
      )

    unit_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        children: [module_2_revision.resource_id],
        title: "Unit 2"
      )

    container_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        children: [unit_1_revision.resource_id, unit_2_revision.resource_id],
        title: "Root Container"
      )

    all_revisions = [
      page_1_revision,
      page_2_revision,
      page_3_revision,
      module_1_revision,
      module_2_revision,
      unit_1_revision,
      unit_2_revision,
      container_revision
    ]

    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, project_id: project.id, resource_id: revision.resource_id)
    end)

    publication =
      insert(:publication, project: project, root_resource_id: container_revision.resource_id)

    Enum.each(all_revisions, fn revision ->
      insert(:published_resource,
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      )
    end)

    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    Sections.enroll(user.id, section.id, [
      Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
    ])

    [
      conn: conn,
      section: section,
      unit_1: unit_1_revision,
      unit_2: unit_2_revision,
      module_1: module_1_revision,
      module_2: module_2_revision,
      page_1: page_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision
    ]
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

    {:ok,
     section: section,
     unit_one_revision: _unit_one_revision,
     page_revision: page_revision,
     page_2_revision: page_2_revision} =
      section_with_assessment(%{}, deployment)

    [section: section, page_revision: page_revision, page_2_revision: page_2_revision]
  end

  defp create_section_with_invalid_registration(_conn) do
    registration =
      insert(:lti_registration, %{
        client_id: "error"
      })

    deployment = insert(:lti_deployment, %{registration: registration})

    {:ok,
     section: section,
     unit_one_revision: _unit_one_revision,
     page_revision: _page_revision,
     page_2_revision: _page_2_revision} =
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
        "/users/log_in"

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
        "/users/log_in"

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

      assert has_element?(view, "h2", "Manage Scores")
    end
  end

  describe "grade sync assessment selector" do
    setup [:user_conn, :create_section_with_hierarchy]

    test "shows suppression-aware container labels when a top-level unit is unnumbered", %{
      conn: conn,
      section: section,
      unit_1: unit_1
    } do
      {:ok, section} =
        Sections.update_section(section, %{unnumbered_unit_ids: [unit_1.resource_id]})

      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      select_html = view |> element(~s{select#assignment_grade_sync_select}) |> render()

      # Page 1 is nested under the suppressed Unit 1 (via Module 1), so it shows no
      # container-number prefix at all, matching how Learn presents a suppressed unit.
      assert select_html =~ "Page 1"
      refute select_html =~ "Unit 1: Page 1"
      refute select_html =~ "Module 1: Page 1"

      # Page 2 is nested under Unit 2 / Module 2. Unit 1 being suppressed means Module 1
      # (nested inside it) never consumes a numbering slot, so Module 2 becomes "Module 1"
      # instead of the raw "Module 2" -- this is the exact bug reported in the ticket.
      refute select_html =~ "Module 2: Page 2"
      assert select_html =~ "Module 1: Page 2"
    end
  end

  describe "fetching valid access token" do
    setup [:admin_conn, :create_section]
    @out_of 120.0

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
      |> element("button[phx-click='test_connection']")
      |> render_click()

      wait_while(fn -> not has_element?(view, "samp", "Requesting line items...") end)

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
      page_revision: page_revision,
      page_2_revision: page_2_revision
    } do
      url_line_items = section.line_items_service_url <> "?limit=1000"

      expect(MockHTTP, :get, fn ^url_line_items, _headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: "[
              {\"id\": \"1\", \"label\":\"#{page_revision.title}\", \"resourceId\":\"oli-torus-#{page_revision.resource_id}\", \"scoreMaximum\":1.0},
              {\"id\": \"2\", \"label\":\"#{page_2_revision.title}\", \"resourceId\":\"oli-torus-#{page_2_revision.resource_id}\", \"scoreMaximum\":1.0}
              ]"
         }}
      end)

      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element(
        "a[phx-click='send_line_items']",
        "Update LMS Line Items"
      )
      |> render_click()

      assert has_element?(view, "div#flash", "LMS line items already up to date")
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
        "a[phx-click='send_line_items']",
        "Update LMS Line Items"
      )
      |> render_click()

      assert has_element?(view, "div#flash", "Error accessing LMS line items")
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
        "a[phx-click='send_grades']",
        "Synchronize Scores"
      )
      |> render_click()

      assert has_element?(view, "p", "Pending score updates: 0")
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
        "a[phx-click='send_grades']",
        "Synchronize Scores"
      )
      |> render_click()

      assert has_element?(view, "p", "Pending score updates: 1")

      # Button disabled until it is finished
      assert view
             |> has_element?(
               "a[phx-click='send_grades'][disabled]",
               "Synchronize Scores"
             )

      payload = %Oli.Delivery.Attempts.PageLifecycle.GradeUpdatePayload{
        resource_access_id: resource_access.id,
        job: %{id: 1},
        status: :success,
        details: nil
      }

      # Send success grade update message
      send(view.pid, {:lms_grade_update_result, payload})

      # Button is enabled again once the sync is finished
      refute view
             |> has_element?(
               "a[phx-click='send_grades'][disabled]",
               "Synchronize Scores"
             )
    end

    test "sync grades - select other resource", %{
      conn: conn,
      section: section,
      page_revision: page_revision,
      page_2_revision: page_2_revision
    } do
      [user_1, user_2, user_3] = user_list = insert_list(3, :user)
      for user <- user_list, do: enroll_user_to_section(user, section, :context_learner)

      [resource_access_1, resource_access_2] =
        for user <- [user_1, user_2],
            do:
              insert(:resource_access,
                user: user,
                section: section,
                resource: page_revision.resource,
                score: 99
              )

      resource_access_3 =
        insert(:resource_access,
          user: user_3,
          section: section,
          resource: page_2_revision.resource,
          score: 120
        )

      for res_acc <- [resource_access_1, resource_access_2, resource_access_3],
          do: insert(:resource_attempt, resource_access: res_acc)

      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      # Renders both resources
      assert view |> element("option[value=#{page_revision.resource_id}]")
      assert view |> element("option[value=#{page_2_revision.resource_id}]")

      # Synchronize for first page
      view
      |> element("a[phx-click='send_grades']", "Synchronize Scores")
      |> render_click()

      assert has_element?(view, "p", "Pending score updates: 2")

      # Change page
      view
      |> element("select[phx-change=select_page]")
      |> render_change(%{"resource_id" => page_2_revision.resource_id})

      # Synchronize for second page
      view
      |> element("a[phx-click='send_grades']", "Synchronize Scores")
      |> render_click()

      assert has_element?(view, "p", "Pending score updates: 1")
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
        "Download Scorebook"
      )
      |> render_click()

      conn =
        get(
          conn,
          Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, section.slug)
        )

      user_1_name = Utils.name(user_1.name, user_1.given_name, user_1.family_name)
      user_2_name = Utils.name(user_2.name, user_2.given_name, user_2.family_name)

      score_1 = resource_access_1.score
      out_of_1 = resource_access_1.out_of
      score_2 = resource_access_2.score
      out_of_2 = resource_access_2.out_of

      assert response(conn, 200) =~
               """
               Status,Name,Email,LMS ID,Progress Test Revision - Points Earned,Progress Test Revision - Points Possible,Progress Test Revision - Percentage,Other Test Revision - Points Earned,Other Test Revision - Points Possible,Other Test Revision - Percentage\r
               Enrolled,\"#{user_1_name}\",#{user_1.email},#{user_1.sub},#{StudentUtils.parse_score(score_1)},#{StudentUtils.parse_score(out_of_1)},#{StudentUtils.parse_percentage(score_1, out_of_1)},,,\r
               Enrolled,\"#{user_2_name}\",#{user_2.email},#{user_2.sub},#{StudentUtils.parse_score(score_2)},#{StudentUtils.parse_score(out_of_2)},#{StudentUtils.parse_percentage(score_2, out_of_2)},,,\r
               """
    end

    test "download gradebook - download file without grades successfully", %{
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
        "Download Scorebook"
      )
      |> render_click()

      conn =
        get(
          conn,
          Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, section.slug)
        )

      user_1_name = Utils.name(user_1.name, user_1.given_name, user_1.family_name)
      user_2_name = Utils.name(user_2.name, user_2.given_name, user_2.family_name)

      assert response(conn, 200) =~
               """
               Status,Name,Email,LMS ID,Progress Test Revision - Points Earned,Progress Test Revision - Points Possible,Progress Test Revision - Percentage,Other Test Revision - Points Earned,Other Test Revision - Points Possible,Other Test Revision - Percentage\r
               Enrolled,\"#{user_1_name}\",#{user_1.email},#{user_1.sub},,,,,,\r
               Enrolled,\"#{user_2_name}\",#{user_2.email},#{user_2.sub},,,,,,\r
               """
    end
  end

  describe "fetching invalid access token" do
    setup [:admin_conn, :create_section_with_invalid_registration]

    @tag :flaky
    test "test connection - shows error on failure to obtain access token", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element("button[phx-click='test_connection']")
      |> render_click()

      assert has_element?(view, "samp", "Starting test")
      assert has_element?(view, "samp", "Requesting access token...")
      Process.sleep(200)

      wait_until(fn -> has_element?(view, "samp", "error fetching access token") end)

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
        "a[phx-click='send_line_items']",
        "Update LMS Line Items"
      )
      |> render_click()

      assert has_element?(view, "div#flash", "Error getting LMS access token")
    end
  end
end
