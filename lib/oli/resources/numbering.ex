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

  defstruct level: 0,
            index: 0,
            revision: nil

  def container_type(level) do
    case level do
      1 -> "Unit"
      2 -> "Module"
      _ -> "Section"
    end
  end

  def prefix(numbering) do
    container_type(numbering.level) <> " #{numbering.index}"
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
  def number_tree_from(revision, revisions) do
    # for all revisions, map them by their ids
    by_id =
      Enum.filter(revisions, fn r ->
        r.resource_type_id == ResourceType.get_id_by_type("page") or
          r.resource_type_id == ResourceType.get_id_by_type("container")
      end)
      |> Enum.reduce(%{}, fn e, m -> Map.put(m, e.resource_id, e) end)

    # now recursively walk the tree structure, tracking level based numbering as we go
    numberings = init_numberings()
    level = 0
    numberings_by_id = %{}
    {_, numberings_by_id} = number_helper(revision, by_id, level, numberings, numberings_by_id)

    numberings_by_id
  end

  # recursive helper to assemble the full hierarchy numberings
  defp number_helper(revision, by_id, level, numberings, numberings_by_id) do
    revision.children
    |> Enum.map(fn id -> Map.get(by_id, id) end)
    |> Enum.reduce({numberings, numberings_by_id}, fn child, {numberings, numberings_by_id} ->
      {index, numberings} = next_index(numberings, level, child)
      numbering = %__MODULE__{level: level, index: index, revision: child}

      number_helper(
        child,
        by_id,
        level + 1,
        numberings,
        Map.put(numberings_by_id, child.id, numbering)
      )
    end)
  end

  def next_index(numberings, level, revision) do
    page = ResourceType.get_id_by_type("page")
    container = ResourceType.get_id_by_type("container")

    case revision.resource_type_id do
      ^page ->
        get_and_update_in(numberings, [:pages], &increment_or_init/1)

      ^container ->
        get_and_update_in(numberings, [:containers, level], &increment_or_init/1)
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

  def init_numberings() do
    %{pages: 1, containers: %{}}
  end
end
