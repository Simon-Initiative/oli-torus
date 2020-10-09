defmodule Oli.Resources.Numbering do

  alias Oli.Resources.ResourceType
  alias Oli.Resources.Revision
  alias Oli.Repo
  import Ecto.Query, warn: false

  defstruct level: 0,
    count: 0,
    container: nil

  def fetch_hierarchy(project_slug) do

    container_id = ResourceType.get_id_by_type("container")

    Repo.all(from m in "published_resources",
      join: rev in Revision, on: rev.id == m.revision_id,
      join: p in "publications", on: p.id == m.publication_id,
      join: c in "projects", on: p.project_id == c.id,
      where: p.published == false and rev.resource_type_id == ^container_id and c.slug == ^project_slug,
      select: rev)

  end

  def prefix(numbering) do
    case numbering.level do
      1 -> "Unit"
      2 -> "Module"
      _ -> "Section"
    end <> " #{numbering.count}"
  end

  @doc """
  Generates a level-based numbering of the containers found in a course hierarchy.

  This method returns a list of %Numbering structs.
  """
  def number_full_tree(root_container, resources) do

    # for all resources, map them by their ids
    by_id = Enum.filter(resources, fn r -> r.resource_type_id == ResourceType.get_id_by_type("container") end)
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
    { Map.put(level_counts, level, count), count }
  end

end
