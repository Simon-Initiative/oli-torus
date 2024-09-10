defmodule Oli.Delivery.Sections.MinimalHierarchy do
  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Resources.Numbering
  alias Oli.Branding.CustomLabels
  alias Oli.Repo

  alias Oli.Publishing.{
    PublishedResource
  }

  import Oli.Utils

  require Logger

  def published_resources_map(publication_ids) when is_list(publication_ids) do
    PublishedResource
    |> join(:left, [pr], r in Oli.Resources.Revision, on: pr.revision_id == r.id)
    |> join(:left, [pr, _], p in Oli.Publishing.Publications.Publication,
      on: pr.publication_id == p.id
    )
    |> where([pr, _r], pr.publication_id in ^publication_ids)
    |> select([pr, r, p], %{
      resource_id: pr.resource_id,
      children: r.children,
      revision_id: pr.revision_id,
      resource_type_id: r.resource_type_id,
      title: r.title,
      scoring_strategy_id: r.scoring_strategy_id,
      collab_space_config: r.collab_space_config,
      max_attempts: r.max_attempts,
      retake_mode: r.retake_mode,
      assessment_mode: r.assessment_mode,
      project_id: p.project_id,
      deleted: r.deleted
    })
    |> Repo.all()
    |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.resource_id, r) end)
  end

  def published_resources_map(publication_id) do
    project_id =
      from(
        p in Oli.Publishing.Publications.Publication,
        where: p.id == ^publication_id,
        select: p.project_id
      )
      |> Repo.one()

    PublishedResource
    |> join(:left, [pr], r in Oli.Resources.Revision, on: pr.revision_id == r.id)
    |> where([pr, _r], pr.publication_id == ^publication_id)
    |> select([pr, r], %{
      resource_id: pr.resource_id,
      children: r.children,
      revision_id: pr.revision_id,
      resource_type_id: r.resource_type_id,
      title: r.title,
      scoring_strategy_id: r.scoring_strategy_id,
      collab_space_config: r.collab_space_config,
      max_attempts: r.max_attempts,
      retake_mode: r.retake_mode,
      assessment_mode: r.assessment_mode,
      deleted: r.deleted
    })
    |> Repo.all()
    |> Enum.map(fn pr -> Map.put(pr, :project_id, project_id) end)
    |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.resource_id, r) end)
  end

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
      Enum.filter(children_ids, fn sr_id -> !is_nil(Map.get(nodes_by_sr_id, sr_id)) end)
      |> Enum.map(fn sr_id ->
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
      [sr: sr, rev: rev, spp: spp] in Oli.Publishing.DeliveryResolver.section_resource_revisions(
        section_slug
      ),
      join: p in Oli.Authoring.Course.Project,
      on: p.id == spp.project_id,
      where:
        rev.resource_type_id == ^page_id or
          rev.resource_type_id == ^container_id,
      select:
        {sr,
         %{
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
