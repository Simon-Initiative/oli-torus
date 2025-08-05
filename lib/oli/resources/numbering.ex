defmodule Oli.Resources.Numbering do
  @moduledoc """
  Numbering module handles number generation for a course hierarchy and contains helper methods
  used in both authoring and delivery.

  Delivery numberings are generated at section resource creation time and authoring numberings
  are generated JIT on resource access. This is because once section resources are generated, they
  are unexpected to change as often as perhaps a course under active development in authoring might.

  Numbering is dictated according to the resource type and level:
    - Pages: All pages are numbered sequentially in course globally. Pages across modules can be
      conceptualized (and navigated via previous/next) as a contiguous list of resources like pages in a book.
    - Containers: Container numberings are scoped to their level in the hierarchy

  For Example:
  ```
    - Unit 1:
      - Module 1
        - Section 1
          - Page 1
          - Page 2
        - Section 2
          - Section 1
            - Page 3
            - Page 4
            - Page 5
      - Module 2
        - Section 3
          - Section 2
            - Page 6
            - Page 7
    - Unit 2:
      - Module 3
        - Section 4
          - Page 8
          - Page 9
        - Section 5
          - Section 1
            - Page 10
            - Page 11
            - Page 12
    - Page 13
  ```
  """
  alias Oli.Resources.ResourceType
  alias Oli.Resources.Revision
  alias Oli.Publishing.Resolver
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Branding.CustomLabels

  @derive Jason.Encoder
  defstruct level: 0,
            index: 0,
            labels: CustomLabels.default_map()

  def container_type_label(numbering) do
    labels = numbering.labels || CustomLabels.default_map()

    case numbering.level do
      1 -> Map.get(labels, :unit)
      2 -> Map.get(labels, :module)
      _ -> Map.get(labels, :section)
    end
  end

  def prefix(numbering) do
    container_type_label(numbering) <> " #{numbering.index}"
  end

  @typep project_or_section_slug :: String.t()
  @typep revision_slug :: String.t()
  @typep resource_id :: Number.t()
  @typep revision_id :: Number.t()
  @typep resolver :: Resolver.t()

  @doc """
  Returns the path from a project's root container to a requested revision slug.

  ## Parameters

    - project_or_section_slug: The project slug or section slug.
    - revision_slug: The revision slug we want to find from the root container.

  ## Examples

     iex> Numbering.path_from_root_to(project_slug, revision_slug)
     [%Revision{}, %Revision{}, %Revision{}]
     [root_container, container_revision, requested_revision]

  """
  @spec path_from_root_to(resolver, project_or_section_slug, revision_slug) ::
          {:ok, [%Revision{}]} | {:error, :target_resource_not_found}
  def path_from_root_to(resolver, project_or_section_slug, revision_slug) do
    with root_container <- resolver.root_container(project_or_section_slug),
         path <-
           revision_path_helper(
             revision_slug,
             root_container.children,
             resource_id_to_revision_map(resolver, project_or_section_slug),
             [root_container]
           ) do
      case path do
        [] ->
          if root_container.slug == revision_slug do
            {:ok, [root_container]}
          else
            {:error, :target_resource_not_found}
          end

        list ->
          {:ok, Enum.reverse(list)}
      end
    end
  end

  @doc """
  Returns the path from a hierarchy's root to a given node

  ## Examples

     iex> Numbering.path_from_root_to(hierarchy, node)
     [%HierarchyNode{}, %HierarchyNode{}, %HierarchyNode{}]

  """
  @spec path_from_root_to(%HierarchyNode{}, %HierarchyNode{}) ::
          {:ok, [%HierarchyNode{}]} | {:not_found, []}
  def path_from_root_to(%HierarchyNode{} = hierarchy, %HierarchyNode{} = node) do
    hierachy_path_helper(
      hierarchy,
      node,
      {:not_found, []}
    )
    |> then(fn {status, path} -> {status, Enum.reverse(path)} end)
  end

  @spec resource_id_to_revision_map(resolver, project_or_section_slug) :: %{
          resource_id => %Revision{}
        }
  defp resource_id_to_revision_map(resolver, project_or_section_slug) do
    for rev <- resolver.all_revisions_in_hierarchy(project_or_section_slug),
        into: %{},
        do: {rev.resource_id, rev}
  end

  defp revision_path_helper(_target_slug, [] = _resource_ids, _revisions, _path) do
    []
  end

  defp revision_path_helper(
         target_slug,
         [resource_id | rest],
         resource_id_to_revision_map,
         path
       ) do
    with revision <- Map.get(resource_id_to_revision_map, resource_id),
         path_using_revision <-
           revision_path_helper(
             target_slug,
             revision.children,
             resource_id_to_revision_map,
             [revision | path]
           ) do
      cond do
        target_slug == revision.slug ->
          [revision | path]

        !Enum.empty?(path_using_revision) ->
          path_using_revision

        true ->
          revision_path_helper(target_slug, rest, resource_id_to_revision_map, path)
      end
    end
  end

  defp hierachy_path_helper(
         %HierarchyNode{} = current_node,
         %HierarchyNode{} = node,
         {:not_found, path}
       ) do
    container = ResourceType.id_for_container()
    path = [current_node | path]

    if current_node.uuid == node.uuid do
      {:ok, path}
    else
      current_node.children
      |> Enum.filter(fn %{revision: r} -> r.resource_type_id == container end)
      |> Enum.reduce_while({:not_found, path}, fn child, path_tracker ->
        case hierachy_path_helper(child, node, path_tracker) do
          {:ok, _path} = result -> {:halt, result}
          {:not_found, _} -> {:cont, {:not_found, path}}
        end
      end)
    end
  end

  @doc """
  Generates a level-based numbering of the containers found in a course hierarchy.

  This method returns a map of revision id to %Numbering structs.
  """
  @spec number_full_tree(resolver, project_or_section_slug, %CustomLabels{}) :: %{
          revision_id => %__MODULE__{}
        }
  def number_full_tree(resolver, project_or_section_slug, labels) do
    root = resolver.root_container(project_or_section_slug)

    full_tree =
      number_tree_from(
        root,
        resolver.all_revisions_in_hierarchy(project_or_section_slug)
      )
      # include numbering for root container, used on initial container add
      |> Map.put(root.id, %__MODULE__{level: 0, index: 1})

    case labels do
      nil ->
        full_tree

      _ ->
        Enum.reduce(full_tree, %{}, fn {k, val}, acc ->
          Map.put(acc, k, %__MODULE__{val | labels: Map.from_struct(labels)})
        end)
    end
  end

  @spec number_tree_from(%Revision{}, [%Revision{}]) :: %{revision_id => %__MODULE__{}}
  defp number_tree_from(revision, revisions) do
    # for all revisions, map them by their ids
    by_id =
      Enum.filter(revisions, fn r ->
        r.resource_type_id == ResourceType.id_for_page() or
          r.resource_type_id == ResourceType.id_for_container()
      end)
      |> Enum.reduce(%{}, fn e, m -> Map.put(m, e.resource_id, e) end)

    # now recursively walk the tree structure, tracking level based numbering as we go
    numbering_tracker = init_numbering_tracker()
    level = 0
    numberings = %{}

    {_, numberings} = number_helper(revision, by_id, level + 1, numbering_tracker, numberings)

    numberings
  end

  # recursive helper to assemble the full hierarchy numberings
  defp number_helper(revision, by_id, level, numbering_tracker, numberings) do
    revision.children
    |> Enum.map(fn id -> Map.get(by_id, id) end)
    |> Enum.reduce({numbering_tracker, numberings}, fn child, {numbering_tracker, numberings} ->
      {index, numbering_tracker} = next_index(numbering_tracker, level, child)
      numbering = %__MODULE__{level: level, index: index}

      number_helper(
        child,
        by_id,
        level + 1,
        numbering_tracker,
        Map.put(numberings, child.id, numbering)
      )
    end)
  end

  def next_index(numbering_tracker, level, revision) do
    page = ResourceType.id_for_page()
    container = ResourceType.id_for_container()

    case revision.resource_type_id do
      ^page ->
        get_and_update_in(numbering_tracker, [:pages], &increment_or_init/1)

      ^container ->
        get_and_update_in(numbering_tracker, [:containers, level], &increment_or_init/1)
    end
  end

  defp increment_or_init(value) do
    case value do
      nil ->
        {1, 2}

      value ->
        {value, value + 1}
    end
  end

  def init_numbering_tracker() do
    %{pages: 1, containers: %{}}
  end

  @doc """
  Renumbers the section resources in a hierarchy. Takes the hierarchy root and returns the
  updated hierarchy root and generated numberings.

  ## Examples
      iex> renumber_hierarchy(hierarchy)
      {updated_hierarchy, numberings}
  """
  def renumber_hierarchy(%HierarchyNode{} = root) do
    numbering_tracker = init_numbering_tracker()
    level = 0
    numberings = %{}

    {hierarchy, _numbering_tracker, numberings} =
      renumber_hierarchy(root, level, numbering_tracker, numberings)

    {hierarchy, numberings}
  end

  defp renumber_hierarchy(
         %HierarchyNode{children: children} = node,
         level,
         numbering_tracker,
         numberings
       ) do
    {numbering_index, numbering_tracker} = next_index(numbering_tracker, level, node.revision)

    numbering = %__MODULE__{level: level, index: numbering_index, labels: node.numbering.labels}
    numberings = Map.put(numberings, node.revision.id, numbering)

    {children, numbering_tracker, numberings} =
      Enum.reduce(
        children,
        {[], numbering_tracker, numberings},
        fn child, {children, numbering_tracker, numberings} ->
          {child, numbering_tracker, numberings} =
            renumber_hierarchy(
              child,
              level + 1,
              numbering_tracker,
              numberings
            )

          {[child | children], numbering_tracker, numberings}
        end
      )
      # it's more efficient to append to list using [id | children_ids] and
      # then reverse than to concat on every reduce call using ++
      |> then(fn {children, numbering_tracker, numberings} ->
        {Enum.reverse(children), numbering_tracker, numberings}
      end)

    {%HierarchyNode{node | numbering: numbering, children: children}, numbering_tracker,
     numberings}
  end
end
