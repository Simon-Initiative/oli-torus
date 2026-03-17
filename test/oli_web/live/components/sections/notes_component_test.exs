defmodule OliWeb.Live.Components.Sections.NotesComponentTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LiveComponentTests
  import Oli.Factory

  alias Oli.Resources.Collaboration
  alias OliWeb.Live.Components.Sections.NotesComponent

  describe "NotesComponent" do
    setup do
      admin = insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().content_admin)
      project = insert(:project, authors: [admin])

      # Create page revisions
      page_1 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Page One",
          graded: false
        )

      page_2 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Page Two",
          graded: false
        )

      # Associate pages to the project
      insert(:project_resource, %{project_id: project.id, resource_id: page_1.resource.id})
      insert(:project_resource, %{project_id: project.id, resource_id: page_2.resource.id})

      # Root container
      container_resource = insert(:resource)
      insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

      container_revision =
        insert(:revision, %{
          resource: container_resource,
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          children: [page_1.resource.id, page_2.resource.id],
          content: %{},
          title: "Root Container"
        })

      # Publication
      publication =
        insert(:publication, %{project: project, root_resource_id: container_resource.id})

      insert(:published_resource, %{
        publication: publication,
        resource: container_resource,
        revision: container_revision,
        author: admin
      })

      insert(:published_resource, %{
        publication: publication,
        resource: page_1.resource,
        revision: page_1,
        author: admin
      })

      insert(:published_resource, %{
        publication: publication,
        resource: page_2.resource,
        revision: page_2,
        author: admin
      })

      # Create blueprint with section_resources
      product = insert(:section, base_project: project, type: :blueprint)
      {:ok, product} = Oli.Delivery.Sections.create_section_resources(product, publication)

      %{product: product, pages_count: 2}
    end

    test "renders with notes OFF (0 pages)", %{conn: conn, product: product, pages_count: pages_count} do
      {:ok, view, _html} =
        live_component_isolated(conn, NotesComponent, %{
          id: "notes-test",
          section: product,
          collab_space_pages_count: 0,
          pages_count: pages_count
        })

      # Toggle should be OFF
      refute has_element?(view, "#notes-test-toggle-notes_checkbox[checked]")

      # Should show "0 pages currently have Notes enabled."
      assert render(view) =~ "0"
      assert render(view) =~ "pages currently have"
      assert render(view) =~ "Notes enabled."
    end

    test "renders with notes ON showing count", %{conn: conn, product: product, pages_count: pages_count} do
      {:ok, view, _html} =
        live_component_isolated(conn, NotesComponent, %{
          id: "notes-test",
          section: product,
          collab_space_pages_count: 1,
          pages_count: pages_count
        })

      # Toggle should be ON (count > 0)
      assert has_element?(view, "#notes-test-toggle-notes_checkbox[checked]")

      # Should show "1 page currently has Notes enabled."
      html = render(view)
      assert html =~ "1"
      assert html =~ "page currently has"
    end

    test "renders 'All X' when all pages have notes", %{conn: conn, product: product, pages_count: pages_count} do
      {:ok, view, _html} =
        live_component_isolated(conn, NotesComponent, %{
          id: "notes-test",
          section: product,
          collab_space_pages_count: pages_count,
          pages_count: pages_count
        })

      assert has_element?(view, "#notes-test-toggle-notes_checkbox[checked]")

      html = render(view)
      assert html =~ "All #{pages_count}"
    end

    test "toggle ON enables notes for all pages", %{conn: conn, product: product, pages_count: pages_count} do
      {:ok, view, _html} =
        live_component_isolated(conn, NotesComponent, %{
          id: "notes-test",
          section: product,
          collab_space_pages_count: 0,
          pages_count: pages_count
        })

      # Toggle ON
      view |> form("#notes-test-toggle-notes", %{}) |> render_change()

      # Should now be checked
      assert has_element?(view, "#notes-test-toggle-notes_checkbox[checked]")

      # Verify database — pages should now have collab spaces enabled
      {enabled_count, _total} =
        Collaboration.count_collab_spaces_enabled_in_pages_for_section(product.slug)

      assert enabled_count == pages_count
    end

    test "toggle OFF disables notes for all pages", %{conn: conn, product: product, pages_count: pages_count} do
      # First enable notes for all pages
      Collaboration.enable_all_page_collab_spaces_for_section(
        product.slug,
        %Oli.Resources.Collaboration.CollabSpaceConfig{status: :enabled}
      )

      {:ok, view, _html} =
        live_component_isolated(conn, NotesComponent, %{
          id: "notes-test",
          section: product,
          collab_space_pages_count: pages_count,
          pages_count: pages_count
        })

      # Should be ON
      assert has_element?(view, "#notes-test-toggle-notes_checkbox[checked]")

      # Toggle OFF
      view |> form("#notes-test-toggle-notes", %{}) |> render_change()

      # Should now be unchecked
      refute has_element?(view, "#notes-test-toggle-notes_checkbox[checked]")

      # Verify database
      {enabled_count, _total} =
        Collaboration.count_collab_spaces_enabled_in_pages_for_section(product.slug)

      assert enabled_count == 0
    end

    test "sends :notes_count_updated to parent on toggle ON", %{conn: conn, product: product, pages_count: pages_count} do
      {:ok, view, _html} =
        live_component_isolated(conn, NotesComponent, %{
          id: "notes-test",
          section: product,
          collab_space_pages_count: 0,
          pages_count: pages_count
        })

      test_pid = self()

      live_component_intercept(view, fn
        {:notes_count_updated, count}, socket ->
          send(test_pid, {:notes_count, count})
          {:halt, socket}

        {:flash, _level, _msg}, socket ->
          {:halt, socket}

        _other, socket ->
          {:cont, socket}
      end)

      view |> form("#notes-test-toggle-notes", %{}) |> render_change()

      assert_received {:notes_count, count}
      assert count == pages_count
    end

    test "sends :notes_count_updated with 0 on toggle OFF", %{conn: conn, product: product, pages_count: pages_count} do
      # Enable notes first
      Collaboration.enable_all_page_collab_spaces_for_section(
        product.slug,
        %Oli.Resources.Collaboration.CollabSpaceConfig{status: :enabled}
      )

      {:ok, view, _html} =
        live_component_isolated(conn, NotesComponent, %{
          id: "notes-test",
          section: product,
          collab_space_pages_count: pages_count,
          pages_count: pages_count
        })

      test_pid = self()

      live_component_intercept(view, fn
        {:notes_count_updated, count}, socket ->
          send(test_pid, {:notes_count, count})
          {:halt, socket}

        {:flash, _level, _msg}, socket ->
          {:halt, socket}

        _other, socket ->
          {:cont, socket}
      end)

      view |> form("#notes-test-toggle-notes", %{}) |> render_change()

      assert_received {:notes_count, 0}
    end
  end
end
