defmodule OliWeb.Common.Hierarchy.MoveModalTest do
  use Oli.DataCase, async: true
  import Oli.Factory
  import Phoenix.LiveViewTest

  alias OliWeb.Common.Hierarchy.MoveModal

  @moduledoc false

  # - Renders modal title and action buttons
  # - Disables move when moving to same container; shows remove when page in a container

  test "renders modal title and action buttons with correct state" do
    container = %{uuid: Ecto.UUID.generate()}

    revision =
      insert(:revision, resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"))

    container_id = Oli.Resources.ResourceType.get_id_by_type("container")

    root = %Oli.Delivery.Hierarchy.HierarchyNode{
      uuid: Ecto.UUID.generate(),
      revision: %Oli.Resources.Revision{title: revision.title, resource_type_id: container_id},
      children: []
    }

    active = %Oli.Delivery.Hierarchy.HierarchyNode{
      uuid: Ecto.UUID.generate(),
      revision: %Oli.Resources.Revision{title: revision.title, resource_type_id: container_id},
      children: []
    }

    root = %{root | children: [active]}

    assigns = %{
      id: "move_modal",
      hierarchy: root,
      active: active,
      from_container: container,
      node: %{uuid: Ecto.UUID.generate(), revision: revision}
    }

    html = render_component(&MoveModal.render/1, assigns)
    assert html =~ "Move"
    assert html =~ ~s(phx-click="MoveModal.move_item")
    assert html =~ ~s(phx-click="MoveModal.cancel")
  end

  test "disables move when moving to the same container and shows remove button for pages" do
    page_rev =
      insert(:revision, resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"))

    same_uuid = Ecto.UUID.generate()
    container = %{uuid: same_uuid}

    container_id = Oli.Resources.ResourceType.get_id_by_type("container")

    root = %Oli.Delivery.Hierarchy.HierarchyNode{
      uuid: Ecto.UUID.generate(),
      revision: %Oli.Resources.Revision{title: page_rev.title, resource_type_id: container_id},
      children: []
    }

    active = %Oli.Delivery.Hierarchy.HierarchyNode{
      uuid: same_uuid,
      revision: %Oli.Resources.Revision{title: page_rev.title, resource_type_id: container_id},
      children: []
    }

    root = %{root | children: [active]}

    assigns = %{
      id: "move_modal",
      hierarchy: root,
      active: active,
      from_container: container,
      node: %{uuid: Ecto.UUID.generate(), revision: page_rev}
    }

    html = render_component(&MoveModal.render/1, assigns)
    assert html =~ ~s(disabled)
    assert html =~ ~s(id="remove_btn")
  end
end
