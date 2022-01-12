defmodule OliWeb.UserActionsTest do
  use OliWeb.ConnCase
  use Surface.LiveViewTest

  import Oli.Factory

  alias OliWeb.Users.Actions

  describe "email confirmation" do
    @author_assigns %{csrf_token: "token", for_author: true}

    test "shows email confirmation buttons when author account was created but not confirmed yet" do
      non_confirmed_author = insert(:author, email_confirmation_token: "token")
      assigns = %{user: non_confirmed_author, csrf_token: "token", for_author: true}

      html = render_actions(assigns)

      assert html =~ "Resend confirmation link"
      assert html =~ "Confirm email"
    end

    test "does not show email confirmation buttons when author account was created and confirmed" do
      confirmed_author = insert(:author, email_confirmed_at: Timex.now())
      assigns = Map.put(@author_assigns, :user, confirmed_author)

      html = render_actions(assigns)

      refute html =~ "Resend confirmation link"
      refute html =~ "Confirm email"
    end

    test "does not show email confirmation buttons when author was invited by an admin and has not accepted yet" do
      invited_and_not_accepted_author = insert(:author, invitation_token: "token")
      assigns = Map.put(@author_assigns, :user, invited_and_not_accepted_author)

      html = render_actions(assigns)

      refute html =~ "Resend confirmation link"
      refute html =~ "Confirm email"
    end

    test "does not show email confirmation buttons when author was invited by an admin and accepted" do
      invited_author =
        insert(:author, invitation_token: "token", invitation_accepted_at: Timex.now())

      assigns = Map.put(@author_assigns, :user, invited_author)

      html = render_actions(assigns)

      refute html =~ "Resend confirmation link"
      refute html =~ "Confirm email"
    end

    test "shows email confirmation buttons when author was invited by an admin and accepted with a different email, but has not confirmed yet" do
      accepted_with_different_email_author =
        insert(:author,
          email_confirmation_token: "token",
          unconfirmed_email: "other_email",
          invitation_token: "token",
          invitation_accepted_at: Timex.now()
        )

      assigns = Map.put(@author_assigns, :user, accepted_with_different_email_author)

      html = render_actions(assigns)

      assert html =~ "Resend confirmation link"
      assert html =~ "Confirm email"
    end

    test "does not show email confirmation buttons when author was invited by an admin and accepted with a different email, and has confirmed his account" do
      accepted_and_confirmed_with_different_email_author =
        insert(:author,
          email_confirmed_at: Timex.now(),
          invitation_token: "token",
          invitation_accepted_at: Timex.now()
        )

      assigns =
        Map.put(@author_assigns, :user, accepted_and_confirmed_with_different_email_author)

      html = render_actions(assigns)

      refute html =~ "Resend confirmation link"
      refute html =~ "Confirm email"
    end
  end

  defp render_actions(assigns) do
    render_surface do
      ~F"""
      <Actions user={@user} csrf_token={@csrf_token} for_author={@for_author}/>
      """
    end
  end
end
