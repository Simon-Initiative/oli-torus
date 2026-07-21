defmodule Oli.Delivery.Remix.SourceResolutionTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Remix
  alias Oli.Delivery.Remix.Source
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResource

  setup do
    author = insert(:author)
    project = insert(:project, authors: [author])

    visible_page =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Visible product page"
      })

    hidden_page =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Hidden product page"
      })

    descendant_of_hidden_container =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Descendant product page"
      })

    hidden_container =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        title: "Hidden product container",
        children: [descendant_of_hidden_container.resource_id]
      })

    root =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        title: "Product root",
        children: [
          visible_page.resource_id,
          hidden_page.resource_id,
          hidden_container.resource_id
        ]
      })

    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: root.resource_id,
        published: ~U[2023-06-26 00:00:00Z]
      })

    Enum.each(
      [root, visible_page, hidden_page, hidden_container, descendant_of_hidden_container],
      fn revision ->
        insert(:published_resource, %{
          publication: publication,
          resource: revision.resource,
          revision: revision,
          author: author
        })

        insert(:project_resource, %{project_id: project.id, resource_id: revision.resource_id})
      end
    )

    product = insert(:section, %{base_project: project, title: "Curated product"})
    {:ok, product} = Sections.create_section_resources(product, publication)

    hidden_page_section_resource =
      product.id
      |> Sections.get_section_resources()
      |> Enum.find(&(&1.resource_id == hidden_page.resource_id))

    {:ok, _} = Sections.update_section_resource(hidden_page_section_resource, %{hidden: true})

    hidden_container_section_resource =
      product.id
      |> Sections.get_section_resources()
      |> Enum.find(&(&1.resource_id == hidden_container.resource_id))

    {:ok, _} =
      Sections.update_section_resource(hidden_container_section_resource, %{hidden: true})

    target = insert(:section, base_project: project)
    {:ok, _} = Sections.create_section_resources(target, publication)
    {:ok, state} = Remix.init(target, author)

    source = Source.product(product, %{project.id => publication})
    state = %{state | available_sources: [source]}

    %{
      author: author,
      state: state,
      source: source,
      product: product,
      project: project,
      publication: publication,
      visible_page: visible_page,
      hidden_page: hidden_page,
      descendant_of_hidden_container: descendant_of_hidden_container
    }
  end

  test "loads a product's curated hierarchy without hidden resources", %{
    state: state,
    source: source,
    visible_page: visible_page,
    hidden_page: hidden_page,
    descendant_of_hidden_container: descendant_of_hidden_container
  } do
    assert {:ok, ^source, hierarchy} = Remix.source_hierarchy(source.key, state)

    resource_ids = hierarchy |> Hierarchy.flatten_hierarchy() |> Enum.map(& &1.resource_id)
    assert visible_page.resource_id in resource_ids
    refute hidden_page.resource_id in resource_ids
    refute descendant_of_hidden_container.resource_id in resource_ids
  end

  test "lists only visible product pages with search and target exclusions", %{
    state: state,
    source: source,
    visible_page: visible_page,
    hidden_page: hidden_page,
    descendant_of_hidden_container: descendant_of_hidden_container
  } do
    assert {:ok, {1, [%{resource_id: resource_id, project_id: project_id}]}} =
             Remix.source_pages(source.key, state, %{text_search: "visible", limit: 5, offset: 0})

    assert resource_id == visible_page.resource_id
    assert project_id == source.pinned_publications |> Map.keys() |> hd()

    assert {:ok, {0, []}} =
             Remix.source_pages(source.key, state, %{
               exclude_resource_ids: [visible_page.resource_id],
               limit: 5,
               offset: 0
             })

    assert {:ok, {0, []}} =
             Remix.source_pages(source.key, state, %{text_search: "hidden", limit: 5, offset: 0})

    assert {:ok, {0, []}} =
             Remix.source_pages(source.key, state, %{
               text_search: "descendant",
               limit: 5,
               offset: 0
             })

    assert {:ok, {1, [_]}} =
             Remix.source_pages(source.key, state, %{limit: -1, offset: -1})

    assert {:ok, {1, [_]}} = Remix.source_pages(source.key, state, %{})

    assert {:ok, {1, []}} =
             Remix.source_pages(source.key, state, %{limit: 5, offset: 1_000_000})

    assert hidden_page.resource_id != visible_page.resource_id
    assert descendant_of_hidden_container.resource_id != visible_page.resource_id
  end

  test "sorts product pages by pinned publication date", %{
    author: author,
    state: state,
    source: source,
    product: product,
    publication: publication,
    visible_page: visible_page
  } do
    older_project = insert(:project, authors: [author])

    older_page =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Older publication page"
      })

    older_root =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        title: "Older publication root",
        children: [older_page.resource_id]
      })

    older_publication =
      insert(:publication, %{
        project: older_project,
        root_resource_id: older_root.resource_id,
        published: ~U[2023-06-25 00:00:00Z]
      })

    Enum.each([older_root, older_page], fn revision ->
      insert(:project_resource, %{project_id: older_project.id, resource_id: revision.resource_id})

      insert(:published_resource, %{
        publication: older_publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    insert(:section_project_publication, %{
      section: product,
      project: older_project,
      publication: older_publication
    })

    older_page_section_resource =
      insert(:section_resource, %{
        section: product,
        project: older_project,
        resource: older_page.resource,
        resource_id: older_page.resource_id,
        resource_type_id: older_page.resource_type_id,
        revision_id: older_page.id,
        revision_slug: older_page.slug,
        project_slug: older_project.slug,
        title: older_page.title,
        graded: older_page.graded,
        hidden: false,
        numbering_index: 2,
        numbering_level: 1,
        children: []
      })

    root_section_resource = Oli.Repo.get!(SectionResource, product.root_section_resource_id)

    {:ok, _root_section_resource} =
      Sections.update_section_resource(root_section_resource, %{
        children: root_section_resource.children ++ [older_page_section_resource.id]
      })

    source =
      Source.product(
        product,
        Map.put(source.pinned_publications, older_project.id, older_publication)
      )

    state = %{state | available_sources: [source]}

    assert {:ok, {2, asc_pages}} =
             Remix.source_pages(source.key, state, %{
               sort_by: :publication_date,
               sort_order: :asc,
               limit: 10,
               offset: 0
             })

    assert Enum.map(asc_pages, & &1.resource_id) == [
             older_page.resource_id,
             visible_page.resource_id
           ]

    assert Enum.map(asc_pages, & &1.publication_date) == [
             older_publication.published,
             publication.published
           ]

    assert {:ok, {2, desc_pages}} =
             Remix.source_pages(source.key, state, %{
               sort_by: :publication_date,
               sort_order: :desc,
               limit: 10,
               offset: 0
             })

    assert Enum.map(desc_pages, & &1.resource_id) == [
             visible_page.resource_id,
             older_page.resource_id
           ]
  end

  test "resolves a product item through its pinned publication", %{
    source: source,
    publication: publication,
    visible_page: visible_page,
    hidden_page: hidden_page,
    descendant_of_hidden_container: descendant_of_hidden_container
  } do
    assert {:ok, {publication_id, resource_id}} =
             Remix.selection_tuple(source, %{
               project_id: publication.project_id,
               resource_id: visible_page.resource_id
             })

    assert publication_id == publication.id
    assert resource_id == visible_page.resource_id

    assert {:ok, [{^publication_id, ^resource_id}]} =
             Remix.selection_tuples(source, [
               %{project_id: publication.project_id, resource_id: visible_page.resource_id}
             ])

    assert {:error, :unavailable_publication} =
             Remix.selection_tuple(source, %{
               project_id: -1,
               resource_id: visible_page.resource_id
             })

    assert {:error, :unavailable_publication} =
             Remix.selection_tuple(source, %{
               project_id: publication.project_id,
               resource_id: hidden_page.resource_id
             })

    assert {:error, :unavailable_publication} =
             Remix.selection_tuple(source, %{
               project_id: publication.project_id,
               resource_id: descendant_of_hidden_container.resource_id
             })

    assert {:error, :unavailable_publication} =
             Remix.selection_tuple(source, %{project_id: publication.project_id, resource_id: -1})
  end

  test "fails closed for unavailable source keys", %{state: state} do
    assert {:error, :unavailable_source} = Remix.source_hierarchy("product:missing", state)
    assert {:error, :unavailable_source} = Remix.source_pages("product:missing", state, %{})
  end
end
