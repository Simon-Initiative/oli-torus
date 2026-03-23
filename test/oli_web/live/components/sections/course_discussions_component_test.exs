defmodule OliWeb.Live.Components.Sections.CourseDiscussionsComponentTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LiveComponentTests
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResource
  alias OliWeb.Live.Components.Sections.CourseDiscussionsComponent

  describe "CourseDiscussionsComponent" do
    setup do
      admin = insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().content_admin)
      project = insert(:project, authors: [admin])

      # Root container
      container_resource = insert(:resource)
      insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

      container_revision =
        insert(:revision, %{
          resource: container_resource,
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          children: [],
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

      # Create blueprint with section_resources
      product =
        insert(:section,
          base_project: project,
          type: :blueprint,
          contains_discussions: false
        )

      {:ok, product} = Sections.create_section_resources(product, publication)

      root_sr = Oli.Repo.get!(SectionResource, product.root_section_resource_id)

      %{product: product, root_sr: root_sr}
    end

    test "renders with discussions OFF", %{conn: conn, product: product, root_sr: root_sr} do
      {:ok, view, _html} =
        live_component_isolated(conn, CourseDiscussionsComponent, %{
          id: "disc-test",
          section: product,
          collab_space_config: nil,
          root_section_resource: root_sr
        })

      # Toggle should be OFF
      refute has_element?(view, "#disc-test-toggle-discussions_checkbox[checked]")

      # Checkboxes should be disabled
      assert has_element?(view, "input[phx-click='toggle_auto_accept'][disabled]")
      assert has_element?(view, "input[phx-click='toggle_anonymous_posting'][disabled]")
    end

    test "renders with discussions ON", %{conn: conn, product: product, root_sr: root_sr} do
      # Enable discussions on the section_resource
      config = %Oli.Resources.Collaboration.CollabSpaceConfig{
        status: :enabled,
        auto_accept: true,
        anonymous_posting: false
      }

      {:ok, updated_sr} =
        Sections.update_section_resource(root_sr, %{collab_space_config: Map.from_struct(config)})

      {:ok, view, _html} =
        live_component_isolated(conn, CourseDiscussionsComponent, %{
          id: "disc-test",
          section: product,
          collab_space_config: updated_sr.collab_space_config,
          root_section_resource: updated_sr
        })

      # Toggle should be ON
      assert has_element?(view, "#disc-test-toggle-discussions_checkbox[checked]")

      # auto_accept checkbox should be checked, anonymous_posting unchecked
      assert has_element?(view, "input[phx-click='toggle_auto_accept'][checked]")
      refute has_element?(view, "input[phx-click='toggle_anonymous_posting'][checked]")

      # Checkboxes should NOT be disabled
      refute has_element?(view, "input[phx-click='toggle_auto_accept'][disabled]")
      refute has_element?(view, "input[phx-click='toggle_anonymous_posting'][disabled]")
    end

    test "toggle discussions ON persists to database", %{
      conn: conn,
      product: product,
      root_sr: root_sr
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, CourseDiscussionsComponent, %{
          id: "disc-test",
          section: product,
          collab_space_config: nil,
          root_section_resource: root_sr
        })

      # Toggle ON
      view |> form("#disc-test-toggle-discussions", %{}) |> render_change()

      # Toggle should now be ON
      assert has_element?(view, "#disc-test-toggle-discussions_checkbox[checked]")

      # Verify database — section should have contains_discussions = true
      updated_section = Oli.Repo.get!(Oli.Delivery.Sections.Section, product.id)
      assert updated_section.contains_discussions == true

      # Verify section_resource has collab_space_config with status: :enabled
      updated_sr = Oli.Repo.get!(SectionResource, root_sr.id)
      assert updated_sr.collab_space_config.status == :enabled
    end

    test "toggle discussions OFF persists to database", %{
      conn: conn,
      product: product,
      root_sr: root_sr
    } do
      # First enable discussions
      config = %Oli.Resources.Collaboration.CollabSpaceConfig{status: :enabled}

      {:ok, updated_sr} =
        Sections.update_section_resource(root_sr, %{collab_space_config: Map.from_struct(config)})

      {:ok, product} =
        Sections.update_section(product, %{contains_discussions: true})

      {:ok, view, _html} =
        live_component_isolated(conn, CourseDiscussionsComponent, %{
          id: "disc-test",
          section: product,
          collab_space_config: updated_sr.collab_space_config,
          root_section_resource: updated_sr
        })

      assert has_element?(view, "#disc-test-toggle-discussions_checkbox[checked]")

      # Toggle OFF
      view |> form("#disc-test-toggle-discussions", %{}) |> render_change()

      refute has_element?(view, "#disc-test-toggle-discussions_checkbox[checked]")

      # Verify database
      updated_section = Oli.Repo.get!(Oli.Delivery.Sections.Section, product.id)
      assert updated_section.contains_discussions == false

      db_sr = Oli.Repo.get!(SectionResource, root_sr.id)
      assert db_sr.collab_space_config.status == :disabled
    end

    test "toggle auto_accept persists to database", %{
      conn: conn,
      product: product,
      root_sr: root_sr
    } do
      config = %Oli.Resources.Collaboration.CollabSpaceConfig{
        status: :enabled,
        auto_accept: false,
        anonymous_posting: false
      }

      {:ok, updated_sr} =
        Sections.update_section_resource(root_sr, %{collab_space_config: Map.from_struct(config)})

      {:ok, view, _html} =
        live_component_isolated(conn, CourseDiscussionsComponent, %{
          id: "disc-test",
          section: product,
          collab_space_config: updated_sr.collab_space_config,
          root_section_resource: updated_sr
        })

      # Click auto_accept checkbox
      view |> element("input[phx-click='toggle_auto_accept']") |> render_click()

      # Verify database
      db_sr = Oli.Repo.get!(SectionResource, root_sr.id)
      assert db_sr.collab_space_config.auto_accept == true
    end

    test "toggle anonymous_posting persists to database", %{
      conn: conn,
      product: product,
      root_sr: root_sr
    } do
      config = %Oli.Resources.Collaboration.CollabSpaceConfig{
        status: :enabled,
        auto_accept: false,
        anonymous_posting: false
      }

      {:ok, updated_sr} =
        Sections.update_section_resource(root_sr, %{collab_space_config: Map.from_struct(config)})

      {:ok, view, _html} =
        live_component_isolated(conn, CourseDiscussionsComponent, %{
          id: "disc-test",
          section: product,
          collab_space_config: updated_sr.collab_space_config,
          root_section_resource: updated_sr
        })

      # Click anonymous_posting checkbox
      view |> element("input[phx-click='toggle_anonymous_posting']") |> render_click()

      # Verify database
      db_sr = Oli.Repo.get!(SectionResource, root_sr.id)
      assert db_sr.collab_space_config.anonymous_posting == true
    end

    test "error flash when root_section_resource is nil", %{conn: conn, product: product} do
      {:ok, view, _html} =
        live_component_isolated(conn, CourseDiscussionsComponent, %{
          id: "disc-test",
          section: product,
          collab_space_config: nil,
          root_section_resource: nil
        })

      test_pid = self()

      live_component_intercept(view, fn
        {:flash, :error, msg}, socket ->
          send(test_pid, {:flash_error, msg})
          {:halt, socket}

        _other, socket ->
          {:cont, socket}
      end)

      view |> form("#disc-test-toggle-discussions", %{}) |> render_change()

      assert_received {:flash_error, "Cannot configure discussions: no root container found"}
    end

    test "sends :section_updated and :collab_space_config_updated to parent", %{
      conn: conn,
      product: product,
      root_sr: root_sr
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, CourseDiscussionsComponent, %{
          id: "disc-test",
          section: product,
          collab_space_config: nil,
          root_section_resource: root_sr
        })

      test_pid = self()

      live_component_intercept(view, fn
        {:section_updated, %Oli.Delivery.Sections.Section{}}, socket ->
          send(test_pid, :section_updated_received)
          {:halt, socket}

        {:collab_space_config_updated, _config, _sr}, socket ->
          send(test_pid, :config_updated_received)
          {:halt, socket}

        {:flash, _level, _msg}, socket ->
          {:halt, socket}

        _other, socket ->
          {:cont, socket}
      end)

      view |> form("#disc-test-toggle-discussions", %{}) |> render_change()

      assert_received :section_updated_received
      assert_received :config_updated_received
    end
  end
end
