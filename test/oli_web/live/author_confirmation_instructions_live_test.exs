defmodule OliWeb.AuthorConfirmationInstructionsLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.Accounts
  alias Oli.Repo

  setup do
    %{
      author:
        author_fixture(%{
          email_verified: nil,
          email_confirmed_at: nil
        })
    }
  end

  describe "Resend confirmation" do
    test "renders the resend confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/authors/confirm")
      assert html =~ "Resend confirmation instructions"
    end

    test "sends a new confirmation token", %{conn: conn, author: author} do
      {:ok, lv, _html} = live(conn, ~p"/authors/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", author: %{email: author.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/authors/confirm")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Accounts.AuthorToken, author_id: author.id).context == "confirm"
    end

    test "does not send confirmation token if author is confirmed", %{conn: conn, author: author} do
      Repo.update!(Accounts.Author.confirm_changeset(author))

      {:ok, lv, _html} = live(conn, ~p"/authors/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", author: %{email: author.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/authors/confirm")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      refute Repo.get_by(Accounts.AuthorToken, author_id: author.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/authors/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", author: %{email: "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/authors/confirm")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Accounts.AuthorToken) == []
    end
  end
end
