defmodule OliWeb.Delivery.Remix.ActionsTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Delivery.Remix.Actions
  alias OliWeb.Delivery.Instructor.PreviewRoutes
  alias Oli.Resources.ResourceType
  alias Oli.Seeder

  describe "Actions component" do
    setup do
      map = Seeder.base_project_with_resource4()

      %{
        section: map.section_1,
        page1: map.page1,
        page2: map.page2,
        revision1: map.revision1,
        revision2: map.revision2
      }
    end

    test "renders remove button as enabled when page is not used as source page", %{
      section: section,
      page1: page1
    } do
      assigns = %{
        uuid: "test-uuid",
        resource_type: ResourceType.id_for_page(),
        hidden: false,
        section_id: section.id,
        resource_id: page1.id,
        is_used_as_source_page: false
      }

      html = render_component(Actions, assigns)

      # Button should not be disabled
      assert html =~ "Remove"
      assert html =~ "show_remove_modal"
      refute html =~ "aria-disabled=\"true\""
    end

    test "renders remove button as disabled when page is used as source page", %{
      section: section,
      page1: page1
    } do
      assigns = %{
        uuid: "test-uuid",
        resource_type: ResourceType.id_for_page(),
        hidden: false,
        section_id: section.id,
        resource_id: page1.id,
        is_used_as_source_page: true
      }

      html = render_component(Actions, assigns)

      # Button should be disabled
      assert html =~ "Remove"
      assert html =~ "disabled"

      # Should have warning icon with tooltip
      assert html =~
               "In order to remove this page, you first need to remove the gating condition associated with it."
    end

    test "renders edit link for pages", %{
      section: section,
      revision1: revision1
    } do
      edit_url =
        PreviewRoutes.lesson_path(section.slug, revision1.slug,
          return_to: "/sections/#{section.slug}/remix"
        )

      html =
        render_component(Actions, %{
          uuid: "test-uuid",
          resource_type: ResourceType.id_for_page(),
          hidden: false,
          is_used_as_source_page: false,
          edit_url: edit_url,
          edit_label: "Open #{revision1.title} in Instructor View"
        })

      assert html =~ "Edit"
      assert html =~ ~s(href="#{edit_url}")
      assert html =~ ~s(aria-label="Open #{revision1.title} in Instructor View")
      assert html =~ ~s(data-unsaved-changes-reason="instructor_view")
    end

    test "does not render edit link for containers" do
      html =
        render_component(Actions, %{
          uuid: "test-uuid",
          resource_type: ResourceType.id_for_container(),
          hidden: false,
          is_used_as_source_page: false,
          edit_url: "/sections/test/preview/lesson/page-slug"
        })

      refute html =~ "Edit"
    end
  end
end
