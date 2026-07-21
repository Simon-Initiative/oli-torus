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

    test "treats section-scoped hidden instructors as members of all active communities for enrollable Remix sources" do
      random_hidden_user = insert(:user, %{hidden: true})
      institution = insert(:institution)
      community = insert(:community, %{global_access: false})
      deleted_community = insert(:community, %{global_access: false, status: :deleted})

      author = insert(:author)
      source_project = insert(:project, %{authors: [author], visibility: :selected})
      community_project = insert(:project, %{authors: [author], visibility: :selected})
      deleted_community_project = insert(:project, %{authors: [author], visibility: :selected})

      root =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          title: "Community Product Root"
        })

      source_publication =
        insert(:publication, %{project: source_project, root_resource_id: root.resource_id})

      community_project_publication =
        insert(:publication, %{project: community_project, root_resource_id: root.resource_id})

      deleted_community_project_publication =
        insert(:publication, %{
          project: deleted_community_project,
          root_resource_id: root.resource_id
        })

      insert(:published_resource, %{
        publication: source_publication,
        resource: root.resource,
        revision: root,
        author: author
      })

      insert(:published_resource, %{
        publication: community_project_publication,
        resource: root.resource,
        revision: root,
        author: author
      })

      insert(:published_resource, %{
        publication: deleted_community_project_publication,
        resource: root.resource,
        revision: root,
        author: author
      })

      insert(:community_project_visibility, %{community: community, project: community_project})

      insert(:community_project_visibility, %{
        community: deleted_community,
        project: deleted_community_project
      })

      community_product =
        insert(:section, %{
          base_project: source_project,
          title: "Hidden Instructor Community Template",
          type: :blueprint,
          status: :active
        })

      {:ok, _community_product} =
        Sections.create_section_resources(community_product, source_publication)

      insert(:community_product_visibility, %{community: community, section: community_product})

      unassociated_product =
        insert(:section, %{
          base_project: source_project,
          title: "Unassociated Hidden Instructor Template",
          type: :blueprint,
          status: :active
        })

      {:ok, _unassociated_product} =
        Sections.create_section_resources(unassociated_product, source_publication)

      deleted_community_product =
        insert(:section, %{
          base_project: source_project,
          title: "Deleted Community Hidden Instructor Template",
          type: :blueprint,
          status: :active
        })

      {:ok, _deleted_community_product} =
        Sections.create_section_resources(deleted_community_product, source_publication)

      insert(:community_product_visibility, %{
        community: deleted_community,
        section: deleted_community_product
      })

      target =
        insert(:section, %{
          base_project: source_project,
          institution: institution,
          type: :enrollable
        })

      {:ok, _target} = Sections.create_section_resources(target, source_publication)

      {:ok, random_hidden_state} = Remix.init(target, random_hidden_user)

      refute Enum.any?(random_hidden_state.available_sources, fn source ->
               source.type == :product and source.product_id == community_product.id
             end)

      {:ok, {section_hidden_instructor, _token}} = Sections.fetch_hidden_instructor(target.id)
      {:ok, state} = Remix.init(target, section_hidden_instructor)

      assert Enum.any?(state.available_sources, fn source ->
               source.type == :product and source.product_id == community_product.id and
                 source.title == "Hidden Instructor Community Template"
             end)

      assert Enum.any?(state.available_sources, fn source ->
               source.type == :project and source.project_id == community_project.id and
                 source.publication_id == community_project_publication.id
             end)

      refute Enum.any?(state.available_sources, fn source ->
               source.type == :product and source.product_id == unassociated_product.id
             end)

      refute Enum.any?(state.available_sources, fn source ->
               source.type == :product and source.product_id == deleted_community_product.id
             end)

      refute Enum.any?(state.available_sources, fn source ->
               source.type == :project and source.project_id == deleted_community_project.id
             end)
    end
  end

  describe "init_admin_instructor/2" do
    test "exposes product templates when an admin edits an enrollable section" do
      admin = insert(:author, %{system_role_id: Oli.Accounts.SystemRole.role_id().content_admin})
      source_author = insert(:author)
      source_project = insert(:project, %{authors: [source_author], visibility: :selected})

      root =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          title: "Source Root"
        })

      source_publication =
        insert(:publication, %{project: source_project, root_resource_id: root.resource_id})

      insert(:published_resource, %{
        publication: source_publication,
        resource: root.resource,
        revision: root,
        author: source_author
      })

      product =
        insert(:section, %{
          base_project: source_project,
          title: "Admin Available Template",
          type: :blueprint
        })

      {:ok, _} = Sections.create_section_resources(product, source_publication)

      archived_product =
        insert(:section, %{
          base_project: source_project,
          title: "Archived Admin Hidden Template",
          type: :blueprint,
          status: :archived
        })

      {:ok, _} = Sections.create_section_resources(archived_product, source_publication)

      target = insert(:section, %{base_project: source_project, type: :enrollable})
      {:ok, _} = Sections.create_section_resources(target, source_publication)

      {:ok, state} = Remix.init_admin_instructor(target, admin)

      assert Enum.any?(state.available_sources, fn source ->
               source.type == :product and source.product_id == product.id and
                 source.title == "Admin Available Template"
             end)

      refute Enum.any?(state.available_sources, fn source ->
               source.type == :product and source.title == target.title
             end)

      refute Enum.any?(state.available_sources, fn source ->
               source.type == :product and source.product_id == archived_product.id
             end)
    end

    test "does not add product template sources to the generic author initializer" do
      admin = insert(:author, %{system_role_id: Oli.Accounts.SystemRole.role_id().content_admin})
      source_author = insert(:author)
      source_project = insert(:project, %{authors: [source_author]})

      root =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          title: "Source Root"
        })

      source_publication =
        insert(:publication, %{project: source_project, root_resource_id: root.resource_id})

      insert(:published_resource, %{
        publication: source_publication,
        resource: root.resource,
        revision: root,
        author: source_author
      })

      product =
        insert(:section, %{
          base_project: source_project,
          title: "Generic Init Hidden Template",
          type: :blueprint
        })

      {:ok, _} = Sections.create_section_resources(product, source_publication)

      target = insert(:section, %{base_project: source_project, type: :enrollable})
      {:ok, _} = Sections.create_section_resources(target, source_publication)

      {:ok, state} = Remix.init(target, admin)

      refute Enum.any?(state.available_sources, &(&1.type == :product))
    end

    test "rejects product template sections" do
      admin = insert(:author, %{system_role_id: Oli.Accounts.SystemRole.role_id().content_admin})
      product = insert(:section, %{type: :blueprint})

      assert {:error, :unsupported_section_type} = Remix.init_admin_instructor(product, admin)
    end

    test "rejects non-admin authors" do
      author = insert(:author)
      target = insert(:section, %{type: :enrollable})

      assert {:error, :unauthorized} = Remix.init_admin_instructor(target, author)
    end
  end
end
