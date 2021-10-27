defmodule OliWeb.Progress.StudentView do
  use Surface.LiveView
  alias OliWeb.Common.{Breadcrumb}

  alias OliWeb.Progress.StudentTabelModel
  alias OliWeb.Common.SortableTable.Table
  alias OliWeb.Sections.Mount

  data breadcrumbs, :any
  data title, :string, default: "Student Progress"
  data section, :any, default: nil
  data user, :any

  prop total_count, :integer, required: true
  prop filter, :string, required: true
  prop table_model, :struct, required: true
  prop sort, :event, default: "paged_table_sort"

  defp set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, _) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Student Progress"
        })
      ]
  end

  def mount(
        %{"section_slug" => section_slug, "user_id" => user_id},
        session,
        socket
      ) do
    case get_user(user_id) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {:ok, user} ->
        case Mount.for(section_slug, session) do
          {:error, e} ->
            Mount.handle_error(socket, {:error, e})

          {type, _, section} ->
            resource_accesses =
              Oli.Delivery.Attempts.Core.get_resource_accesses(
                section_slug,
                user_id
              )
              |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.resource_id, r) end)

            hierarchy = Oli.Publishing.DeliveryResolver.full_hierarchy(section.slug)

            page_nodes =
              hierarchy
              |> Oli.Delivery.Hierarchy.flatten()
              |> Enum.filter(fn node ->
                node.revision.resource_type_id ==
                  Oli.Resources.ResourceType.get_id_by_type("page")
              end)

            total_count = length(page_nodes)

            {:ok, table_model} =
              StudentTabelModel.new(page_nodes, resource_accesses, section, user)

            {:ok,
             assign(socket,
               table_model: table_model,
               total_count: total_count,
               page_nodes: page_nodes,
               resource_accesses: resource_accesses,
               breadcrumbs: set_breadcrumbs(type, section),
               section: section,
               user: user
             )}
        end
    end
  end

  defp get_user(user_id) do
    case Oli.Accounts.get_user!(user_id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  def render(assigns) do
    ~F"""
      <div>

        <Table model={@table_model} sort="do_sort"/>
      </div>
    """
  end
end
