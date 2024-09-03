defmodule Oli.Versioning.RevisionTree.Tree do
  import Ecto.Query, warn: false

  alias Oli.Publishing.AuthoringResolver
  alias Oli.Authoring.Course
  alias Oli.Versioning.RevisionTree.Node

  @doc """
  Creates a tree representation of a collection revisions for one resource id.
  """
  def build(revisions, resource_id) do
    projects =
      Course.list_projects_containing_resource(resource_id)
      |> sort_preorder

    head_revisions =
      Enum.map(projects, fn p -> AuthoringResolver.from_resource_id(p.slug, resource_id) end)

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

        _ ->
          nodes
      end
    end)
  end

  # Sorts a collection of projects according by a preorder tree traversal, based on the
  # tree structure of parent project references
  def sort_preorder(projects) do
    by_parent =
      Enum.reduce(projects, %{}, fn e, m ->
        case Map.get(m, e.project_id) do
          nil -> Map.put(m, e.project_id, [e])
          others -> Map.put(m, e.project_id, others ++ [e])
        end
      end)

    project_ids =
      Enum.map(projects, fn p -> p.id end)
      |> MapSet.new()

    # Determine the project that this resource was originally created in. It is the
    # project whose parent reference is not in this set
    [root_project] = Enum.filter(projects, fn p -> !MapSet.member?(project_ids, p.project_id) end)

    sort_preorder_helper([], root_project, by_parent)
  end

  defp sort_preorder_helper(projects, current, by_parent) do
    # if this current one is not the parent of any other, we reach our base case
    case Map.get(by_parent, current.id) do
      nil ->
        projects ++ [current]

      children ->
        Enum.reduce(children, projects ++ [current], fn c, all ->
          sort_preorder_helper(all, c, by_parent)
        end)
    end
  end

  defp track_back(child_node, by_id, project, nodes) do
    # See if this revision has a previous revision linked to it
    case child_node.revision.previous_revision_id do
      # It does not, which represents the original revision for this resource
      nil ->
        nodes

      id ->
        # Identified in MER-3625, duplicated resources created in the system prior to the
        # fix will have a first revision that points to the old resource revision. This
        # is a special case where we simply ignore the previous revision that is not in the
        # set of revisions we are tracking for the current resource.
        case Map.get(by_id, id) do
          nil ->
            nodes

          previous ->
            # There is a previous revision, so lets first check to see if the previous
            # is a revision that we have encountered before (by tracing back from another head).

            case Map.get(nodes, previous.id) do
              # We haven't encountered it yet, so we simply create a new tree node, store it and
              # continue tracking backwards into the previous
              nil ->
                previous_node = %Node{
                  revision: previous,
                  children: [child_node.revision.id],
                  project_id: project.id
                }

                nodes = Map.put(nodes, previous.id, previous_node)
                track_back(previous_node, by_id, project, nodes)

              # We have encountered this previous revision already so this previous represents a
              # "fork" point in our revision history - simply update the children node to wire in this
              # new descendent path
              node ->
                Map.put(nodes, previous.id, %Node{
                  revision: node.revision,
                  children: node.children ++ [child_node.revision.id],
                  project_id: node.project_id
                })
            end
        end
    end
  end
end
