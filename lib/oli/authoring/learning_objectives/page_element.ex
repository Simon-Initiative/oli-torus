defmodule Oli.Authoring.LearningObjectives.PageElement do
  @moduledoc """
  Resolves the Learning Objectives authoring payload for the page element.

  The returned data is a read-only snapshot used by the page editor to refresh
  element advisory state during page load. It does not attach or detach
  objectives from pages, activities, or objective hierarchy revisions.
  """

  import Ecto.Query, warn: false

  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Publishing.PublishedResource
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Resources.ResourceType

  @page_id ResourceType.id_for_page()
  @container_id ResourceType.id_for_container()
  @activity_id ResourceType.id_for_activity()

  @type resolved_objective :: %{
          resource_id: pos_integer(),
          title: String.t(),
          description: String.t() | nil,
          parent_resource_id: pos_integer() | nil,
          children: [pos_integer()],
          related_activity_ids: [pos_integer()],
          directly_matched: boolean()
        }

  @doc """
  Returns objectives attached to activities in the current page's container scope.

  The `hierarchy` should come from `AuthoringResolver.full_hierarchy/1` for the
  same project and working publication. Traversing that hierarchy lets us reuse
  current page revisions and their maintained `activity_refs` instead of scanning
  page JSON or issuing a query per descendant page.
  """
  @spec resolve(
          String.t(),
          pos_integer(),
          HierarchyNode.t(),
          [map()]
        ) :: [resolved_objective()]
  def resolve(project_slug, page_resource_id, %HierarchyNode{} = hierarchy, objective_revisions) do
    hierarchy
    |> scope_container_for_page(page_resource_id)
    |> descendant_page_activity_ids()
    |> related_objectives_by_activity(project_slug)
    |> build_objective_payload(objective_revisions)
  end

  @doc """
  True when the page content contains at least one Learning Objectives element.
  """
  @spec has_learning_objectives_element?(map()) :: boolean()
  def has_learning_objectives_element?(%{"model" => _model} = content) do
    Oli.Resources.PageContent.flat_filter(content, fn
      %{"type" => "learning_objectives"} -> true
      _ -> false
    end)
    |> Enum.any?()
  end

  def has_learning_objectives_element?(_), do: false

  defp scope_container_for_page(%HierarchyNode{} = hierarchy, page_resource_id) do
    case path_to_resource(hierarchy, page_resource_id) do
      nil ->
        hierarchy

      path ->
        path
        |> Enum.drop(-1)
        |> Enum.reverse()
        |> Enum.find(hierarchy, &container?/1)
    end
  end

  defp path_to_resource(%HierarchyNode{resource_id: resource_id} = node, resource_id), do: [node]

  defp path_to_resource(%HierarchyNode{children: children} = node, resource_id) do
    Enum.find_value(children, fn child ->
      case path_to_resource(child, resource_id) do
        nil -> nil
        path -> [node | path]
      end
    end)
  end

  defp container?(%HierarchyNode{revision: %Revision{resource_type_id: @container_id}}), do: true
  defp container?(_), do: false

  defp descendant_page_activity_ids(%HierarchyNode{} = container) do
    container
    |> descendant_pages()
    |> Enum.flat_map(fn %HierarchyNode{revision: %Revision{activity_refs: activity_refs}} ->
      activity_refs || []
    end)
    |> Enum.uniq()
  end

  defp descendant_pages(%HierarchyNode{revision: %Revision{resource_type_id: @page_id}} = node),
    do: [node]

  defp descendant_pages(%HierarchyNode{children: children}) do
    Enum.flat_map(children, &descendant_pages/1)
  end

  defp related_objectives_by_activity([], _project_slug), do: %{}

  defp related_objectives_by_activity(activity_ids, project_slug) do
    activity_objective_refs(project_slug, activity_ids)
    |> Enum.reduce(%{}, fn %{resource_id: activity_id, objectives: objectives}, acc ->
      objectives
      |> objective_ids_from_activity()
      |> Enum.reduce(acc, fn objective_id, acc ->
        Map.update(acc, objective_id, [activity_id], fn activity_ids ->
          [activity_id | activity_ids]
        end)
      end)
    end)
    |> Map.new(fn {objective_id, activity_ids} ->
      {objective_id, Enum.sort(Enum.uniq(activity_ids))}
    end)
  end

  defp activity_objective_refs(project_slug, activity_ids) do
    # Keep this page-load query narrow. Activity revision content can be large,
    # but objective reconciliation only needs each activity id and objective map.
    Repo.all(
      from mapping in PublishedResource,
        join: rev in Revision,
        on:
          rev.id == mapping.revision_id and
            rev.resource_id == mapping.resource_id,
        where:
          mapping.publication_id in subquery(
            AuthoringResolver.project_working_publication(project_slug)
          ) and
            mapping.resource_id in ^activity_ids and
            rev.resource_type_id == @activity_id and
            rev.deleted == false and
            rev.resource_scope == :project,
        select: %{resource_id: rev.resource_id, objectives: rev.objectives}
    )
  end

  defp objective_ids_from_activity(objectives) when is_map(objectives) do
    objectives
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(&is_integer/1)
    |> Enum.uniq()
  end

  defp objective_ids_from_activity(_), do: []

  defp build_objective_payload(related_by_objective, objective_revisions) do
    directly_matched_ids =
      related_by_objective
      |> Map.keys()
      |> MapSet.new()

    objectives_by_id =
      objective_revisions
      |> Enum.map(fn objective -> {objective.resource_id, objective} end)
      |> Map.new()

    parent_by_child = parent_by_child(objective_revisions)
    children_by_parent = children_by_parent(objective_revisions)

    included_ids =
      directly_matched_ids
      |> include_parent_objectives(parent_by_child)
      |> MapSet.intersection(MapSet.new(Map.keys(objectives_by_id)))

    objective_revisions
    |> ordered_objective_ids(parent_by_child, children_by_parent)
    |> Enum.filter(&MapSet.member?(included_ids, &1))
    |> Enum.map(fn objective_id ->
      objective = Map.fetch!(objectives_by_id, objective_id)

      %{
        resource_id: objective.resource_id,
        title: objective.title,
        description: Map.get(objective, :description),
        parent_resource_id: Map.get(parent_by_child, objective.resource_id),
        children: Map.get(children_by_parent, objective.resource_id, []),
        related_activity_ids: Map.get(related_by_objective, objective.resource_id, []),
        directly_matched: MapSet.member?(directly_matched_ids, objective.resource_id)
      }
    end)
  end

  defp parent_by_child(objective_revisions) do
    Enum.reduce(objective_revisions, %{}, fn objective, acc ->
      objective.children
      |> Enum.reduce(acc, fn child_id, acc ->
        Map.put_new(acc, child_id, objective.resource_id)
      end)
    end)
  end

  defp children_by_parent(objective_revisions) do
    objective_revisions
    |> Enum.map(fn objective ->
      {objective.resource_id, Enum.sort(objective.children || [])}
    end)
    |> Map.new()
  end

  defp include_parent_objectives(objective_ids, parent_by_child) do
    Enum.reduce(objective_ids, objective_ids, fn objective_id, included ->
      include_ancestors(objective_id, included, parent_by_child)
    end)
  end

  defp include_ancestors(objective_id, included, parent_by_child) do
    case Map.get(parent_by_child, objective_id) do
      nil ->
        included

      parent_id ->
        include_ancestors(parent_id, MapSet.put(included, parent_id), parent_by_child)
    end
  end

  defp ordered_objective_ids(objective_revisions, parent_by_child, children_by_parent) do
    known_ids = MapSet.new(Enum.map(objective_revisions, & &1.resource_id))
    objectives_by_id = Map.new(objective_revisions, &{&1.resource_id, &1})

    root_ids =
      objective_revisions
      |> Enum.map(& &1.resource_id)
      |> Enum.reject(&Map.has_key?(parent_by_child, &1))

    root_ids
    |> sort_ids(objectives_by_id)
    |> Enum.flat_map(&preorder_ids(&1, children_by_parent, objectives_by_id, known_ids))
  end

  defp preorder_ids(objective_id, children_by_parent, objectives_by_id, known_ids) do
    children =
      children_by_parent
      |> Map.get(objective_id, [])
      |> Enum.filter(&MapSet.member?(known_ids, &1))
      |> sort_ids(objectives_by_id)

    [
      objective_id
      | Enum.flat_map(
          children,
          &preorder_ids(&1, children_by_parent, objectives_by_id, known_ids)
        )
    ]
  end

  defp sort_ids(ids, objectives_by_id) do
    Enum.sort_by(ids, fn id ->
      objective = Map.get(objectives_by_id, id)
      {(objective && objective.title) || "", id}
    end)
  end
end
