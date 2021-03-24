defmodule Oli.Versioning.RevisionTree.Tree do

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Authoring.Course
  alias Oli.Versioning.RevisionTree.Node


  @doc """
  Partitions the revisions for a resource into projects
  """
  def build(resource_id) do

    revisions = list_revisions_by_resource(resource_id)
    projects = Course.list_projects_containing_resource(resource_id)
    head_revisions = Enum.map(projects, fn p -> AuthoringResolver.from_resource_id(p.slug, resource_id) end)

    build(revisions, head_revisions, projects)

  end

  def build(revisions, head_revisions, projects) do

    by_id = Enum.reduce(revisions, %{}, fn e, m -> Map.put(m, e.id, e) end)

    Enum.zip(head_revisions, projects)
    |> Enum.reduce(%{}, fn {head, project}, nodes ->

      case Map.get(nodes, head.id) do

        nil ->
          node = %Node{revision: head, children: [], project_id: project.id}
          track_back(node, by_id, project, Map.put(nodes, head.id, node))

        node -> nodes

      end
    end)

  end


  defp track_back(child_node, by_id, project, nodes) do

    # See if this revision has a previous revision linked to it
    case child_node.revision.previous_revision_id do

      # It does not, which represents the original revision for this resource
      nil -> nodes

      id ->

        # There is a previous revision, so lets first check to see if the previous
        # is a revision that we have encountered before (by tracing back from another head).
        previous = Map.get(by_id, id)

        case Map.get(nodes, previous.id) do

          # We haven't encountered it yet, so we simply create a new tree node, store it and
          # continue tracking backwards into the previous
          nil ->
            previous_node = %Node{revision: previous, children: [child_node], project_id: project.id}
            nodes = Map.put(nodes, previous.id, previous_node)
            track_back(previous_node, by_id, project, nodes)

          # We have encountered this previous revision already so this previous represents a
          # "fork" point in our revision history - simply update the children node to wire in this
          # new descendent path
          node ->
            Map.put(nodes, previous.id, %Node{revision: node.revision, children: node.children ++ [child_node], project_id: node.project_id})

        end

    end

  end

  def list_revisions_by_resource(resource_id) do
    Repo.all(from r in Revision,
      where: r.resource_id == ^resource_id,
      select: map(r, [:id, :previous_revision_id]))
  end

end
