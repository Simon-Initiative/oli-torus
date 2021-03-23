defmodule OliWeb.RevisionHistory.RevisionTree do

  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Resources
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Authoring.Course
  alias OliWeb.RevisionHistory.TreeNode


  @doc """
  Partitions the revisions for a resource into projects
  """
  def build_revision_tree(resource_id) do

    # get all revisions for this resource
    # get all projects that have this resource
    # authoring resolve the head revisions for each project

    # from each project head revision, walk backwards building
    # a structure to track the entire revision tree

    revisions = list_revisions_by_resource(resource_id)

    projects = Course.list_projects_containing_resource(resource_id)

    heads = Enum.map(projects, fn p -> AuthoringResolver.from_resource_id(p.slug, resource_id) end)
    |> Enum.zip(projects)

    seen_revisions = MapSet.new()

    nodes


  end

  def build_revision_tree(revisions, head_revisions, projects) do

    by_id = Enum.reduce(revisions, %{}, fn e, m -> Map.put(m, r.id, r) end)
    by_previous = Enum.reduce(revisions, %{}, fn e, m -> Map.put(m, r.previous_revision_id, r) end)

    seen_revisions = MapSet.new()

    heads = Enum.zip(head_revisions, projects)

    Enum.reduce(heads, %{}, fn {head, project}, nodes ->

      Enum.reduce_while()

    end


  end


  defp track_back(revision, by_id, project, nodes) do

    case revision.previous_revision_id do
      nil -> nodes
      id ->
        previous = Map.get(by_id, id)

        case Map.get(nodes, previous.id) do

          nil ->
            nodes = Map.put(nodes, previous.id, %TreeNode{revision: previous, children: [child], project_id: project.id})
            track_back(previous, by_id, project, nodes)

          node ->

            Map.put(nodes, previous.id, %TreeNode{revision: previous, children: [child], project_id: project.id}))

        end


    end


  end


  def list_revisions_by_resource(resource_id) do
    Repo.all(from r in Revision,
      where: r.resource_id == ^resource_id,
      select: map(r, [:id, :previous_revision_id])
  end


end
