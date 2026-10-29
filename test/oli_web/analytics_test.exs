defmodule OliWeb.AnalyticsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Oli.Accounts.{Author, SystemRole, User}
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Resources.{ResourceType, Revision}
  alias OliWeb.Analytics
  alias Phoenix.LiveView.{JS, Socket, Utils}

  @section %Section{id: 9_876, slug: "private-section", base_project_id: 42}
  @learner %User{id: 5_555, guest: false, independent_learner: true}

  setup do
    original = Application.fetch_env(:oli, :analytics)
    Application.put_env(:oli, :analytics, gtm_container_id: "GTM-QA123")

    on_exit(fn ->
      case original do
        :error -> Application.delete_env(:oli, :analytics)
        {:ok, value} -> Application.put_env(:oli, :analytics, value)
      end
    end)
  end

  defp page(attrs) do
    struct(
      %Revision{resource_type_id: ResourceType.id_for_page(), content: %{}, graded: false},
      attrs
    )
  end

  defp context(path, assigns),
    do: Analytics.page_context("https://torus.example" <> path, assigns)

  test "controller and LiveView context contains templates and generic areas/titles only" do
    for {path, template, area, title, extra} <- [
          {"/sections/private-course/lesson/private-page?search=private",
           "/sections/:section_slug/lesson/:revision_slug", "delivery", "Learning", %{}},
          {"/users/reset_password/private-token", "/users/reset_password/:token", "public",
           "Torus", %{}},
          {"/authors/reset_password/private-token", "/authors/reset_password/:token", "public",
           "Torus", %{}},
          {"/users/confirm/private-token", "/users/confirm/:token", "public", "Torus", %{}},
          {"/authors/invite/private-token", "/authors/invite/:token", "public", "Torus", %{}},
          {"/collaborators/invite/private-token", "/collaborators/invite/:token", "public",
           "Torus", %{}},
          {"/sections/join/private-invitation", "/sections/join/:section_invite_slug", "delivery",
           "Learning", %{}},
          {"/workspaces/course_author", "/workspaces/course_author", "authoring", "Authoring",
           %{}},
          {"/workspaces/instructor", "/workspaces/instructor", "instructor", "Instructor", %{}},
          {"/sections/private-course/instructor_dashboard/overview",
           "/sections/:section_slug/instructor_dashboard/:view", "instructor", "Instructor", %{}},
          {"/sections/private-course/schedule", "/sections/:section_slug/schedule", "instructor",
           "Instructor", %{}},
          {"/sections/private-course/adaptive_lesson/private-page",
           "/sections/:section_slug/adaptive_lesson/:revision_slug", "delivery", "Learning",
           %{page_type: "adaptive"}},
          {"/admin/users", "/admin/users", "admin", "Administration", %{}}
        ] do
      context = context(path, %{page_title: "Private title"})

      assert context ==
               Map.merge(
                 %{
                   page_path: template,
                   page_area: area,
                   page_title: title,
                   traffic_type: "external"
                 },
                 extra
               )

      refute Jason.encode!(context) =~ "private"
      refute Jason.encode!(context) =~ "Private title"
    end
  end

  test "unknown, LTI and card-entry routes are excluded" do
    for path <- ["/does-not-exist", "/sections/private/payment/new", "/lti/launch"] do
      assert Analytics.page_context("https://torus.example" <> path) == nil
    end
  end

  test "system admins are internal, other sessions are external" do
    admin = %Author{system_role_id: SystemRole.role_id().system_admin}

    assert Analytics.page_context("/workspaces/course_author", %{current_author: admin}).traffic_type ==
             "internal"

    assert Analytics.page_context("/workspaces/course_author").traffic_type == "external"
  end

  test "delivery context carries role, base project course and entry point, never identifiers" do
    assigns = %{current_user: @learner, section: @section}

    assert %{
             user_role: "learner",
             course_id: 42,
             entry_point: "direct",
             page_area: "delivery"
           } = context = context("/sections/private-section", assigns)

    refute Map.has_key?(context, :page_type)
    refute Map.has_key?(context, :preview_mode)
    encoded = Jason.encode!(context)
    refute encoded =~ "9876"
    refute encoded =~ "5555"
    refute encoded =~ "private-section"

    lms_user = %User{@learner | independent_learner: false}

    assert context("/sections/private-section", %{assigns | current_user: lms_user}).entry_point ==
             "lti"

    guest = %User{@learner | guest: true}

    assert context("/sections/private-section", %{assigns | current_user: guest}).user_role ==
             "guest"
  end

  test "roles follow admin, authoring, instructor, guest and learner precedence" do
    admin = %Author{system_role_id: SystemRole.role_id().content_admin}
    author = %Author{system_role_id: SystemRole.role_id().author}
    project = %Project{id: 7}

    assert context("/sections/private-section", %{current_user: @learner, current_author: admin}).user_role ==
             "admin"

    assert context("/admin/users", %{current_author: author}).user_role == "admin"

    assert %{user_role: "author", course_id: 7} =
             context("/workspaces/course_author/7/overview", %{
               current_author: author,
               project: project,
               section: @section
             })

    assert %{user_role: "instructor", course_id: 42, page_area: "instructor"} =
             context("/sections/private-section/instructor_dashboard/overview", %{
               current_user: @learner,
               section: @section
             })

    assert %{user_role: "author"} = context("/users/log_in", %{current_author: author})
    refute Map.has_key?(context("/users/log_in", %{}), :user_role)
  end

  test "previews are flagged, and instructors previewing a section are instructors" do
    assigns = %{current_user: @learner, section: @section}

    assert %{user_role: "instructor", preview_mode: "preview", course_id: 42} =
             context("/sections/private-section/preview/learn", assigns)

    assert %{preview_mode: "preview"} =
             context("/sections/private-section/learn", Map.put(assigns, :preview_mode, true))

    assert %{user_role: "author", preview_mode: "template_preview"} =
             context("/sections/private-section", Map.put(assigns, :template_preview_mode, true))

    assert %{preview_mode: "preview", user_role: "author"} =
             context("/authoring/project/private-project/preview", %{
               current_author: %Author{system_role_id: SystemRole.role_id().author}
             })
  end

  test "page type comes from the page revision" do
    for {attrs, expected} <- [
          {%{content: %{"advancedDelivery" => true}, graded: true}, "adaptive"},
          {%{graded: true}, "graded"},
          {%{purpose: :application}, "exploration"},
          {%{purpose: :deliberate_practice}, "practice"},
          {%{}, "practice"},
          {%{resource_type_id: ResourceType.id_for_container()}, "other"}
        ] do
      assigns = %{current_user: @learner, section: @section, page_context: %{page: page(attrs)}}

      assert context("/sections/private-section/lesson/private-page", assigns).page_type ==
               expected
    end

    hard_load = %{current_user: @learner, section: @section, page_revision: page(graded: true)}

    assert context("/sections/private-section/lesson/private-page", hard_load).page_type ==
             "graded"

    connected = Map.put(hard_load, :page_context, %{page: page(%{})})

    assert context("/sections/private-section/lesson/private-page", connected).page_type ==
             "practice"
  end

  test "a mounted subject keeps its inputs and only fills missing course and page data" do
    mounted = Analytics.subject(%{current_user: @learner, section: @section})
    slimmed = %{current_user: %User{id: 5_555}, section: %Section{id: 9_876}}

    assert %{user: :independent, section_course_id: 42} = Analytics.subject(slimmed, mounted)

    late = Analytics.subject(%{project: %Project{id: 7}}, Analytics.subject(%{}))
    assert late.project_course_id == 7
  end

  describe "track/3" do
    defp connected_socket, do: %Socket{transport_pid: self()}

    test "pushes only catalogued event parameters for the browser writer" do
      socket =
        Analytics.track(connected_socket(), "attempt_submitted", %{
          activity_type: "oli_multiple_choice"
        })

      assert Utils.get_push_events(socket) == [
               [
                 "analytics:track",
                 %{name: "attempt_submitted", params: %{"activity_type" => "oli_multiple_choice"}}
               ]
             ]
    end

    test "drops uncatalogued, invalid and context parameters with a warning" do
      log =
        capture_log(fn ->
          socket =
            Analytics.track(connected_socket(), "feature_used", %{
              "feature_name" => "outline_opened",
              "course_id" => 42,
              "user_id" => 5_555
            })

          assert [["analytics:track", %{params: %{"feature_name" => "outline_opened"}}]] =
                   Utils.get_push_events(socket)

          socket = Analytics.track(connected_socket(), "feature_used", %{feature_name: "nope"})
          assert [["analytics:track", %{params: params}]] = Utils.get_push_events(socket)
          assert params == %{}
        end)

      assert log =~
               "feature_used dropped parameters not allowed by the catalog: course_id, user_id"

      assert log =~ "feature_used dropped parameters not allowed by the catalog: feature_name"
      refute log =~ "5555"
      refute log =~ "nope"
    end

    test "uncatalogued events, disabled deployments and dead renders push nothing" do
      log =
        capture_log(fn ->
          assert Utils.get_push_events(Analytics.track(connected_socket(), "page_exited")) == []
        end)

      assert log =~ "Dropped analytics event not in the catalog: \"page_exited\""

      assert Utils.get_push_events(Analytics.track(%Socket{}, "page_entered")) == []

      Application.put_env(:oli, :analytics, gtm_container_id: nil)
      assert Utils.get_push_events(Analytics.track(connected_socket(), "page_entered")) == []
    end
  end

  test "js_track/3 appends a validated browser dispatch" do
    js = Analytics.js_track(%JS{}, "feature_used", %{feature_name: "dot_opened", page_id: 1})
    assert [["dispatch", %{event: "phx:analytics:track", detail: detail}]] = js.ops
    assert detail == %{name: "feature_used", params: %{"feature_name" => "dot_opened"}}

    capture_log(fn ->
      assert Analytics.js_track(%JS{}, "page_exited", %{}) == %JS{}
    end)
  end
end
