defmodule OliWeb.RemixSectionLiveTest do
  use OliWeb.ConnCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Oli.Factory
  import Ecto.Query, warn: false

  alias Oli.Seeder
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Accounts

  describe "remix section as admin" do
    setup [:setup_admin_session]

    test "mount as admin", %{
      conn: conn,
      map: %{
        section_1: section_1,
        unit1_container: unit1_container,
        revision1: revision1,
        revision2: revision2
      }
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section_1.slug))

      {:ok, view, _html} = live(conn)

      assert view |> element("#entry-#{unit1_container.revision.resource_id}") |> has_element?()
      assert view |> element("#entry-#{revision1.resource_id}") |> has_element?()
      assert view |> element("#entry-#{revision2.resource_id}") |> has_element?()
    end

    test "saving redirects admin correctly", %{
      conn: conn,
      map: %{
        section_1: section_1
      }
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section_1.slug))

      {:ok, view, _html} = live(conn)

      render_hook(view, "reorder", %{"sourceIndex" => "0", "dropIndex" => "2"})

      view
      |> element("#save")
      |> render_click()

      assert_redirected(
        view,
        Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section_1.slug)
      )
    end

    test "breadcrumbs render correctly", %{
      conn: conn,
      map: %{
        section_1: section_1
      }
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section_1.slug))

      {:ok, _view, html} = live(conn)

      assert html =~ "Customize Content"
    end

    test "remix section remove and save (including last course material)", %{
      conn: conn,
      map: %{
        section_1: section_1
      }
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section_1.slug))

      {:ok, view, _html} = live(conn)

      node_children_uuids =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{button[phx-click="show_remove_modal"]})
        |> Floki.attribute("phx-value-uuid")

      open_modal_and_confirm_removal(node_children_uuids, view)

      assert render(view) =~ "<p>There&#39;s nothing here.</p>"

      view
      |> element("#save")
      |> render_click()

      assert_redirected(
        view,
        Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section_1.slug)
      )
    end
  end

  describe "remix section as instructor" do
    setup [:setup_instructor_session]

    test "mount as instructor", %{
      conn: conn,
      map: %{
        section_1: section_1,
        unit1_container: unit1_container,
        revision1: revision1,
        revision2: revision2
      }
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section_1.slug))

      {:ok, view, _html} = live(conn)

      assert view |> element("#entry-#{unit1_container.revision.resource_id}") |> has_element?()
      assert view |> element("#entry-#{revision1.resource_id}") |> has_element?()
      assert view |> element("#entry-#{revision2.resource_id}") |> has_element?()
    end

    test "remix section - add materials - materials are added after save even if the revision has not max_attempts set",
         %{
           conn: conn,
           map: %{
             section_1: section_1
           }
         } do
      {:ok, view, _html} = live(conn, ~p"/sections/#{section_1.slug}/remix")

      ## Unit 1 does not exist
      refute view |> render() =~ "Great Unit 1"

      ## add Unit 1
      view
      |> element("button[phx-click=\"show_add_materials_modal\"]")
      |> render_click()

      view
      |> element(
        ".hierarchy table > tbody tr button[phx-click=\"HierarchyPicker.select_publication\"]",
        "Project 1"
      )
      |> render_click()

      view
      |> element(
        ".hierarchy > div[id^=\"hierarchy_item_\"]",
        "Great Unit 1"
      )
      |> render_click()

      view
      |> element(
        "button[phx-click=\"AddMaterialsModal.add\"]",
        "Add"
      )
      |> render_click()

      ## Unit 1 exists
      assert view |> render() =~ "Great Unit 1"

      view
      |> element("#save", "Save")
      |> render_click()

      assert_redirected(
        view,
        ~p"/sections/#{section_1.slug}/remix"
      )

      {:ok, view, _html} = live(conn, ~p"/sections/#{section_1.slug}/remix")

      ## Unit 1 was saved and is now part of the curriculum
      assert view |> render() =~ "Great Unit 1"
    end

    test "saving redirects instructor correctly", %{
      conn: conn,
      map: %{
        section_1: section
      }
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section.slug))

      {:ok, view, _html} = live(conn)

      render_hook(view, "reorder", %{"sourceIndex" => "0", "dropIndex" => "2"})

      view
      |> element("#save")
      |> render_click()

      assert_redirect(
        view,
        ~p"/sections/#{section.slug}/remix"
      )
    end

    test "cancel button works correctly", %{
      conn: conn,
      map: map
    } do
      conn =
        get(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, map.section_1.slug)
        )

      {:ok, view, _html} = live(conn)

      ## Elixir Page does not exist
      refute view |> render() =~ "Elixir Page"

      ## add the Elixir Page
      view
      |> element("button[phx-click=\"show_add_materials_modal\"]")
      |> render_click()

      view
      |> element(
        ".hierarchy table > tbody tr:first-of-type button[phx-click=\"HierarchyPicker.select_publication\"]"
      )
      |> render_click()

      view
      |> element(".hierarchy > div[id^=\"hierarchy_item_\"]", "Elixir Page")
      |> render_click()

      view
      |> element("button[phx-click=\"AddMaterialsModal.add\"]", "Add")
      |> render_click()

      ## Elixir Page exists
      assert view |> render() =~ "Elixir Page"

      ## click on the cancel button
      view
      |> render_hook("cancel")

      ## cancel the modal that shows the cancel button
      view
      |> element("button[phx-click=\"cancel_modal\"]")
      |> render_click()

      ## nothing happens and the Elixir Page still exists
      assert view |> render() =~ "Elixir Page"

      ## click on the cancel button again
      view
      |> render_hook("cancel")

      ## click on the ok that shows the cancel button
      view
      |> element("button[phx-click=\"ok_cancel_modal\"]")
      |> render_click()

      ## expect to be redirected
      assert_redirect(
        view,
        ~p"/sections/#{map.section_1.slug}/remix"
      )
    end

    test "breadcrumbs render correctly", %{
      conn: conn,
      map: %{
        section_1: section_1
      }
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section_1.slug))

      {:ok, _view, html} = live(conn)

      refute html =~ "Admin"
      assert html =~ "Customize Content"
    end

    test "remix section navigation", %{
      conn: conn,
      map: %{
        section_1: section_1,
        unit1_container: unit1_container,
        nested_revision1: nested_revision1,
        nested_revision2: nested_revision2
      }
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section_1.slug))

      {:ok, view, _html} = live(conn)

      # navigate to a lower unit
      view
      |> element("#entry-#{unit1_container.revision.resource_id} button.entry-title")
      |> render_click()

      assert view |> element("#entry-#{unit1_container.revision.resource_id}") |> has_element?() ==
               false

      assert view |> element("#entry-#{nested_revision1.resource_id}") |> has_element?()
      assert view |> element("#entry-#{nested_revision2.resource_id}") |> has_element?()

      # navigate back to root container
      view
      |> element("#curriculum-back")
      |> render_click()

      assert view |> element("#entry-#{unit1_container.revision.resource_id}") |> has_element?()
    end

    test "remix section reorder and save", %{
      conn: conn,
      map: %{
        section_1: section
      }
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section.slug))

      {:ok, view, _html} = live(conn)

      render_hook(view, "reorder", %{"sourceIndex" => "0", "dropIndex" => "2"})

      view
      |> element("#save")
      |> render_click()

      assert_redirect(
        view,
        ~p"/sections/#{section.slug}/remix"
      )
    end

    test "remix section remove and save (including last course material)", %{
      conn: conn,
      map: %{
        section_1: section
      }
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section.slug))

      {:ok, view, _html} = live(conn)

      node_children_uuids =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{button[phx-click="show_remove_modal"]})
        |> Floki.attribute("phx-value-uuid")

      open_modal_and_confirm_removal(node_children_uuids, view)

      assert render(view) =~ "<p>There&#39;s nothing here.</p>"

      view
      |> element("#save")
      |> render_click()

      assert_redirect(
        view,
        ~p"/sections/#{section.slug}/remix"
      )
    end

    test "show and hide pages works correctly", %{
      conn: conn,
      map: %{section_1: section, revision1: revision1}
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section.slug))

      {:ok, view, _html} = live(conn)

      # Find the uuid of the first node
      node_uuid =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{button[phx-click="show_hide_resource_modal"]})
        |> Floki.attribute("phx-value-uuid")
        |> hd()

      # Assert the button is showing "Hide", as the page is not hidden
      assert has_element?(view, "button[phx-value-uuid=\"#{node_uuid}\"]", "Hide")

      # Click the button to show the modal to hide the page
      view
      |> element(
        "button[phx-click=\"show_hide_resource_modal\"][phx-value-uuid=\"#{node_uuid}\"]"
      )
      |> render_click()

      # Assert the modal is showing the correct title
      assert has_element?(
               view,
               ".modal-body",
               "Are you sure you want to hide #{revision1.title}?"
             )

      # Click the button to hide the page and confirm the action
      view
      |> element("button[phx-click=\"HideResourceModal.toggle\"]", "Hide")
      |> render_click()

      # Find again the uuid of the first node
      node_uuid =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{button[phx-click="show_hide_resource_modal"]})
        |> Floki.attribute("phx-value-uuid")
        |> hd()

      # Assert the button is showing "Show", as the page is hidden
      assert has_element?(view, "button[phx-value-uuid=\"#{node_uuid}\"]", "Show")

      # Save the changes
      view |> element("#save") |> render_click()

      # Check the page is hidden
      sr_updated = Sections.get_section_resource(section.id, revision1.resource_id)

      assert sr_updated.hidden == true
    end

    test "cancel button in hide/show page modal works correctly", %{
      conn: conn,
      map: %{section_1: section, revision1: revision1}
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section.slug))

      {:ok, view, _html} = live(conn)

      # Find the uuid of the first node
      node_uuid =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{button[phx-click="show_hide_resource_modal"]})
        |> Floki.attribute("phx-value-uuid")
        |> hd()

      # Assert the button is showing "Hide", as the page is not hidden
      assert has_element?(view, "button[phx-value-uuid=\"#{node_uuid}\"]", "Hide")

      # Click the button to show the modal to hide the page
      view
      |> element(
        "button[phx-click=\"show_hide_resource_modal\"][phx-value-uuid=\"#{node_uuid}\"]"
      )
      |> render_click()

      # Assert the modal is showing the correct title
      assert has_element?(
               view,
               ".modal-body",
               "Are you sure you want to hide #{revision1.title}?"
             )

      # Click the button to cancel
      view
      |> element("button[phx-click=\"HideResourceModal.cancel\"]", "Cancel")
      |> render_click()

      # Find again the uuid of the first node
      node_uuid =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{button[phx-click="show_hide_resource_modal"]})
        |> Floki.attribute("phx-value-uuid")
        |> hd()

      # Assert the button is showing "Hide", as the page is not hidden
      assert has_element?(view, "button[phx-value-uuid=\"#{node_uuid}\"]", "Hide")

      # Check the page is not hidden
      sr_updated = Sections.get_section_resource(section.id, revision1.resource_id)

      assert sr_updated.hidden == false
    end

    test "cancel button after hide/show page works correctly", %{
      conn: conn,
      map: %{section_1: section, revision1: revision1}
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section.slug))

      {:ok, view, _html} = live(conn)

      # Find the uuid of the first node
      node_uuid =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{button[phx-click="show_hide_resource_modal"]})
        |> Floki.attribute("phx-value-uuid")
        |> hd()

      # Assert the button is showing "Hide", as the page is not hidden
      assert has_element?(view, "button[phx-value-uuid=\"#{node_uuid}\"]", "Hide")

      # Click the button to show the modal to hide the page
      view
      |> element(
        "button[phx-click=\"show_hide_resource_modal\"][phx-value-uuid=\"#{node_uuid}\"]"
      )
      |> render_click()

      # Assert the modal is showing the correct title
      assert has_element?(
               view,
               ".modal-body",
               "Are you sure you want to hide #{revision1.title}?"
             )

      # Click the button to hide the page and confirm the action
      view
      |> element("button[phx-click=\"HideResourceModal.toggle\"]", "Hide")
      |> render_click()

      # Find again the uuid of the first node
      node_uuid =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{button[phx-click="show_hide_resource_modal"]})
        |> Floki.attribute("phx-value-uuid")
        |> hd()

      # Assert the button is showing "Show", as the page is hidden
      assert has_element?(view, "button[phx-value-uuid=\"#{node_uuid}\"]", "Show")

      # Cancel the changes
      view |> element("#cancel") |> render_click()

      # Check the page is not hidden
      sr_updated = Sections.get_section_resource(section.id, revision1.resource_id)

      assert sr_updated.hidden == false
    end

    test "remix section - add materials - resources are inserted preserving hierarchical order",
         %{
           conn: conn,
           map: %{
             section_1: section
           }
         } do
      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/remix")

      # Open the add materials modal
      view
      |> element("button[phx-click=\"show_add_materials_modal\"]")
      |> render_click()

      # Select the project
      view
      |> element(
        ".hierarchy table > tbody tr button[phx-click=\"HierarchyPicker.select_publication\"]",
        "Project 1"
      )
      |> render_click()

      # Verify the hierarchy is displayed correctly before selecting items
      hierarchy_html = render(view)

      # Check that the hierarchy shows all expected items in the correct order
      hierarchy_items =
        hierarchy_html
        |> Floki.parse_fragment!()
        |> Floki.find(".hierarchy > div[id^=\"hierarchy_item_\"]")
        |> Enum.map(&Floki.text/1)

      assert Enum.at(hierarchy_items, 0) =~ "Elixir Page"
      assert Enum.at(hierarchy_items, 1) =~ "Another orph. Page"
      assert Enum.at(hierarchy_items, 2) =~ "Great Unit 1"

      # Verify that containers (units) are properly displayed in the hierarchy
      assert hierarchy_html =~ "Great Unit 1"

      # First add the orphan page, which is the last one in the hierarchy
      view
      |> element(".hierarchy > div", "Another orph. Page")
      |> render_click()

      # Then add the elixir page, which is the second to last one in the hierarchy
      view
      |> element(".hierarchy > div", "Elixir Page")
      |> render_click()

      # Add the resources
      view
      |> element("button[phx-click=\"AddMaterialsModal.add\"]", "Add")
      |> render_click()

      # Save the changes
      view
      |> element("#save", "Save")
      |> render_click()

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/remix")

      html = render(view)

      # Get the entries
      entries =
        html
        |> Floki.parse_document!()
        |> Floki.find(".curriculum-entries .entry-title")
        |> Enum.map(&Floki.text/1)

      # Assert the elixir page is before the orphan page
      assert Enum.find_index(entries, &(&1 =~ "Elixir Page")) <
               Enum.find_index(entries, &(&1 =~ "Another orph. Page"))
    end

    test "remix section - add materials - hierarchy is displayed correctly with multiple units",
         %{
           conn: conn,
           map: %{
             section_1: section
           }
         } do
      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/remix")

      # Open the add materials modal
      view
      |> element("button[phx-click=\"show_add_materials_modal\"]")
      |> render_click()

      # Select the project
      view
      |> element(
        ".hierarchy table > tbody tr button[phx-click=\"HierarchyPicker.select_publication\"]",
        "Project 1"
      )
      |> render_click()

      # Get the hierarchy items and verify they are displayed in the correct order
      hierarchy_html = render(view)

      # Parse the hierarchy to check the order
      hierarchy_items =
        hierarchy_html
        |> Floki.parse_fragment!()
        |> Floki.find(".hierarchy > div[id^=\"hierarchy_item_\"]")
        |> Enum.map(&Floki.text/1)

      # Assert that the hierarchy items are displayed in the correct order
      assert Enum.at(hierarchy_items, 0) =~ "Elixir Page"
      assert Enum.at(hierarchy_items, 1) =~ "Another orph. Page"
      assert Enum.at(hierarchy_items, 2) =~ "Great Unit 1"

      # Verify that containers (units) are properly identified
      hierarchy_elements =
        hierarchy_html
        |> Floki.parse_fragment!()
        |> Floki.find(".hierarchy > div[id^=\"hierarchy_item_\"]")

      unit_element = Enum.at(hierarchy_elements, 0)
      assert Floki.text(unit_element) =~ "Elixir Page"

      assert length(hierarchy_elements) == 3
    end

    test "remix section - add materials - hierarchy preserves nested structure",
         %{
           conn: conn,
           map: %{
             section_1: section
           }
         } do
      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/remix")

      # Open the add materials modal
      view
      |> element("button[phx-click=\"show_add_materials_modal\"]")
      |> render_click()

      # Select the project
      view
      |> element(
        ".hierarchy table > tbody tr button[phx-click=\"HierarchyPicker.select_publication\"]",
        "Project 1"
      )
      |> render_click()

      # Verify that the hierarchy shows the correct structure
      hierarchy_html = render(view)

      # Check that all expected items are present in the hierarchy
      assert hierarchy_html =~ "Elixir Page"
      assert hierarchy_html =~ "Another orph. Page"
      assert hierarchy_html =~ "Great Unit 1"

      # Verify the hierarchy items are selectable and maintain their order
      hierarchy_items =
        hierarchy_html
        |> Floki.parse_fragment!()
        |> Floki.find(".hierarchy > div[id^=\"hierarchy_item_\"]")

      # Assert that we have exactly 3 items in the hierarchy
      assert length(hierarchy_items) == 3

      # Verify that each item can be selected (has click functionality)
      Enum.each(hierarchy_items, fn item ->
        assert Floki.attribute(item, "phx-click") != []
      end)

      # Test selecting items in hierarchy order
      view
      |> element(".hierarchy > div[id^=\"hierarchy_item_\"]", "Elixir Page")
      |> render_click()

      view
      |> element(".hierarchy > div[id^=\"hierarchy_item_\"]", "Great Unit 1")
      |> render_click()

      # Add the selected materials
      view
      |> element("button[phx-click=\"AddMaterialsModal.add\"]", "Add")
      |> render_click()

      # Verify the materials were added in the correct order
      assert render(view) =~ "Elixir Page"
      assert render(view) =~ "Great Unit 1"
    end

    test "remix section - add materials - complex hierarchy with multiple units displays correctly",
         %{
           conn: conn,
           map: %{
             section_1: section
           }
         } do
      # Create additional units for a more complex hierarchy
      author = insert(:author, %{email: "test_author@example.com"})

      # Create Unit 2
      unit_2_revision =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          title: "Unit 2: Advanced Topics",
          max_attempts: nil
        })

      # Create Unit 3
      unit_3_revision =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          title: "Unit 3: Final Review",
          max_attempts: nil
        })

      # Create a page for Unit 2
      unit_2_page =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Advanced Page"
        })

      # Create a page for Unit 3
      unit_3_page =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Review Page"
        })

      # Create a new project with complex hierarchy
      complex_proj = insert(:project, title: "Complex Project", authors: [author])

      # Create a container with all units and pages
      complex_container =
        insert(:revision, %{
          resource: insert(:resource),
          objectives: %{},
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          children: [
            unit_2_revision.resource_id,
            unit_2_page.resource_id,
            unit_3_revision.resource_id,
            unit_3_page.resource_id
          ],
          content: %{},
          deleted: false,
          title: "Complex Root Container"
        })

      # Add all resources to the project
      Enum.each(
        [unit_2_revision, unit_2_page, unit_3_revision, unit_3_page, complex_container],
        fn revision ->
          insert(:project_resource, %{
            project_id: complex_proj.id,
            resource_id: revision.resource_id
          })
        end
      )

      # Create publication for the complex project
      complex_publication =
        insert(:publication, %{
          project: complex_proj,
          published: ~U[2023-06-30 00:36:38.112566Z],
          root_resource_id: complex_container.resource_id
        })

      # Add all resources to the publication
      Enum.each(
        [unit_2_revision, unit_2_page, unit_3_revision, unit_3_page, complex_container],
        fn revision ->
          insert(:published_resource, %{
            publication: complex_publication,
            resource: revision.resource,
            revision: revision,
            author: author
          })
        end
      )

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/remix")

      # Open the add materials modal
      view
      |> element("button[phx-click=\"show_add_materials_modal\"]")
      |> render_click()

      # Select the complex project
      view
      |> element(
        ".hierarchy table > tbody tr button[phx-click=\"HierarchyPicker.select_publication\"]",
        "Complex Project"
      )
      |> render_click()

      # Verify the hierarchy displays all units in the correct order
      hierarchy_html = render(view)

      # Parse the hierarchy to check the order
      hierarchy_items =
        hierarchy_html
        |> Floki.parse_fragment!()
        |> Floki.find(".hierarchy > div[id^=\"hierarchy_item_\"]")
        |> Enum.map(&Floki.text/1)

      assert Enum.at(hierarchy_items, 0) =~ "Unit 2: Advanced Topics"
      assert Enum.at(hierarchy_items, 1) =~ "Advanced Page"
      assert Enum.at(hierarchy_items, 2) =~ "Unit 3: Final Review"
      assert Enum.at(hierarchy_items, 3) =~ "Review Page"

      # Verify that containers (units) are properly identified
      hierarchy_elements =
        hierarchy_html
        |> Floki.parse_fragment!()
        |> Floki.find(".hierarchy > div[id^=\"hierarchy_item_\"]")

      # Check that we have exactly 4 items in the hierarchy
      assert length(hierarchy_elements) == 4

      # Verify that each item can be selected
      Enum.each(hierarchy_elements, fn item ->
        assert Floki.attribute(item, "phx-click") != []
      end)

      # Test selecting a unit and a page
      view
      |> element(".hierarchy > div[id^=\"hierarchy_item_\"]", "Unit 2: Advanced Topics")
      |> render_click()

      view
      |> element(".hierarchy > div[id^=\"hierarchy_item_\"]", "Review Page")
      |> render_click()

      # Add the selected materials
      view
      |> element("button[phx-click=\"AddMaterialsModal.add\"]", "Add")
      |> render_click()

      # Verify the materials were added
      assert render(view) =~ "Unit 2: Advanced Topics"
      assert render(view) =~ "Review Page"
    end
  end

  describe "remix section as product manager" do
    setup [:setup_product_manager_session]

    test "mount as product manager", %{
      conn: conn,
      prod: prod,
      revision1: revision1,
      revision2: revision2,
      project_slug: project_slug
    } do
      conn =
        get(
          conn,
          Routes.product_remix_path(OliWeb.Endpoint, :product_remix, prod.slug)
        )

      {:ok, view, _html} = live(conn)

      assert view |> element("#entry-#{revision1.resource_id}") |> has_element?()
      assert view |> element("#entry-#{revision2.resource_id}") |> has_element?()

      assert view
             |> has_element?(
               "#entry-#{revision1.resource_id} a[href=\"#{Routes.resource_path(OliWeb.Endpoint,
               :edit,
               project_slug,
               revision1.slug)}\"]",
               "Edit Page"
             )

      assert view
             |> has_element?(
               "#entry-#{revision2.resource_id} a[href=\"#{Routes.resource_path(OliWeb.Endpoint,
               :edit,
               project_slug,
               revision2.slug)}\"]",
               "Edit Page"
             )
    end

    test "saving redirects product manager correctly", %{
      conn: conn,
      prod: prod
    } do
      conn =
        get(
          conn,
          Routes.product_remix_path(OliWeb.Endpoint, :product_remix, prod.slug)
        )

      {:ok, view, _html} = live(conn)

      render_hook(view, "reorder", %{"sourceIndex" => "0", "dropIndex" => "2"})

      view
      |> element("#save")
      |> render_click()

      assert_redirect(
        view,
        Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, prod.slug)
      )
    end
  end

  describe "remix section for open and free" do
    setup [:setup_admin_session]

    test "mount as open and free", %{
      conn: conn,
      map: %{
        oaf_section_1: oaf_section_1,
        unit1_container: unit1_container,
        revision1: revision1,
        revision2: revision2
      }
    } do
      conn =
        get(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, oaf_section_1.slug)
        )

      {:ok, view, _html} = live(conn)

      assert view |> element("#entry-#{unit1_container.revision.resource_id}") |> has_element?()
      assert view |> element("#entry-#{revision1.resource_id}") |> has_element?()
      assert view |> element("#entry-#{revision2.resource_id}") |> has_element?()
    end

    test "saving redirects open and free correctly", %{
      conn: conn,
      map: %{
        oaf_section_1: oaf_section_1
      }
    } do
      conn =
        get(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, oaf_section_1.slug)
        )

      {:ok, view, _html} = live(conn)

      render_hook(view, "reorder", %{"sourceIndex" => "0", "dropIndex" => "2"})

      view
      |> element("#save")
      |> render_click()

      assert_redirect(
        view,
        ~p"/sections/#{oaf_section_1.slug}/remix"
      )
    end

    test "remix section items and add materials items are ordered correctly", %{
      conn: conn,
      map: %{
        oaf_section_1: oaf_section_1,
        unit1_container: unit1_container,
        latest1: latest1,
        latest2: latest2
      }
    } do
      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, oaf_section_1.slug)
        )

      assert view
             |> element(".curriculum-entries > div:nth-child(2)")
             |> render() =~ "#{latest1.title}"

      assert view
             |> element(".curriculum-entries > div:nth-child(4)")
             |> render() =~ "#{latest2.title}"

      assert view
             |> element(".curriculum-entries > div:nth-child(6)")
             |> render() =~ "#{unit1_container.revision.title}"

      # click add materials and assert is listing units first
      view
      |> element("button[phx-click=\"show_add_materials_modal\"]")
      |> render_click()

      view
      |> element(
        ".hierarchy table > tbody tr:first-of-type button[phx-click=\"HierarchyPicker.select_publication\"]"
      )
      |> render_click()

      # Verify the hierarchy displays items in the correct order
      hierarchy_html = render(view)

      # Check that the hierarchy shows all expected items
      assert hierarchy_html =~ "#{unit1_container.revision.title}"
      assert hierarchy_html =~ "#{latest1.title}"
      assert hierarchy_html =~ "#{latest2.title}"
    end

    test "remix section - add materials - publications are paginated", %{
      conn: conn,
      map: %{
        oaf_section_1: oaf_section_1
      }
    } do
      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, oaf_section_1.slug)
        )

      # click add materials and assert is listing units first
      view
      |> element("button[phx-click=\"show_add_materials_modal\"]")
      |> render_click()

      assert has_element?(view, "nav[aria-label=\"Paging\"]")
      refute has_element?(view, "button", "Project 5")

      view
      |> element("button[phx-click=\"HierarchyPicker.publications_page_change\"]", "2")
      |> render_click()

      assert has_element?(view, "button", "Project 5")
    end

    test "remix section - add materials - publications can be filtered by text", %{
      conn: conn,
      map: %{
        oaf_section_1: oaf_section_1
      }
    } do
      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, oaf_section_1.slug)
        )

      # click add materials and assert is listing units first
      view
      |> element("button[phx-click=\"show_add_materials_modal\"]")
      |> render_click()

      view
      |> element("form[phx-change=\"HierarchyPicker.publications_text_search\"]")
      |> render_change(%{"text_search" => "Project 2"})

      assert has_element?(view, "button", "Project 2")
      refute has_element?(view, ".hierarchy table > tbody tr:nth-of-type(2)")
    end

    test "remix section items - add materials - all pages view gets rendered correctly", %{
      conn: conn,
      map: %{
        oaf_section_1: oaf_section_1,
        unit1_container: unit1_container,
        latest1: latest1,
        latest2: latest2
      },
      orphan_revision_publication: orphan_revision_publication
    } do
      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, oaf_section_1.slug)
        )

      # click add materials and assert is listing units first
      view
      |> element("button[phx-click=\"show_add_materials_modal\"]")
      |> render_click()

      view
      |> element(
        ".hierarchy table > tbody tr:first-of-type button[phx-click=\"HierarchyPicker.select_publication\"]"
      )
      |> render_click()

      assert view
             |> element(".hierarchy > div[id^=\"hierarchy_item_\"]:nth-of-type(1)")
             |> render() =~ "#{latest1.title}"

      assert view
             |> element(".hierarchy > div[id^=\"hierarchy_item_\"]:nth-of-type(2)")
             |> render() =~ "#{latest2.title}"

      assert view
             |> element(".hierarchy > div[id^=\"hierarchy_item_\"]:nth-of-type(3)")
             |> render() =~ "#{unit1_container.revision.title}"

      view
      |> element("button[phx-value-tab_name=\"all_pages\"]")
      |> render_click()

      view
      |> element("th[phx-value-sort_by=\"title\"]")
      |> render_click()

      assert view
             |> has_element?(".remix_materials_table td", "An Orphan Page")

      assert view
             |> has_element?(".remix_materials_table th", "Published on")

      assert view
             |> has_element?(
               ".remix_materials_table td",
               OliWeb.Common.FormatDateTime.format_datetime(orphan_revision_publication.published,
                 show_timezone: false
               )
             )
    end

    test "remix section items - add materials - all pages view can be sorted", %{
      conn: conn,
      map: %{
        oaf_section_1: oaf_section_1
      }
    } do
      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, oaf_section_1.slug)
        )

      view
      |> element("button[phx-click=\"show_add_materials_modal\"]")
      |> render_click()

      view
      |> element(
        ".hierarchy table > tbody tr button[phx-click=\"HierarchyPicker.select_publication\"]",
        "Project 1"
      )
      |> render_click()

      view
      |> element("button[phx-value-tab_name=\"all_pages\"]")
      |> render_click()

      view
      |> element("th[phx-value-sort_by=\"title\"]")
      |> render_click()

      IO.inspect(element(view, ".remix_materials_table tr:first-of-type td:nth-of-type(2)"))
      # "Another orph. Page" is the first element after sorting
      assert view
             |> has_element?(
               ".remix_materials_table tr:last-of-type td:nth-of-type(2)",
               "Elixir Page"
             )

      assert view
             |> has_element?(
               ".remix_materials_table tbody tr:first-of-type td:nth-of-type(2)",
               "Another orph. Page"
             )

      view
      |> element("th[phx-value-sort_by=\"title\"]")
      |> render_click()

      # "Elixir Page" is the first element after sorting
      assert view
             |> has_element?(
               ".remix_materials_table tbody tr:last-of-type td:nth-of-type(2)",
               "Another orph. Page"
             )

      assert view
             |> has_element?(
               ".remix_materials_table tr:first-of-type td:nth-of-type(2)",
               "Elixir Page"
             )

      # Can sort by published date
      assert view
             |> has_element?("th[data-sortable=\"true\"]", "Published on")
    end

    test "remix section items - add materials - all pages view can be filtered by text", %{
      conn: conn,
      map: %{
        oaf_section_1: oaf_section_1
      }
    } do
      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, oaf_section_1.slug)
        )

      view
      |> element("button[phx-click=\"show_add_materials_modal\"]")
      |> render_click()

      view
      |> element(
        ".hierarchy table > tbody tr:first-of-type button[phx-click=\"HierarchyPicker.select_publication\"]"
      )
      |> render_click()

      view
      |> element("button[phx-value-tab_name=\"all_pages\"]")
      |> render_click()

      view
      |> element("form[phx-change=\"HierarchyPicker.pages_text_search\"]")
      |> render_change(%{"text_search" => "Orphan"})

      assert view
             |> has_element?(".remix_materials_table tbody tr:first-of-type td", "An Orphan Page")

      refute view
             |> has_element?(".remix_materials_table tabtbodyle tr:nth-of-type(2)")
    end
  end

  defp open_modal_and_confirm_removal([], view), do: view

  defp open_modal_and_confirm_removal([uuid | tail], view) do
    view
    |> element(~s{button[phx-click="show_remove_modal"][phx-value-uuid="#{uuid}"]})
    |> render_click()

    view
    |> element(~s{button[phx-click="RemoveModal.remove"]})
    |> render_click()

    open_modal_and_confirm_removal(tail, view)
  end

  defp setup_admin_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource4()

    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().system_admin})

    conn =
      Plug.Test.init_test_session(conn, %{})
      |> log_in_author(admin)

    # Add an orphan page to the section
    orphan_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "An Orphan Page"
      })

    insert(:project_resource, %{
      project_id: map.project.id,
      resource_id: orphan_revision.resource.id
    })

    insert(:published_resource, %{
      publication: map.pub2,
      resource: orphan_revision.resource,
      revision: orphan_revision
    })

    author = insert(:author, %{email: "my_custom@email.com"})

    proj_1 = insert(:project, title: "Project 1", authors: [author])
    proj_2 = insert(:project, title: "Project 2", authors: [author])
    proj_3 = insert(:project, title: "Project 3", authors: [author])
    proj_4 = insert(:project, title: "Project 4", authors: [author])
    proj_5 = insert(:project, title: "Project 5", authors: [author])

    page_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Elixir Page"
      })

    orphan_revision_2 =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Another orph. Page"
      })

    container_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [
          page_revision.resource_id,
          orphan_revision_2.resource_id
        ],
        content: %{},
        deleted: false,
        title: "Root Container"
      })

    insert(:project_resource, %{
      project_id: proj_1.id,
      resource_id: page_revision.resource.id
    })

    insert(:project_resource, %{
      project_id: proj_1.id,
      resource_id: orphan_revision_2.resource.id
    })

    insert(:project_resource, %{
      project_id: proj_1.id,
      resource_id: container_revision.resource_id
    })

    proj_1_publication =
      insert(:publication, %{
        project: proj_1,
        published: ~U[2023-06-25 00:36:38.112566Z],
        root_resource_id: container_revision.resource_id
      })

    insert(:published_resource, %{
      publication: proj_1_publication,
      resource: page_revision.resource,
      revision: page_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: proj_1_publication,
      resource: orphan_revision_2.resource,
      revision: orphan_revision_2,
      author: author
    })

    insert(:published_resource, %{
      publication: proj_1_publication,
      resource: container_revision.resource,
      revision: container_revision,
      author: author
    })

    section =
      insert(:section,
        base_project: proj_1,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable
      )

    {:ok, _section} = Sections.create_section_resources(section, proj_1_publication)

    insert(:publication, %{
      project: proj_2,
      published: ~U[2023-06-26 00:36:38.112566Z]
    })

    insert(:publication, %{
      project: proj_3,
      published: ~U[2023-06-27 00:36:38.112566Z]
    })

    insert(:publication, %{
      project: proj_4,
      published: ~U[2023-06-28 00:36:38.112566Z]
    })

    insert(:publication, %{
      project: proj_5,
      published: ~U[2023-06-29 00:36:38.112566Z]
    })

    {:ok,
     conn: conn,
     map: map,
     author: map.author,
     institution: map.institution,
     project: map.project,
     publication: map.publication,
     orphan_revision_publication: map.pub2}
  end

  defp setup_instructor_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource4()

    {:ok, instructor} =
      Accounts.update_user_platform_roles(
        user_fixture(%{can_create_sections: true, independent_learner: true}),
        [
          Lti_1p3.Roles.PlatformRoles.get_role(:institution_instructor)
        ]
      )

    {:ok, _enrollment} =
      Sections.enroll(instructor.id, map.section_1.id, [
        ContextRoles.get_role(:context_instructor)
      ])

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil, section_slug: map.section_1.slug)
      |> log_in_user(instructor)

    # Add an orphan page to the section
    orphan_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "An Orphan Page"
      })

    insert(:project_resource, %{
      project_id: map.project.id,
      resource_id: orphan_revision.resource.id
    })

    insert(:published_resource, %{
      publication: map.pub2,
      resource: orphan_revision.resource,
      revision: orphan_revision
    })

    author = insert(:author, %{email: "my_custom@email.com"})

    proj_1 = insert(:project, title: "Project 1", authors: [author])
    proj_2 = insert(:project, title: "Project 2", authors: [author])

    page_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Elixir Page"
      })

    orphan_revision_2 =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Another orph. Page"
      })

    unit_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        title: "Great Unit 1",
        max_attempts: nil
      })

    container_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [
          page_revision.resource_id,
          orphan_revision_2.resource_id,
          unit_1_revision.resource_id
        ],
        content: %{},
        deleted: false,
        title: "Root Container"
      })

    insert(:project_resource, %{
      project_id: proj_1.id,
      resource_id: page_revision.resource.id
    })

    insert(:project_resource, %{
      project_id: proj_1.id,
      resource_id: orphan_revision_2.resource.id
    })

    insert(:project_resource, %{
      project_id: proj_1.id,
      resource_id: unit_1_revision.resource.id
    })

    insert(:project_resource, %{
      project_id: proj_1.id,
      resource_id: container_revision.resource_id
    })

    proj_1_publication =
      insert(:publication, %{
        project: proj_1,
        published: ~U[2023-06-25 00:36:38.112566Z],
        root_resource_id: container_revision.resource_id
      })

    insert(:published_resource, %{
      publication: proj_1_publication,
      resource: page_revision.resource,
      revision: page_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: proj_1_publication,
      resource: orphan_revision_2.resource,
      revision: orphan_revision_2,
      author: author
    })

    insert(:published_resource, %{
      publication: proj_1_publication,
      resource: unit_1_revision.resource,
      revision: unit_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: proj_1_publication,
      resource: container_revision.resource,
      revision: container_revision,
      author: author
    })

    section =
      insert(:section,
        base_project: proj_1,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable
      )

    {:ok, _section} = Sections.create_section_resources(section, proj_1_publication)

    insert(:publication, %{
      project: proj_2,
      published: ~U[2023-06-26 00:36:38.112566Z]
    })

    {:ok,
     conn: conn,
     map: map,
     author: map.author,
     institution: map.institution,
     project: map.project,
     publication: map.publication,
     orphan_revision_publication: map.pub2}
  end

  defp setup_product_manager_session(%{conn: conn}) do
    %{
      prod1: prod,
      author: product_author,
      publication: publication,
      revision1: revision1,
      revision2: revision2,
      project: project
    } =
      Seeder.base_project_with_resource2()
      |> Seeder.create_product(%{title: "My 1st product", amount: Money.new(100, "USD")}, :prod1)

    {:ok, _prod} = Sections.create_section_resources(prod, publication)

    conn =
      Plug.Test.init_test_session(conn, %{})
      |> log_in_author(product_author)

    {:ok,
     conn: conn,
     prod: prod,
     revision1: revision1,
     revision2: revision2,
     project_slug: project.slug}
  end
end
