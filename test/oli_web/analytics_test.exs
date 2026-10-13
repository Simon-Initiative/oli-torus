defmodule OliWeb.AnalyticsTest do
  use ExUnit.Case, async: true

  alias Oli.Accounts.Author
  alias Oli.Accounts.SystemRole
  alias OliWeb.Analytics

  test "controller and LiveView context contains templates and generic areas/titles only" do
    for {path, template, area, title} <- [
          {"/sections/private-course/lesson/private-page?search=private",
           "/sections/:section_slug/lesson/:revision_slug", "delivery", "Learning"},
          {"/users/reset_password/private-token", "/users/reset_password/:token", "public",
           "Torus"},
          {"/authors/reset_password/private-token", "/authors/reset_password/:token", "public",
           "Torus"},
          {"/users/confirm/private-token", "/users/confirm/:token", "public", "Torus"},
          {"/authors/invite/private-token", "/authors/invite/:token", "public", "Torus"},
          {"/collaborators/invite/private-token", "/collaborators/invite/:token", "public",
           "Torus"},
          {"/sections/join/private-invitation", "/sections/join/:section_invite_slug", "delivery",
           "Learning"},
          {"/workspaces/course_author", "/workspaces/course_author", "authoring", "Authoring"},
          {"/workspaces/instructor", "/workspaces/instructor", "instructor", "Instructor"},
          {"/sections/private-course/instructor_dashboard/overview",
           "/sections/:section_slug/instructor_dashboard/:view", "instructor", "Instructor"},
          {"/sections/private-course/schedule", "/sections/:section_slug/schedule", "instructor",
           "Instructor"},
          {"/sections/private-course/adaptive_lesson/private-page",
           "/sections/:section_slug/adaptive_lesson/:revision_slug", "delivery", "Learning"},
          {"/admin/users", "/admin/users", "admin", "Administration"}
        ] do
      context =
        Analytics.page_context("https://torus.example" <> path, %{page_title: "Private title"})

      assert context == %{
               page_path: template,
               page_area: area,
               page_title: title,
               traffic_type: "external"
             }

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
end
