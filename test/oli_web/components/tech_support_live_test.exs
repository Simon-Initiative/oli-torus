defmodule OliWeb.Components.TechSupportLiveTest do
  use OliWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "modal" do
    test "renders all fields", %{conn: conn} do
      session_data = %{"id" => "some_ide", "requires_sender_data" => true}

      {:ok, view, _} =
        live_isolated(conn, OliWeb.TechSupportLive, session: session_data)

      # Extra fields added when not having a user account
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

    test "omits requester info fields ", %{conn: conn} do
      session_data = %{"id" => "some_ide"}

      {:ok, view, _} =
        live_isolated(conn, OliWeb.TechSupportLive, session: session_data)

      # Extra fields are omitted when having access to a user account
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
end
