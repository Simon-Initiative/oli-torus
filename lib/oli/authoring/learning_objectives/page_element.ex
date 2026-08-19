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
          parent_resource_ids: [pos_integer()],
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

    parent_ids_by_child = parent_ids_by_child(objective_revisions)
    children_by_parent = children_by_parent(objective_revisions)

    included_ids =
      directly_matched_ids
      |> include_parent_objectives(parent_ids_by_child)
      |> MapSet.intersection(MapSet.new(Map.keys(objectives_by_id)))

    objective_revisions
    |> ordered_objective_ids(parent_ids_by_child, children_by_parent)
    |> Enum.filter(&MapSet.member?(included_ids, &1))
    |> Enum.map(fn objective_id ->
      objective = Map.fetch!(objectives_by_id, objective_id)
      parent_resource_ids = Map.get(parent_ids_by_child, objective.resource_id, [])

      %{
        resource_id: objective.resource_id,
        title: objective.title,
        description: Map.get(objective, :description),
        parent_resource_id: List.first(parent_resource_ids),
        parent_resource_ids: parent_resource_ids,
        children: Map.get(children_by_parent, objective.resource_id, []),
        related_activity_ids: Map.get(related_by_objective, objective.resource_id, []),
        directly_matched: MapSet.member?(directly_matched_ids, objective.resource_id)
      }
    end)
  end

  defp parent_ids_by_child(objective_revisions) do
    objective_revisions
    |> Enum.reduce(%{}, fn objective, acc ->
      objective.children
      |> Enum.reduce(acc, fn child_id, acc ->
        Map.update(acc, child_id, MapSet.new([objective.resource_id]), fn parent_ids ->
          MapSet.put(parent_ids, objective.resource_id)
        end)
      end)
    end)
    |> Enum.into(%{}, fn {child_id, parent_ids} ->
      {child_id, parent_ids |> MapSet.to_list() |> Enum.sort()}
    end)
  end

  defp children_by_parent(objective_revisions) do
    objective_revisions
    |> Enum.map(fn objective ->
      {objective.resource_id, Enum.sort(objective.children || [])}
    end)
    |> Map.new()
  end

  defp include_parent_objectives(objective_ids, parent_ids_by_child) do
    Enum.reduce(objective_ids, objective_ids, fn objective_id, included ->
      include_ancestors(objective_id, included, parent_ids_by_child)
    end)
  end

  defp include_ancestors(objective_id, included, parent_ids_by_child) do
    parent_ids_by_child
    |> Map.get(objective_id, [])
    |> Enum.reduce(included, fn parent_id, included ->
      include_ancestors(parent_id, MapSet.put(included, parent_id), parent_ids_by_child)
    end)
  end

  defp ordered_objective_ids(objective_revisions, parent_ids_by_child, children_by_parent) do
    known_ids = MapSet.new(Enum.map(objective_revisions, & &1.resource_id))
    objectives_by_id = Map.new(objective_revisions, &{&1.resource_id, &1})

    root_ids =
      objective_revisions
      |> Enum.map(& &1.resource_id)
      |> Enum.reject(&Map.has_key?(parent_ids_by_child, &1))

    {ordered_ids, emitted_ids} =
      root_ids
      |> sort_ids(objectives_by_id)
      |> visit_ids(
        children_by_parent,
        parent_ids_by_child,
        objectives_by_id,
        known_ids,
        [],
        MapSet.new()
      )

    remaining_ids =
      known_ids
      |> MapSet.difference(emitted_ids)
      |> MapSet.to_list()
      |> sort_ids(objectives_by_id)

    {ordered_ids, _emitted_ids} =
      visit_ids(
        remaining_ids,
        children_by_parent,
        parent_ids_by_child,
        objectives_by_id,
        known_ids,
        ordered_ids,
        emitted_ids
      )

    ordered_ids
  end

  defp visit_ids(
         objective_ids,
         children_by_parent,
         parent_ids_by_child,
         objectives_by_id,
         known_ids,
         ordered_ids,
         emitted_ids
       ) do
    Enum.reduce(objective_ids, {ordered_ids, emitted_ids}, fn objective_id,
                                                              {ordered_ids, emitted_ids} ->
      visit_id(
        objective_id,
        children_by_parent,
        parent_ids_by_child,
        objectives_by_id,
        known_ids,
        ordered_ids,
        emitted_ids
      )
    end)
  end

  defp visit_id(
         objective_id,
         children_by_parent,
         parent_ids_by_child,
         objectives_by_id,
         known_ids,
         ordered_ids,
         emitted_ids
       ) do
    cond do
      MapSet.member?(emitted_ids, objective_id) ->
        {ordered_ids, emitted_ids}

      waiting_for_parent?(objective_id, parent_ids_by_child, known_ids, emitted_ids) ->
        {ordered_ids, emitted_ids}

      true ->
        child_ids =
          children_by_parent
          |> Map.get(objective_id, [])
          |> Enum.filter(&MapSet.member?(known_ids, &1))
          |> sort_ids(objectives_by_id)

        visit_ids(
          child_ids,
          children_by_parent,
          parent_ids_by_child,
          objectives_by_id,
          known_ids,
          ordered_ids ++ [objective_id],
          MapSet.put(emitted_ids, objective_id)
        )
    end
  end

  defp waiting_for_parent?(objective_id, parent_ids_by_child, known_ids, emitted_ids) do
    parent_ids_by_child
    |> Map.get(objective_id, [])
    |> Enum.any?(fn parent_id ->
      MapSet.member?(known_ids, parent_id) && !MapSet.member?(emitted_ids, parent_id)
    end)
  end

  defp sort_ids(ids, objectives_by_id) do
    Enum.sort_by(ids, fn id ->
      objective = Map.get(objectives_by_id, id)
      {(objective && objective.title) || "", id}
    end)
  end
end
