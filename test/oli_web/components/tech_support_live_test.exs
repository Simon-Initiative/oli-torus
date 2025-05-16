defmodule OliWeb.Components.TechSupportLiveTest do
  use OliWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "without an account" do
    test "includes requester name and email fields since the user is not signed in", %{conn: conn} do
      {:ok, view, _} = live_isolated(conn, OliWeb.TechSupportLive)

      # Extra fields are added when no user account is present
      assert view
             |> has_element?(
               ~s|form div[phx-feedback-for="help[name]"] input[required="required"][name="help[name]"][placeholder="Enter Name"]|
             )

      assert view
             |> has_element?(
               ~s|form div[phx-feedback-for="help[email_address]"] input[required="required"][name="help[email_address]"][placeholder="Enter Email"]|
             )

      #  Remaining fields
      assert view
             |> has_element?(
               ~s|form div[phx-feedback-for="help[subject]"] select[required="required"][name="help[subject]"]|
             )

      assert view
             |> has_element?(
               ~s|form div[phx-feedback-for="help[message]"] textarea[required="required"][name="help[message]"]|
             )
    end
  end

  describe "with an account" do
    setup [:signin_admin]

    test "excludes name and email fields because they are taken from the account", %{conn: conn} do
      {:ok, view, _} = live_isolated(conn, OliWeb.TechSupportLive)

      # Extra fields are omitted when accessing a user account
      refute view
             |> has_element?(
               ~s|form div[phx-feedback-for="help[name]"] input[required="required"][name="help[name]"][placeholder="Enter Name"]|
             )

      refute view
             |> has_element?(
               ~s|form div[phx-feedback-for="help[email_address]"] input[required="required"][name="help[email_address]"][placeholder="Enter Email"]|
             )

      #  Remaining fields
      assert view
             |> has_element?(
               ~s|form div[phx-feedback-for="help[subject]"] select[required="required"][name="help[subject]"]|
             )

      assert view
             |> has_element?(
               ~s|form div[phx-feedback-for="help[message]"] textarea[required="required"][name="help[message]"]|
             )
    end
  end

  defp signin_admin(%{conn: conn}) do
    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().system_admin})
    conn = log_in_author(conn, admin)
    %{conn: conn, admin: admin}
  end
end
