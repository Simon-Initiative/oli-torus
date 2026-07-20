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
      assert is_list(state.available_sources)
      assert [%{type: :project, publication_id: publication_id}] = state.available_sources
      assert publication_id == pub.id
    end

    test "exposes a community product as a source without exposing its base project" do
      user = insert(:user)
      institution = insert(:institution)
      community = insert(:community, %{global_access: false})
      insert(:community_member_account, %{user: user, community: community})

      author = insert(:author)
      project = insert(:project, %{authors: [author], visibility: :selected})
      root = insert(:revision, %{resource_type_id: Oli.Resources.ResourceType.id_for_container()})
      publication = insert(:publication, %{project: project, root_resource_id: root.resource_id})

      insert(:published_resource, %{
        publication: publication,
        resource: root.resource,
        revision: root,
        author: author
      })

      product = insert(:section, %{base_project: project, title: "Approved Template"})
      {:ok, _} = Sections.create_section_resources(product, publication)
      insert(:community_product_visibility, %{community: community, section: product})

      target = insert(:section, %{base_project: project, institution: institution})
      {:ok, _} = Sections.create_section_resources(target, publication)

      {:ok, state} = Remix.init(target, user)

      assert [%{type: :product, title: "Approved Template", product_id: product_id}] =
               state.available_sources

      assert product_id == product.id
      refute Enum.any?(state.available_sources, &(&1.type == :project))
    end
  end
end
