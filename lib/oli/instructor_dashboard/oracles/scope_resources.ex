defmodule Oli.InstructorDashboard.Oracles.ScopeResources do
  @moduledoc """
  Returns course title and scoped resources for the requested scope.
  """

  use Oli.Dashboard.Oracle

  alias Oli.Dashboard.OracleContext
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.InstructorDashboard.Oracles.Helpers
  alias Oli.Resources.ResourceType

  @impl true
  def key, do: :oracle_instructor_scope_resources

  @impl true
  def version, do: 1

  @impl true
  def load(%OracleContext{} = context, _opts) do
    with {:ok, section_id, scope} <- Helpers.section_scope(context) do
      section = Helpers.section(section_id)
      hierarchy = SectionResourceDepot.get_delivery_resolver_full_hierarchy(section)
      page_type_id = ResourceType.id_for_page()

      case scoped_node(hierarchy, scope.container_type, scope.container_id) do
        nil ->
          {:error, {:unknown_scope_container, scope.container_id}}

        node ->
          {:ok,
           %{
             course_title: section.title,
             items: build_items(node.children || [], [], section.customizations, page_type_id)
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

  defp build_items(children, ancestor_labels, customizations, page_type_id) do
    Enum.flat_map(children, fn child ->
      item = %{
        resource_id: child.resource_id,
        resource_type_id: child.revision.resource_type_id,
        title: child.revision.title,
        context_label: join_context_labels(ancestor_labels)
      }

      next_ancestor_labels =
        case child.revision.resource_type_id == page_type_id do
          true ->
            ancestor_labels

          false ->
            ancestor_labels ++ [container_label(child, customizations)]
        end

      [
        item
        | build_items(child.children || [], next_ancestor_labels, customizations, page_type_id)
      ]
    end)
  end

  defp container_label(child, customizations) do
    Sections.get_container_label_and_numbering(
      child.numbering.level || 0,
      child.numbering.index || 0,
      customizations
    )
  end

  defp join_context_labels([]), do: nil
  defp join_context_labels(labels), do: Enum.join(labels, " > ")
end
