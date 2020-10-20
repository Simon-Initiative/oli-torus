defmodule Oli.Resources.Numbering do
  alias Oli.Resources.ResourceType
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.Revision

  defstruct level: 0,
            count: 0,
            container: nil

  def prefix(numbering) do
    case numbering.level do
      1 -> "Unit"
      2 -> "Module"
      _ -> "Section"
    end <> " #{numbering.count}"
  end

  @typep project_slug :: String.t()
  @typep revision_slug :: String.t()
  @typep resource_id :: Number.t()
  @doc """
  Returns the path from a project's root container to a requested revision slug.

  ## Parameters

    - project_slug
    - revision_slug: The revision slug we want to find from the root container.

  ## Examples

     iex> Numbering.path_from_root_to(project_slug, revision_slug)
     [%Revision{}, %Revision{}, %Revision{}]
     [root_container, container_revision, requested_revision]

  """
  @spec path_from_root_to(project_slug, revision_slug) ::
          {:ok, [%Revision{}]} | {:error, :target_resource_not_found}
  def path_from_root_to(project_slug, revision_slug) do
    with root_container <- AuthoringResolver.root_container(project_slug),
         path <-
           path_helper(
             revision_slug,
             root_container.children,
             resource_id_to_revision_map(project_slug),
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

  @spec resource_id_to_revision_map(project_slug) :: %{resource_id => %Revision{}}
  defp resource_id_to_revision_map(project_slug) do
    for rev <- AuthoringResolver.all_revisions_in_hierarchy(project_slug),
        into: %{},
        do: {rev.resource_id, rev}
  end

  defp path_helper(_target_slug, [] = _resource_ids, _revisions, _path) do
    []
  end

  defp path_helper(
         target_slug,
         [resource_id | rest] = _resource_ids_to_look_through,
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

  This method returns a list of %Numbering structs.
  """
  def number_full_tree(project_slug) do
    number_full_tree(
      AuthoringResolver.root_container(project_slug),
      AuthoringResolver.all_revisions_in_hierarchy(project_slug)
    )
  end

  def number_full_tree(root_container, resources) do
    # for all resources, map them by their ids
    by_id =
      Enum.filter(resources, fn r ->
        r.resource_type_id == ResourceType.get_id_by_type("container")
      end)
      |> Enum.reduce(%{}, fn e, m -> Map.put(m, e.resource_id, e) end)

    numberings = %{}

    # now recursively walk the tree structure, tracking level based numbering as we go
    level_counts = %{}
    {_, numberings} = number_helper(root_container, by_id, 1, level_counts, numberings)

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
