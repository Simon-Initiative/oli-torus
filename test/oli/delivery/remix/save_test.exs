defmodule Oli.Delivery.Remix.SaveTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Remix
  alias Oli.Delivery.Sections

  @tag :remix_save
  test "toggle then save persists to section resources" do
    author = insert(:author)
    project = insert(:project, authors: [author])

    page =
      insert(:revision, %{resource_type_id: Oli.Resources.ResourceType.id_for_page(), title: "P"})

    root =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        title: "Root",
        children: [page.resource_id]
      })

    pub = insert(:publication, %{project: project, root_resource_id: root.resource_id})

    Enum.each([root, page], fn r ->
      insert(:published_resource, %{
        publication: pub,
        resource: r.resource,
        revision: r,
        author: author
      })
    end)

    section = insert(:section, base_project: project)
    {:ok, _} = Sections.create_section_resources(section, pub)

    {:ok, state} = Remix.init(section, author)
    target_uuid = hd(state.active.children).uuid
    {:ok, state} = Remix.toggle_hidden(state, target_uuid)

    {:ok, _section} = Remix.save(state)

    # verify persisted
    sr = Sections.get_section_resource(section.id, hd(state.active.children).revision.resource_id)
    assert sr.hidden == true
  end
end
