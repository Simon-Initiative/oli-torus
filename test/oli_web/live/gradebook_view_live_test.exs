defmodule OliWeb.GradebookViewLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  defp live_view_gradebook_view_route(section_slug) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Grades.GradebookView,
      section_slug
    )
  end

  describe "user cannot access when is not logged in" do
    setup [:section_with_assessment]

    test "redirects to login page when accessing the gradebook view", %{
      conn: conn,
      section: section
    } do
      redirect_path = "/users/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_gradebook_view_route(section.slug))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :section_with_assessment]

    test "redirects to login page when accessing the student view", %{
      conn: conn,
      section: section
    } do
      conn = get(conn, live_view_gradebook_view_route(section.slug))

      redirect_path = "/users/log_in"

      assert conn
             |> get(live_view_gradebook_view_route(section.slug))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"#{redirect_path}\">redirected</a>.</body></html>"
    end
  end

  describe "gradebook view" do
    setup [:admin_conn, :section_with_assessment]

    scores_expected_format = %{
      100.334 => 100.33,
      119.336 => 119.34,
      62.889 => 62.89,
      60.33333 => 60.33,
      90.10 => 90.10,
      120 => 120.0,
      0.0 => 0.0,
      0 => 0.0
    }

    for {score, expected_score} <- scores_expected_format do
      @score score
      @expected_score expected_score
      @out_of 120.0

      test "loads gradebook view table data correctly with score: #{score}", %{
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
            score: @score,
            out_of: @out_of
          )

        insert(:resource_attempt, resource_access: resource_access)

        {:ok, view, _html} = live(conn, live_view_gradebook_view_route(section.slug))

        assert view
               |> element(
                 "tr[phx-value-id='#{user.id}'] a[href=\"/sections/#{section.slug}/progress/#{user.id}/#{page_revision.resource.id}\"]"
               )
               |> render =~ "#{@expected_score}/#{@out_of}"
      end
    end

    test "table has classes to ensure overflow", %{conn: conn} do
      %{section: section} = create_project_with_n_scored_pages(conn, 30)

      user = insert(:user, %{family_name: "James", given_name: "LeBron"})
      enroll_user_to_section(user, section, :context_learner)

      {:ok, view, _html} = live(conn, live_view_gradebook_view_route(section.slug))

      # Check that the table is rendered with a horizontal scroll bar
      assert view
             |> element(~s(table[class="overflow-x-scroll block scrollbar"]))
    end
  end
end
