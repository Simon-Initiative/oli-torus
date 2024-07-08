defmodule OliWeb.Sections.InvalidSectionInviteViewTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  describe "course invitation with no student account" do
    test "redirects to the invalid message view if the link is invalid", %{conn: conn} do
      conn = get(conn, ~p"/sections/join/12345")

      assert conn.halted

      redirect_to = ~p"/sections/join/invalid"

      assert redirected_to(conn, 302) == redirect_to

      {:ok, view, _html} = live(conn, redirect_to)

      assert render(view) =~
               "This enrollment link has expired or is invalid. If you already have a student account, please <a href=\"/session/new\">sign in</a>.\n</div></div>"

      assert element(view, "a[href=\"/session/new\"]") |> render() =~ "sign in"
    end

    test "redirects to the Student Sign In page if the invitation link is valid", %{conn: conn} do
      section_invite_slig = "12345"
      %{section: section} = insert(:section_invite, slug: section_invite_slig)

      conn = get(conn, ~p"/sections/join/#{section_invite_slig}")

      assert conn.halted

      redirect_to =
        ~p"/session/new?request_path=%2Fsections%2Fjoin%2F#{section_invite_slig}&section=#{section.slug}&from_invitation_link%3F=true"

      assert redirected_to(conn, 302) == redirect_to

      conn = get(conn, redirect_to)

      assert html_response(conn, 200) =~ "Student Sign In"
    end
  end

  describe "course invitation with student account" do
    setup [:user_conn]

    test "redirects to the invalid message view if the link is invalid", %{conn: conn} do
      conn = get(conn, ~p"/sections/join/12345")

      redirect_to = ~p"/sections/join/invalid"

      assert redirected_to(conn, 302) == redirect_to

      {:ok, view, _html} = live(conn, redirect_to)

      assert render(view) =~
               "This enrollment link has expired or is invalid. If you already have a student account, please <a href=\"/session/new\">sign in</a>.\n</div></div>"
    end

    test "shows enroll view", %{conn: conn} do
      section_invite_slig = "12345"
      insert(:section_invite, slug: section_invite_slig)

      conn = get(conn, ~p"/sections/join/#{section_invite_slig}")

      assert html_response(conn, 200) =~ "Enroll in Course Section"
    end
  end
end
