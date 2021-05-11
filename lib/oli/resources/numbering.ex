defmodule Oli.Resources.Numbering do
  alias Oli.Resources.ResourceType
  alias Oli.Resources.Revision
  alias Oli.Publishing.Resolver
  alias Oli.Utils.HierarchyNode

  defstruct level: 0,
            count: 0,
            container: nil

  def container_type(level) do
    case level do
      1 -> "Unit"
      2 -> "Module"
      _ -> "Section"
    end
  end

  def prefix(numbering) do
    container_type(numbering.level) <> " #{numbering.count}"
  end

  @typep project_or_section_slug :: String.t()
  @typep revision_slug :: String.t()
  @typep resource_id :: Number.t()
  @typep revision_id :: Number.t()
  @typep resolver :: Resolver.t()

  @doc """
  Returns a [%HierarchyNode{}] representing the course's hierarchy structure.

  ## Parameters

    - resolver
    - project_or_section_slug: The project slug or the section slug.

  """
  @spec full_hierarchy(resolver, project_or_section_slug) :: [%HierarchyNode{}]
  def full_hierarchy(resolver, project_or_section_slug) do
    revisions_by_id =
      resolver.all_revisions_in_hierarchy(project_or_section_slug)
      |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.resource_id, r) end)

    full_hierarchy_helper(
      number_full_tree(resolver, project_or_section_slug),
      revisions_by_id,
      resolver.root_container(project_or_section_slug)
    )
  end

  def full_hierarchy_helper(numberings, revisions_by_id, revision) do
    [
      %HierarchyNode{
        revision: revision,
        children:
          Enum.flat_map(
            revision.children,
            fn resource_id ->
              full_hierarchy_helper(
                numberings,
                revisions_by_id,
                Map.get(revisions_by_id, resource_id)
              )
            end
          ),
        numbering: Map.get(numberings, revision.id)
      }
    ]
  end

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
           path_helper(
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

  @spec resource_id_to_revision_map(resolver, project_or_section_slug) :: %{
          resource_id => %Revision{}
        }
  defp resource_id_to_revision_map(resolver, project_or_section_slug) do
    for rev <- resolver.all_revisions_in_hierarchy(project_or_section_slug),
        into: %{},
        do: {rev.resource_id, rev}
  end

  defp path_helper(_target_slug, [] = _resource_ids, _revisions, _path) do
    []
  end

  defp path_helper(
         target_slug,
         [resource_id | rest],
         resource_id_to_revision_map,
         path
       ) do
    with revision <- Map.get(resource_id_to_revision_map, resource_id),
         path_using_revision <-
           path_helper(
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
          path_helper(target_slug, rest, resource_id_to_revision_map, path)
      end
    end
  end

  @doc """
  Generates a level-based numbering of the containers found in a course hierarchy.

  This method returns a map of revision id to %Numbering structs.
  """
  @spec number_full_tree(resolver, project_or_section_slug) :: %{revision_id => %__MODULE__{}}
  def number_full_tree(resolver, project_or_section_slug) do
    number_tree_from(
      resolver.root_container(project_or_section_slug),
      resolver.all_revisions_in_hierarchy(project_or_section_slug)
    )
  end

  @spec number_tree_from(%Revision{}, [%Revision{}]) :: %{revision_id => %__MODULE__{}}
  def number_tree_from(container, resources) do
    # for all resources, map them by their ids
    by_id =
      Enum.filter(resources, fn r ->
        r.resource_type_id == ResourceType.get_id_by_type("container")
      end)
      |> Enum.reduce(%{}, fn e, m -> Map.put(m, e.resource_id, e) end)

    numberings = %{}

    # now recursively walk the tree structure, tracking level based numbering as we go
    level_counts = %{}
    {_, numberings} = number_helper(container, by_id, 1, level_counts, numberings)

    numberings
  end

  # recursive helper to assemble the full hierarchy numberings
  defp number_helper(container, by_id, level, level_counts, numberings) do
    Enum.filter(container.children, fn id -> Map.has_key?(by_id, id) end)
    |> Enum.map(fn id -> Map.get(by_id, id) end)
    |> Enum.reduce({level_counts, numberings}, fn container, {counts, nums} ->
      {counts, count} = increment_count(counts, level)
      numbering = %__MODULE__{level: level, count: count, container: container}

      number_helper(container, by_id, level + 1, counts, Map.put(nums, container.id, numbering))
    end)
  end

  defp increment_count(level_counts, level) do
    count = Map.get(level_counts, level, 0) + 1
    {Map.put(level_counts, level, count), count}
  end
end
