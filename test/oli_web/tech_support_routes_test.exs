defmodule OliWeb.TechSupportRoutesTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "authoring layout" do
    test "student log in has two tech support buttons", %{conn: conn} do
      conn = get(conn, "/")

      response_parsed = html_response(conn, 200) |> Floki.parse_document!()

      assert response_parsed
             |> Floki.find("span#tech_support_student_sign_in[phx-click]")
             |> Floki.text() =~ "contact our support team."

      assert response_parsed
             |> Floki.find("span#tech_support_navbar_sign_in[phx-click]")
             |> Floki.text() =~ "Support"
    end

    test "other log in pages has one tech support buttons/links", %{conn: conn} do
      conn = get(conn, "/instructors/log_in")

      response_parsed = html_response(conn, 200) |> Floki.parse_document!()

      assert response_parsed
             |> Floki.find("span#tech_support_navbar_sign_in[phx-click]")
             |> Floki.text() =~ "Support"
    end
  end

  describe "delivery" do
    setup [:user_conn]

    test "instructor workspace (not independent)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor")

      assert view
             |> element("span#tech_support_is_not_independet_instructor[phx-click]")
             |> render() =~ "contact support."
    end

    test "instructor workspace", %{conn: conn} do
      [user] = Oli.Repo.all(Oli.Accounts.User)
      _instructor = Oli.Accounts.update_user(user, %{can_create_sections: true})
      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor")

      assert view
             |> element("button#tech_support_workspace_sidebar_nav[phx-click]")
             |> render() =~ "Support"
    end
  end

  describe "student" do
    setup [:prepare_session]

    test "enroll page", %{conn: conn, section: section} do
      conn = get(conn, "/sections/#{section.slug}/enroll")
      response_parsed = html_response(conn, 200) |> Floki.parse_document!()

      assert response_parsed
             |> Floki.find("div#trigger-tech-support-modal")
             |> Floki.text()

      assert response_parsed
             |> Floki.find("span#tech_support_enroll_top_navbar")
             |> Floki.text()
    end
  end

  defp prepare_session(%{conn: conn}) do
    author = author_fixture()

    %{project: project, institution: institution} = Oli.Seeder.base_project_with_resource(author)

    tool_jwk = jwk_fixture()

    registration = registration_fixture(%{tool_jwk_id: tool_jwk.id})

    deployment =
      deployment_fixture(%{institution_id: institution.id, registration_id: registration.id})

    section =
      section_fixture(%{
        institution_id: institution.id,
        lti_1p3_deployment_id: deployment.id,
        base_project_id: project.id
      })

    {:ok, conn: conn, author: author, institution: institution, section: section}
  end
end

# /sections/#{section_slug}/enroll
