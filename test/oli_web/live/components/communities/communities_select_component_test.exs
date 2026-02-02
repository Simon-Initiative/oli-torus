defmodule OliWeb.Live.Components.Communities.CommunitiesSelectComponentTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import LiveComponentTests
  require Ecto.Query
  import Oli.Factory

  alias Oli.Groups
  alias OliWeb.Live.Components.Communities.CommunitiesSelectComponent

  describe "CommunitiesSelectComponent" do
    setup do
      user = insert(:user)
      institution = insert(:institution)

      community1 = insert(:community, name: "Alpha Community")
      community2 = insert(:community, name: "Beta Community")
      community3 = insert(:community, name: "Gamma Community")

      # Associate community1 directly with user
      {:ok, _} = Groups.create_community_account(%{user_id: user.id, community_id: community1.id})

      # Associate community2 with institution
      {:ok, _} =
        Groups.create_community_institution(%{
          institution_id: institution.id,
          community_id: community2.id
        })

      %{
        user: user,
        institution: institution,
        communities: [community1, community2, community3],
        direct_community: community1,
        institution_community: community2,
        available_community: community3
      }
    end

    test "renders display mode with current communities", %{
      conn: conn,
      user: user,
      institution: institution,
      direct_community: direct_community
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, CommunitiesSelectComponent, %{
          id: "test-communities",
          user_id: user.id,
          institution: institution,
          disabled_edit: false
        })

      assert has_element?(component, "ul[aria-label='Communities'] li", direct_community.name)
      refute has_element?(component, "input")
      refute has_element?(component, "button", "X")
    end

    test "renders empty display when no communities", %{conn: conn} do
      user_without_communities = insert(:user)
      # Pass nil institution to ensure no institution communities are shown
      {:ok, component, _html} =
        live_component_isolated(conn, CommunitiesSelectComponent, %{
          id: "test-communities",
          user_id: user_without_communities.id,
          institution: nil,
          disabled_edit: false
        })

      refute has_element?(component, "ul[aria-label='Communities'] li")
      assert has_element?(component, "div", "Click to add communities...")
    end

    test "renders readonly mode with disabled_edit=true", %{
      conn: conn,
      user: user,
      institution: institution,
      direct_community: direct_community
    } do
      {:ok, _component, html} =
        live_component_isolated(conn, CommunitiesSelectComponent, %{
          id: "test-communities",
          user_id: user.id,
          institution: institution,
          disabled_edit: true
        })

      # Should show community as link in readonly mode
      assert html =~ direct_community.name
      # Should have the gray background class for readonly
      assert html =~ "bg-[var(--color-gray-100)]"
    end

    test "edit mode shows input and remove buttons for direct communities", %{
      conn: conn,
      user: user,
      institution: institution,
      direct_community: direct_community
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, CommunitiesSelectComponent, %{
          id: "test-communities",
          user_id: user.id,
          institution: institution,
          disabled_edit: false
        })

      # Enter edit mode
      component |> element("div[phx-click='toggle_edit']") |> render_click()

      # Should show input and remove buttons in edit mode
      assert has_element?(component, "input")
      assert has_element?(component, "button", "X")

      assert has_element?(
               component,
               "ul[aria-label='Selected communities'] li",
               direct_community.name
             )
    end

    test "institution communities are shown without remove button", %{
      conn: conn,
      user: user,
      institution: institution,
      institution_community: institution_community
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, CommunitiesSelectComponent, %{
          id: "test-communities",
          user_id: user.id,
          institution: institution,
          disabled_edit: false
        })

      # Enter edit mode
      component |> element("div[phx-click='toggle_edit']") |> render_click()

      # Should show institution community with "(via institution)" label

      assert has_element?(
               component,
               "ul[aria-label='Communities via institution'] li",
               institution_community.name
             )

      assert render(component) =~ "(via institution)"
    end

    test "available communities are shown in edit mode dropdown", %{
      conn: conn,
      user: user,
      institution: institution,
      available_community: available_community
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, CommunitiesSelectComponent, %{
          id: "test-communities",
          user_id: user.id,
          institution: institution,
          disabled_edit: false
        })

      # Enter edit mode
      component |> element("div[phx-click='toggle_edit']") |> render_click()

      # Should show available communities in dropdown
      assert has_element?(
               component,
               "button[phx-click='add_community']",
               available_community.name
             )
    end

    test "handle_keydown with Escape exits edit mode", %{
      conn: conn,
      user: user,
      institution: institution
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, CommunitiesSelectComponent, %{
          id: "test-communities",
          user_id: user.id,
          institution: institution,
          disabled_edit: false
        })

      # Enter edit mode
      component |> element("div[phx-click='toggle_edit']") |> render_click()
      assert has_element?(component, "input")

      # Press Escape
      component
      |> element("input")
      |> render_keydown(%{key: "Escape"})

      # Should exit edit mode
      refute has_element?(component, "input")
    end

    test "communities are displayed in order (most recent first)", %{
      conn: conn,
      institution: institution
    } do
      user = insert(:user)
      community_old = insert(:community, name: "Old Community")
      community_new = insert(:community, name: "New Community")

      # Add old community first
      {:ok, ca_old} =
        Groups.create_community_account(%{user_id: user.id, community_id: community_old.id})

      # Update to make it older
      Oli.Repo.update_all(
        Ecto.Query.from(ca in Oli.Groups.CommunityAccount, where: ca.id == ^ca_old.id),
        set: [inserted_at: ~U[2024-01-01 10:00:00Z]]
      )

      # Add new community
      {:ok, _} =
        Groups.create_community_account(%{user_id: user.id, community_id: community_new.id})

      {:ok, _component, html} =
        live_component_isolated(conn, CommunitiesSelectComponent, %{
          id: "test-communities",
          user_id: user.id,
          institution: institution,
          disabled_edit: false
        })

      # New community should appear before old community
      new_index = :binary.match(html, "New Community") |> elem(0)
      old_index = :binary.match(html, "Old Community") |> elem(0)

      assert new_index < old_index
    end

    test "no institution shows only direct communities", %{
      conn: conn,
      user: user,
      direct_community: direct_community
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, CommunitiesSelectComponent, %{
          id: "test-communities",
          user_id: user.id,
          institution: nil,
          disabled_edit: false
        })

      # Should show direct community
      assert has_element?(component, "ul[aria-label='Communities'] li", direct_community.name)
      # Should not show any institution communities (in display mode, all are shown in one list)
      html = render(component)
      refute html =~ "(via institution)"
    end

    test "search filters available communities", %{
      conn: conn,
      user: user,
      institution: institution
    } do
      # Create additional communities for search testing
      insert(:community, name: "Searchable Alpha")
      insert(:community, name: "Searchable Beta")
      insert(:community, name: "Other Community")

      {:ok, component, _html} =
        live_component_isolated(conn, CommunitiesSelectComponent, %{
          id: "test-communities",
          user_id: user.id,
          institution: institution,
          disabled_edit: false
        })

      # Enter edit mode
      component |> element("div[phx-click='toggle_edit']") |> render_click()

      # Search for "Searchable"
      component
      |> element("input")
      |> render_keyup(%{value: "Searchable"})

      html = render(component)
      assert html =~ "Searchable Alpha"
      assert html =~ "Searchable Beta"
      refute html =~ "Other Community"
    end
  end
end
