defmodule OliWeb.Delivery.Remix.ActionsTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Delivery.Remix.Actions
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
      assert html =~ "btn btn-danger"
      assert html =~ "phx-click=\"show_remove_modal\""
      refute html =~ "disabled"

      # Should not have warning icon
      refute html =~ "fill-Fill-Accent-fill-accent-orange-bold"
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
      assert html =~ "btn btn-danger"
      assert html =~ "disabled"

      # Should have warning icon with tooltip
      assert html =~ "fill-Fill-Accent-fill-accent-orange-bold"

      assert html =~
               "In order to remove this page, you first need to remove the gating condition associated with it."
    end
  end
end
