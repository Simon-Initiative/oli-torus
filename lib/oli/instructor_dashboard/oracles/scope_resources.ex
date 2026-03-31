defmodule Oli.InstructorDashboard.Oracles.ScopeResources do
  @moduledoc """
  Returns course title and direct child resources for the requested scope.
  """

  use Oli.Dashboard.Oracle

  alias Oli.Dashboard.OracleContext
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.InstructorDashboard.Oracles.Helpers

  @impl true
  def key, do: :oracle_instructor_scope_resources

  @impl true
  def version, do: 2

  @impl true
  def load(%OracleContext{} = context, _opts) do
    with {:ok, section_id, scope} <- Helpers.section_scope(context) do
      section = Helpers.section(section_id)
      hierarchy = SectionResourceDepot.get_delivery_resolver_full_hierarchy(section)

      case scoped_node(hierarchy, scope.container_type, scope.container_id) do
        nil ->
          {:error, {:unknown_scope_container, scope.container_id}}

        node ->
          {:ok,
           %{
             course_title: section.title,
             scope_label: scope_label(scope.container_type, node),
             items: build_items(node.children || [])
           }}
      end
    end
  end

  defp scoped_node(hierarchy, :course, nil), do: hierarchy

  defp scoped_node(hierarchy, :container, container_id),
    do: find_by_resource_id(hierarchy, container_id)

  defp scoped_node(_hierarchy, _container_type, _container_id), do: nil

  defp find_by_resource_id(node, resource_id) do
    cond do
      node.resource_id == resource_id ->
        node

      true ->
        Enum.find_value(node.children || [], fn child ->
          find_by_resource_id(child, resource_id)
        end)
    end
  end

  defp scope_label(:course, _node), do: "Entire Course"
  defp scope_label(:container, node), do: node.revision.title
  defp scope_label(_container_type, _node), do: "Selected Scope"

  defp build_items(children) do
    Enum.map(children, fn child ->
      %{
        resource_id: child.resource_id,
        resource_type_id: child.revision.resource_type_id,
        title: child.revision.title
      }
    end)
  end
end
