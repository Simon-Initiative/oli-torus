defmodule OliWeb.StudentViewLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  defp live_view_student_view_route(section_slug, user_id) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Progress.StudentView,
      section_slug,
      user_id
    )
  end

  describe "user cannot access when is not logged in" do
    setup [:section_with_assessment]

    test "redirects to login when accessing the student view", %{
      conn: conn,
      section: section
    } do
      user = insert(:user)
      redirect_path = "/users/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_student_view_route(section.slug, user.id))
    end
  end

  describe "student cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :section_with_assessment]

    test "redirects to login when accessing the student view", %{
      conn: conn,
      section: section
    } do
      user = insert(:user)
      conn = get(conn, live_view_student_view_route(section.slug, user.id))

      redirect_path = "/users/log_in"

      assert conn
             |> get(live_view_student_view_route(section.slug, user.id))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"#{redirect_path}\">redirected</a>.</body></html>"
    end
  end

  describe "student view" do
    setup [:admin_conn, :section_with_assessment]

    scores_expected_format = %{
      1.334 => 1.33,
      1.336 => 1.34,
      4.889 => 4.89,
      7.33333 => 7.33,
      9.10 => 9.10,
      5 => 5.0,
      0.0 => 0.0,
      0 => 0.0
    }

    for {score, expected_score} <- scores_expected_format do
      @score score
      @expected_score expected_score
      @out_of 10.0

      test "loads student view data correctly with score #{score}", %{
        conn: conn,
        section: section,
        page_revision: page_revision
      } do
        user = insert(:user)

        resource_access =
          insert(:resource_access,
            user: user,
            resource: page_revision.resource,
            section: section,
            score: @score,
            out_of: @out_of
          )

        insert(:resource_attempt, resource_access: resource_access)

        {:ok, view, html} = live(conn, live_view_student_view_route(section.slug, user.id))

        assert html =~ "Progress Details for #{user.family_name}, #{user.given_name}"

        assert view
               |> element("tr[id=\"0\" phx-value-id='0']")
               |> render =~ "#{@expected_score} / #{@out_of}"

        assert view
               |> element("tr[id=\"0\" phx-value-id='0']")
               |> render =~
                 "<a href=\"/sections/#{section.slug}/progress/#{user.id}/#{page_revision.resource.id}\">#{page_revision.title}</a>"
      end
    end
  end
end
