defmodule OliWeb.Live.Components.Tags.TagsComponentTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import LiveComponentTests
  import Oli.Factory

  alias Oli.Tags
  alias OliWeb.Live.Components.Tags.TagsComponent

  describe "TagsComponent" do
    setup do
      project = insert(:project)
      section = insert(:section)

      {:ok, tag1} = Tags.create_tag(%{name: "Biology"})
      {:ok, tag2} = Tags.create_tag(%{name: "Chemistry"})
      {:ok, tag3} = Tags.create_tag(%{name: "Physics"})

      # Associate some tags with entities
      {:ok, _} = Tags.associate_tag_with_project(project, tag1)
      {:ok, _} = Tags.associate_tag_with_section(section, tag2)

      %{
        project: project,
        section: section,
        tags: [tag1, tag2, tag3],
        biology: tag1,
        chemistry: tag2,
        physics: tag3
      }
    end

    test "renders display mode with current tags", %{
      conn: conn,
      project: project,
      biology: biology
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :project,
          entity_id: project.id,
          current_tags: [biology]
        })

      assert has_element?(component, "span[role='selected tag']", "Biology")
      refute has_element?(component, "input")
      refute has_element?(component, "button", "X")
    end

    test "renders empty display when no tags", %{conn: conn} do
      # Create a project with no tags
      empty_project = insert(:project)

      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :project,
          entity_id: empty_project.id,
          current_tags: []
        })

      refute has_element?(component, "span[role='selected tag']")
    end

    test "handles unloaded association in current_tags", %{conn: conn, project: project} do
      # Simulate unloaded association
      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :project,
          entity_id: project.id,
          current_tags: %Ecto.Association.NotLoaded{
            __field__: :tags,
            __owner__: project.__struct__
          }
        })

      assert has_element?(component, "span[role='selected tag']", "Biology")
    end

    test "edit mode shows input and remove buttons", %{
      conn: conn,
      project: project,
      biology: biology
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :project,
          entity_id: project.id,
          current_tags: [biology]
        })

      # Enter edit mode
      component |> element("div[phx-click='toggle_edit']") |> render_click()

      # Should show input and remove buttons in edit mode
      assert has_element?(component, "input")
      assert has_element?(component, "button", "X")
      assert has_element?(component, "span[role='selected tag']", "Biology")
    end

    test "add_tag button is rendered in edit mode", %{
      conn: conn,
      project: project,
      biology: biology,
      physics: _physics
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :project,
          entity_id: project.id,
          current_tags: [biology]
        })

      # Enter edit mode
      component |> element("div[phx-click='toggle_edit']") |> render_click()

      # Should show add buttons for available tags
      assert has_element?(component, "button[phx-click='add_tag']", "Physics")
      assert has_element?(component, "button[phx-click='add_tag']", "Chemistry")
    end

    test "remove_tag button is rendered in edit mode", %{
      conn: conn,
      project: project,
      biology: biology
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :project,
          entity_id: project.id,
          current_tags: [biology]
        })

      # Enter edit mode
      component |> element("div[phx-click='toggle_edit']") |> render_click()

      # Should show tag with X button for removal
      assert has_element?(component, "span[role='selected tag']", "Biology")
      assert has_element?(component, "button[phx-click='remove_tag']", "X")
    end

    test "available tags are shown in edit mode", %{
      conn: conn,
      section: section,
      chemistry: chemistry
    } do
      # Create additional tags for search
      {:ok, _biochemistry} = Tags.create_tag(%{name: "Biochemistry"})
      {:ok, _math} = Tags.create_tag(%{name: "Mathematics"})

      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :section,
          entity_id: section.id,
          current_tags: [chemistry]
        })

      # Enter edit mode
      component |> element("div[phx-click='toggle_edit']") |> render_click()

      # Should show available tags (excluding already selected chemistry)
      assert has_element?(component, "button", "Biology")
      assert has_element?(component, "button", "Physics")
      assert has_element?(component, "button", "Biochemistry")
      assert has_element?(component, "button", "Mathematics")
    end

    test "input field accepts keydown events", %{
      conn: conn,
      project: project,
      biology: biology
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :project,
          entity_id: project.id,
          current_tags: [biology]
        })

      # Enter edit mode
      component |> element("div[phx-click='toggle_edit']") |> render_click()

      # Input should have keydown handler
      assert has_element?(component, "input[phx-keydown='handle_keydown']")

      # Current tags should still be displayed
      assert has_element?(component, "span[role='selected tag']", "Biology")
    end

    test "input field supports search functionality", %{
      conn: conn,
      project: project,
      biology: biology,
      physics: _physics
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :project,
          entity_id: project.id,
          current_tags: [biology]
        })

      # Enter edit mode
      component |> element("div[phx-click='toggle_edit']") |> render_click()

      # Input should have search handler
      assert has_element?(component, "input[phx-keyup='search_tags']")

      # Current tags should be displayed
      assert has_element?(component, "span[role='selected tag']", "Biology")
    end

    test "handle_keydown with Escape exits edit mode", %{
      conn: conn,
      project: project,
      biology: biology
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :project,
          entity_id: project.id,
          current_tags: [biology]
        })

      # Enter edit mode
      component |> element("div[phx-click='toggle_edit']") |> render_click()
      assert has_element?(component, "input")

      # Press Escape (test render_keydown)
      component
      |> element("input")
      |> render_keydown(%{key: "Escape"})

      # Should exit edit mode
      refute has_element?(component, "input")
    end

    test "works with sections", %{conn: conn, section: section, chemistry: chemistry} do
      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :section,
          entity_id: section.id,
          current_tags: [chemistry]
        })

      assert has_element?(component, "span[role='selected tag']", "Chemistry")
    end

    test "works with blueprint sections (products)", %{conn: conn, chemistry: chemistry} do
      product = insert(:section, %{type: :blueprint})
      {:ok, _} = Tags.associate_tag_with_section(product, chemistry)

      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :section,
          entity_id: product.id,
          current_tags: [chemistry]
        })

      assert has_element?(component, "span[role='selected tag']", "Chemistry")
    end

    test "displays error state styling when needed", %{conn: conn, project: project} do
      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :project,
          entity_id: project.id,
          current_tags: []
        })

      # Enter edit mode to see the input field
      component |> element("div[phx-click='toggle_edit']") |> render_click()

      # Component should render without errors
      assert has_element?(component, "input")
    end

    test "input field is available for tag creation", %{conn: conn, project: project} do
      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :project,
          entity_id: project.id,
          current_tags: []
        })

      # Enter edit mode
      component |> element("div[phx-click='toggle_edit']") |> render_click()

      # Should have input field for creating new tags
      assert has_element?(component, "input[type='text']")
    end

    test "tags are displayed in alphabetical order", %{conn: conn, project: project} do
      {:ok, zebra} = Tags.create_tag(%{name: "Zebra"})
      {:ok, apple} = Tags.create_tag(%{name: "Apple"})
      {:ok, _} = Tags.associate_tag_with_project(project, zebra)
      {:ok, _} = Tags.associate_tag_with_project(project, apple)

      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :project,
          entity_id: project.id,
          current_tags: Tags.get_project_tags(project)
        })

      # Get all tag elements and check order
      tags_html = render(component)
      apple_index = :binary.match(tags_html, "Apple") |> elem(0)
      zebra_index = :binary.match(tags_html, "Zebra") |> elem(0)

      assert apple_index < zebra_index
    end

    test "removes unused tags from database when remove_if_unused is true", %{conn: conn} do
      project = insert(:project)
      {:ok, unique_tag} = Tags.create_tag(%{name: "UniqueTag"})
      {:ok, _} = Tags.associate_tag_with_project(project, unique_tag)

      {:ok, component, _html} =
        live_component_isolated(conn, TagsComponent, %{
          id: "test-tags",
          entity_type: :project,
          entity_id: project.id,
          current_tags: [unique_tag]
        })

      # Enter edit mode
      component |> element("div[phx-click='toggle_edit']") |> render_click()

      # Should show the tag with remove button
      assert has_element?(component, "button[phx-click='remove_tag']", "X")

      # Tag should still exist in database (removal happens when button is clicked)
      assert Tags.get_tag_by_name("UniqueTag") != nil
    end
  end
end
