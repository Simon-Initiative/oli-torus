defmodule Oli.Delivery.Remix.InitTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Remix
  alias Oli.Delivery.Sections

  describe "init/2" do
    test "initializes state for author" do
      author = insert(:author)
      project = insert(:project, authors: [author])

      root =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          title: "Root",
          children: []
        })

      pub = insert(:publication, %{project: project, root_resource_id: root.resource_id})

      insert(:published_resource, %{
        publication: pub,
        resource: root.resource,
        revision: root,
        author: author
      })

      section = insert(:section, base_project: project, title: "S1")
      {:ok, _} = Sections.create_section_resources(section, pub)

      {:ok, state} = Remix.init(section, author)

      assert state.section.id == section.id
      assert state.hierarchy.uuid == state.active.uuid
      assert is_list(state.available_publications)
    end
  end
end
