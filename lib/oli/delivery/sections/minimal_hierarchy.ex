defmodule Oli.Delivery.Sections.MinimalHierarchy do

  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Resources.Numbering
  alias Oli.Branding.CustomLabels
  alias Oli.Repo

  import Oli.Utils

  require Logger

  def full_hierarchy(section_slug) do

    mark = Oli.Timing.mark()

    {hierarchy_nodes, root_hierarchy_node} = hierarchy_nodes_by_sr_id(section_slug)
    result = hierarchy_node_with_children(root_hierarchy_node, hierarchy_nodes)

    Logger.info("MinimalHierarchy.full_hierarchy: #{Oli.Timing.elapsed(mark) / 1000 / 1000}ms")

    result
  end

  defp hierarchy_node_with_children(
        %HierarchyNode{children: children_ids} = node,
        nodes_by_sr_id
      ) do
    Map.put(
      node,
      :children,
      Enum.map(children_ids, fn sr_id ->
        Map.get(nodes_by_sr_id, sr_id)
        |> hierarchy_node_with_children(nodes_by_sr_id)
      end)
    )
  end

  # Returns a map of resource ids to hierarchy nodes and the root hierarchy node
  defp hierarchy_nodes_by_sr_id(section_slug) do
    page_id = Oli.Resources.ResourceType.get_id_by_type("page")
    container_id = Oli.Resources.ResourceType.get_id_by_type("container")

    section = Sections.get_section_by(slug: section_slug)

    labels =
      case section.customizations do
        nil -> Map.from_struct(CustomLabels.default())
        l -> Map.from_struct(l)
      end

    from(
      [sr: sr, rev: rev, spp: spp] in Oli.Publishing.DeliveryResolver.section_resource_revisions(section_slug),
      join: p in Oli.Authoring.Course.Project,
      on: p.id == spp.project_id,
      where:
        rev.resource_type_id == ^page_id or
          rev.resource_type_id == ^container_id,
      select:
        {sr, %{
          id: rev.id,
          resource_id: rev.resource_id,
          resource_type_id: rev.resource_type_id,
          slug: rev.slug,
          title: rev.title,
          graded: rev.graded
        }, p.slug}
    )
    |> Repo.all()
    |> Enum.reduce({%{}, nil}, fn {sr, rev, proj_slug}, {nodes, root} ->

      is_root? = section.root_section_resource_id == sr.id

      node = %HierarchyNode{
        uuid: uuid(),
        numbering: %Numbering{
          index: sr.numbering_index,
          level: sr.numbering_level,
          labels: labels
        },
        children: sr.children,
        resource_id: rev.resource_id,
        project_id: sr.project_id,
        project_slug: proj_slug,
        revision: rev,
        section_resource: sr
      }

      {
        Map.put(
          nodes,
          sr.id,
          node
        ),
        if(is_root?, do: node, else: root)
      }
    end)

  end

end
