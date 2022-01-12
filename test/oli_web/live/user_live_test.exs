defmodule OliWeb.UserLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  @live_view_author_index_route Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsView)

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the index view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authoring/session/new?request_path=%2Fadmin%2Fauthors"}}} =
        live(conn, @live_view_author_index_route)
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn]

    test "returns forbidden when accessing the index view", %{conn: conn} do
      conn = get(conn, @live_view_author_index_route)

      assert response(conn, 403)
    end
  end

  describe "index" do
    setup [:admin_conn]

    test "lists all authors", %{conn: conn, admin: admin} do
      {:ok, view, _html} = live(conn, @live_view_author_index_route)

      # returns 2 because of the admin account created in the seeds
      assert render(view) =~ "Showing all results (2 total)"

      assert has_element?(view, "tr, ##{admin.id}")
    end

    test "shows confirmation pending message when author account was created but not confirmed yet",
         %{conn: conn} do
      non_confirmed_author = insert(:author, email_confirmation_token: "token")

      {:ok, view, _html} = live(conn, @live_view_author_index_route)

      assert view
             |> element("##{non_confirmed_author.id} span[data-toggle=\"tooltip\"")
             |> render() =~ "Confirmation Pending"
    end

    test "shows email confirmed message when author account was created and confirmed", %{
      conn: conn
    } do
      confirmed_author = insert(:author, email_confirmed_at: Timex.now())
      {:ok, view, _html} = live(conn, @live_view_author_index_route)

      assert view
             |> element("##{confirmed_author.id} span[data-toggle=\"tooltip\"")
             |> render() =~ "Email Confirmed"
    end

    test "shows invitation pending message when author was invited by an admin and has not accepted yet",
         %{conn: conn} do
      invited_and_not_accepted_author = insert(:author, invitation_token: "token")
      {:ok, view, _html} = live(conn, @live_view_author_index_route)

      assert view
             |> element("##{invited_and_not_accepted_author.id} span[data-toggle=\"tooltip\"")
             |> render() =~ "Invitation Pending"
    end

    test "shows invitation accepted message when author was invited by an admin and accepted", %{
      conn: conn
    } do
      invited_author =
        insert(:author, invitation_token: "token", invitation_accepted_at: Timex.now())

      {:ok, view, _html} = live(conn, @live_view_author_index_route)

      assert view
             |> element("##{invited_author.id} span[data-toggle=\"tooltip\"")
             |> render() =~ "Invitation Accepted"
    end

    test "shows confirmation pending message when author was invited by an admin and accepted with a different email, but has not confirmed yet",
         %{conn: conn} do
      accepted_with_different_email_author =
        insert(:author,
          email_confirmation_token: "token",
          unconfirmed_email: "other_email",
          invitation_token: "token",
          invitation_accepted_at: Timex.now()
        )

      {:ok, view, _html} = live(conn, @live_view_author_index_route)

      assert view
             |> element(
               "##{accepted_with_different_email_author.id} span[data-toggle=\"tooltip\""
             )
             |> render() =~ "Confirmation Pending"
    end

    test "shows email confirmed message when author was invited by an admin and accepted with a different email, and has confirmed his account",
         %{conn: conn} do
      accepted_and_confirmed_with_different_email_author =
        insert(:author,
          email_confirmed_at: Timex.now(),
          invitation_token: "token",
          invitation_accepted_at: Timex.now()
        )

      {:ok, view, _html} = live(conn, @live_view_author_index_route)

      assert view
             |> element(
               "##{accepted_and_confirmed_with_different_email_author.id} span[data-toggle=\"tooltip\""
             )
             |> render() =~ "Email Confirmed"
    end
  end
end
