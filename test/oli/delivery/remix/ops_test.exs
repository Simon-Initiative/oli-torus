defmodule Oli.Delivery.Remix.OpsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Remix
  alias Oli.Delivery.Remix.Source
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

      insert(:project_resource, %{project_id: project.id, resource_id: r.resource_id})
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
    %{pub: pub, page: page} = publication_with_page("NP")
    state = make_publication_available(state, pub)

    pr_by_pub = Publishing.get_published_resources_for_publications([pub.id])
    sel = [{pub.id, page.resource_id}]

    before_len = length(state.active.children)
    {:ok, state} = Remix.add_materials(state, sel, pr_by_pub)
    assert length(state.active.children) == before_len + 1
    assert Enum.any?(state.active.children, &(&1.revision.title == "NP"))
  end

  test "add_materials rejects materials from a project sharing resources with base project", %{
    state: state
  } do
    base_page = hd(state.active.children).revision
    %{pub: pub} = publication_with_page("Clone Page", shared_page: base_page)
    state = make_publication_available(state, pub)
    pr_by_pub = Publishing.get_published_resources_for_publications([pub.id])

    assert {:error, :shared_project_resources} =
             Remix.add_materials(state, [{pub.id, base_page.resource_id}], pr_by_pub)
  end

  test "add_materials rejects materials from unavailable publications", %{state: state} do
    %{pub: pub, page: page} = publication_with_page("Unavailable Source")
    pr_by_pub = Publishing.get_published_resources_for_publications([pub.id])

    assert {:error, :unavailable_publication} =
             Remix.add_materials(state, [{pub.id, page.resource_id}], pr_by_pub)

    assert {:error, :unavailable_publication} =
             Remix.add_materials(state, [{pub.id, page.resource_id}])
  end

  test "derives publication lookup from available sources", %{state: state} do
    %{pub: pub} = publication_with_page("Available Source")
    state = make_publication_available(state, pub)

    assert %{id: publication_id, project_id: project_id} = Remix.publication_by_id(state, pub.id)
    assert publication_id == pub.id
    assert project_id == pub.project_id
    assert Remix.publication_by_id(state, -1) == nil
  end

  test "add_materials rejects materials sharing resources with an already remixed project", %{
    state: state
  } do
    %{pub: first_pub, page: first_page} = publication_with_page("First Source")
    state = make_publication_available(state, first_pub)

    assert {:ok, state} = Remix.add_materials(state, [{first_pub.id, first_page.resource_id}])

    %{pub: second_pub} = publication_with_page("Second Source", shared_page: first_page)
    state = make_publication_available(state, second_pub)
    pr_by_pub = Publishing.get_published_resources_for_publications([second_pub.id])

    assert {:error, :shared_project_resources} =
             Remix.add_materials(state, [{second_pub.id, first_page.resource_id}], pr_by_pub)
  end

  test "add_materials allows adding more materials from an already remixed project", %{
    state: state
  } do
    %{pub: pub, page: first_page} = publication_with_page("First Source")

    second_page =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Second Source"
      })

    insert(:published_resource, %{
      publication: pub,
      resource: second_page.resource,
      revision: second_page,
      author: insert(:author)
    })

    insert(:project_resource, %{project_id: pub.project_id, resource_id: second_page.resource_id})

    state = make_publication_available(state, pub)

    assert {:ok, state} = Remix.add_materials(state, [{pub.id, first_page.resource_id}])
    assert {:ok, state} = Remix.add_materials(state, [{pub.id, second_page.resource_id}])

    assert Enum.any?(state.active.children, &(&1.revision.title == "First Source"))
    assert Enum.any?(state.active.children, &(&1.revision.title == "Second Source"))
  end

  test "add_materials rejects a batch containing projects that share resources", %{state: state} do
    %{pub: first_pub, page: first_page} = publication_with_page("First Source")
    %{pub: second_pub, page: second_page} = publication_with_page("Second Source")
    state = make_publication_available(state, first_pub)
    state = make_publication_available(state, second_pub)

    insert(:project_resource, %{
      project_id: second_pub.project_id,
      resource_id: first_page.resource_id
    })

    pr_by_pub = Publishing.get_published_resources_for_publications([first_pub.id, second_pub.id])

    assert {:error, :selected_projects_share_resources} =
             Remix.add_materials(
               state,
               [{first_pub.id, first_page.resource_id}, {second_pub.id, second_page.resource_id}],
               pr_by_pub
             )
  end

  defp find_sr(h, uuid) do
    if h.uuid == uuid do
      h.section_resource
    else
      h.children |> Enum.map(&find_sr(&1, uuid)) |> Enum.find(& &1)
    end
  end

  defp make_publication_available(state, pub) do
    %{state | available_sources: [Source.project(pub) | state.available_sources]}
  end

  defp publication_with_page(page_title, opts \\ []) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    page =
      case Keyword.get(opts, :shared_page) do
        nil ->
          insert(:revision, %{
            resource_type_id: Oli.Resources.ResourceType.id_for_page(),
            title: page_title
          })

        shared_page ->
          shared_page
      end

    root =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        title: "Root #{page_title}",
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

      insert(:project_resource, %{project_id: project.id, resource_id: r.resource_id})
    end)

    %{project: project, pub: pub, root: root, page: page}
  end
end
