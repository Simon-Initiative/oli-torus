defmodule Oli.Delivery.Remix.OpsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Remix
  alias Oli.Delivery.Sections
  alias Oli.Publishing

  setup do
    author = insert(:author)
    project = insert(:project, authors: [author])

    page1 =
      insert(:revision, %{resource_type_id: Oli.Resources.ResourceType.id_for_page(), title: "P1"})

    page2 =
      insert(:revision, %{resource_type_id: Oli.Resources.ResourceType.id_for_page(), title: "P2"})

    root =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        title: "Root",
        children: [page1.resource_id, page2.resource_id]
      })

    pub = insert(:publication, %{project: project, root_resource_id: root.resource_id})

    Enum.each([root, page1, page2], fn r ->
      insert(:published_resource, %{
        publication: pub,
        resource: r.resource,
        revision: r,
        author: author
      })
    end)

    section = insert(:section, base_project: project, title: "S1")
    {:ok, _} = Sections.create_section_resources(section, pub)

    {:ok,
     state:
       (fn ->
          {:ok, s} = Remix.init(section, author)
          s
        end).()}
  end

  test "reorder preserves multiset and updates order", %{state: state} do
    children_before = Enum.map(state.active.children, & &1.revision.resource_id)
    assert length(children_before) == 2

    {:ok, state} = Remix.reorder(state, 0, 2)
    children_after = Enum.map(state.active.children, & &1.revision.resource_id)
    assert Enum.sort(children_before) == Enum.sort(children_after)
    assert hd(children_after) != hd(children_before)
    assert state.has_unsaved_changes
  end

  test "remove deletes node by uuid", %{state: state} do
    target_uuid = hd(state.active.children).uuid
    {:ok, state} = Remix.remove(state, target_uuid)
    assert length(state.active.children) == 1
    refute Enum.any?(state.active.children, &(&1.uuid == target_uuid))
  end

  test "toggle_hidden flips hidden flag in section_resource", %{state: state} do
    target_uuid = hd(state.active.children).uuid
    sr_before = find_sr(state.hierarchy, target_uuid)
    hidden_before = sr_before && sr_before.hidden

    {:ok, state} = Remix.toggle_hidden(state, target_uuid)
    sr_after = find_sr(state.hierarchy, target_uuid)
    assert sr_before && sr_after && sr_after.hidden != hidden_before
  end

  test "add_materials appends from other publication", %{state: state} do
    # create another project/pub with one page
    author = insert(:author)
    proj = insert(:project, authors: [author])

    page =
      insert(:revision, %{resource_type_id: Oli.Resources.ResourceType.id_for_page(), title: "NP"})

    root =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        title: "R2",
        children: [page.resource_id]
      })

    pub = insert(:publication, %{project: proj, root_resource_id: root.resource_id})

    Enum.each([root, page], fn r ->
      insert(:published_resource, %{
        publication: pub,
        resource: r.resource,
        revision: r,
        author: author
      })
    end)

    pr_by_pub = Publishing.get_published_resources_for_publications([pub.id])
    sel = [{pub.id, page.resource_id}]

    before_len = length(state.active.children)
    {:ok, state} = Remix.add_materials(state, sel, pr_by_pub)
    assert length(state.active.children) == before_len + 1
    assert Enum.any?(state.active.children, &(&1.revision.title == "NP"))
  end

  defp find_sr(h, uuid) do
    if h.uuid == uuid do
      h.section_resource
    else
      h.children |> Enum.map(&find_sr(&1, uuid)) |> Enum.find(& &1)
    end
  end
end
