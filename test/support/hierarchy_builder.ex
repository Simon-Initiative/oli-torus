defmodule Oli.Test.HierarchyBuilder do
  @moduledoc """
  Composable test helper for building project hierarchies declaratively.

  ## Usage

      tree = build_hierarchy(project, publication, author,
        {:container, "Root", [
          {:container, "Unit 1", [
            {:container, "Module 1", [
              {:page, "Page A"},
              {:page, "Page B"}
            ]}
          ]},
          {:container, "Unit 2", [
            {:page, "Page C"}
          ]},
          {:container, "Blueprint Only", [], container_scope: :blueprint}
        ]}
      )

      # Access any node by title:
      tree["Module 1"].resource
      tree["Page A"].revision

  Containers accept an optional keyword list for extra revision attributes
  (e.g., `container_scope: :blueprint`). Defaults to `:project` scope.

  Returns a flat map keyed by title, where each value has `:resource` and `:revision`.
  """

  import Oli.Factory
  import Ecto.Changeset, only: [change: 2]

  alias Oli.Repo
  alias Oli.Resources.ResourceType

  @doc """
  Builds a hierarchy of resources/revisions in the database and returns a flat
  map keyed by title for easy access in tests.

  Each node is a `{type, title}` or `{type, title, children}` tuple where
  `type` is `:container` or `:page`.

  Automatically sets `root_resource_id` on the publication to the root node.
  """
  def build_hierarchy(project, publication, author, tree) do
    {root_node, acc} = build_node(project, publication, author, tree, %{})

    Repo.update!(change(publication, root_resource_id: root_node.resource.id))

    acc
  end

  defp build_node(project, publication, author, {:container, title, children, opts}, acc)
       when is_list(opts) do
    {child_nodes, acc} =
      Enum.reduce(children, {[], acc}, fn child, {nodes, acc} ->
        {node, acc} = build_node(project, publication, author, child, acc)
        {nodes ++ [node], acc}
      end)

    child_ids = Enum.map(child_nodes, & &1.resource.id)

    resource = insert(:resource)

    revision_attrs =
      [
        resource: resource,
        resource_type_id: ResourceType.id_for_container(),
        title: title,
        children: child_ids,
        author: author,
        content: %{"model" => [], "version" => "0.1.0"}
      ] ++ opts

    revision = insert(:revision, revision_attrs)

    insert(:project_resource, project_id: project.id, resource_id: resource.id)

    insert(:published_resource,
      publication: publication,
      resource: resource,
      revision: revision
    )

    node = %{resource: resource, revision: revision}
    {node, Map.put(acc, title, node)}
  end

  defp build_node(project, publication, author, {:container, title, children}, acc) do
    build_node(project, publication, author, {:container, title, children, []}, acc)
  end

  defp build_node(project, publication, author, {:container, title}, acc) do
    build_node(project, publication, author, {:container, title, [], []}, acc)
  end

  defp build_node(project, publication, author, {:page, title}, acc) do
    resource = insert(:resource)

    revision =
      insert(:revision,
        resource: resource,
        resource_type_id: ResourceType.id_for_page(),
        title: title,
        author: author,
        content: %{"model" => [], "version" => "0.1.0"}
      )

    insert(:project_resource, project_id: project.id, resource_id: resource.id)

    insert(:published_resource,
      publication: publication,
      resource: resource,
      revision: revision
    )

    node = %{resource: resource, revision: revision}
    {node, Map.put(acc, title, node)}
  end
end
