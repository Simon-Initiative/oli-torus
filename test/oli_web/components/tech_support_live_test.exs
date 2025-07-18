defmodule OliWeb.Components.TechSupportLiveTest do
  use OliWeb.ConnCase
  import Phoenix.LiveViewTest
  import Oli.Factory

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

  describe "publisher-specific support and knowledge base link logic" do
    setup do
      # Set global default
      default_kb = "https://default.kb.example.com"
      original_vendor_property = Application.get_env(:oli, :vendor_property)

      Application.put_env(
        :oli,
        :vendor_property,
        Keyword.merge(Application.get_env(:oli, :vendor_property, []),
          knowledgebase_url: default_kb
        )
      )

      on_exit(fn ->
        if is_nil(original_vendor_property) do
          Application.delete_env(:oli, :vendor_property)
        else
          Application.put_env(:oli, :vendor_property, original_vendor_property)
        end
      end)

      :ok
    end

    test "displays publisher-specific knowledge base link", %{conn: conn} do
      publisher =
        insert(:publisher, knowledge_base_link: "https://custom.kb.com")

      project = insert(:project, publisher: publisher)
      session = %{"project" => project}

      {:ok, view, _} = live_isolated(conn, OliWeb.TechSupportLive, session: session)

      assert view |> has_element?(~s|a[href="https://custom.kb.com"]|)
    end

    test "falls back to global knowledge base link if publisher field is nil",
         %{conn: conn} do
      publisher = insert(:publisher, knowledge_base_link: nil)
      project = insert(:project, publisher: publisher)
      session = %{"project" => project}

      {:ok, view, _} = live_isolated(conn, OliWeb.TechSupportLive, session: session)

      assert view |> has_element?(~s|a[href="https://default.kb.example.com"]|)
    end

    test "falls back to global knowledge base link if no publisher", %{
      conn: conn
    } do
      project = insert(:project, publisher: nil)
      session = %{"project" => project}

      {:ok, view, _} = live_isolated(conn, OliWeb.TechSupportLive, session: session)

      assert view |> has_element?(~s|a[href="https://default.kb.example.com"]|)
    end
  end

  defp signin_admin(%{conn: conn}) do
    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().system_admin})
    conn = log_in_author(conn, admin)
    %{conn: conn, admin: admin}
  end
end
