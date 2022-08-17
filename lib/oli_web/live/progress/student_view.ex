defmodule OliWeb.Progress.StudentView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  import OliWeb.Common.Utils
  import OliWeb.Common.Params

  alias OliWeb.Common.{Breadcrumb}
  alias OliWeb.Common.TextSearch
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Progress.StudentTabelModel
  alias OliWeb.Common.SortableTable.Table
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.SessionContext
  alias OliWeb.Router.Helpers, as: Routes

  data breadcrumbs, :any
  data title, :string, default: "Student Progress"
  data section, :any, default: nil
  data user, :any
  data text_search, :string
  data table_model, :struct
  data resource_accesses, :map
  data page_nodes, :list

  def set_breadcrumbs(type, section, user_id) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section, user_id)
  end

  def breadcrumb(previous, section, user_id) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Student Progress",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug, user_id)
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
        context = SessionContext.init(session)

        case Mount.for(section_slug, session) do
          {:error, e} ->
            Mount.handle_error(socket, {:error, e})

          {type, _, section} ->
            resource_accesses =
              Oli.Delivery.Attempts.Core.get_resource_accesses(
                section_slug,
                user_id
              )
              |> Enum.reduce(%{}, fn r, m ->
                # limit score decimals to two significant figures, rounding up
                r =
                  case r.score do
                    nil -> r
                    _ -> Map.put(r, :score, format_score(r.score))
                  end

                Map.put(m, r.resource_id, r)
              end)

            hierarchy = Oli.Publishing.DeliveryResolver.full_hierarchy(section.slug)

            page_nodes =
              hierarchy
              |> Oli.Delivery.Hierarchy.flatten()
              |> Enum.filter(fn node ->
                node.revision.resource_type_id ==
                  Oli.Resources.ResourceType.get_id_by_type("page")
              end)

            {:ok, table_model} =
              StudentTabelModel.new(page_nodes, resource_accesses, section, user, context)

            {:ok,
             assign(socket,
               context: context,
               text_search: "",
               table_model: table_model,
               page_nodes: page_nodes,
               resource_accesses: resource_accesses,
               breadcrumbs: set_breadcrumbs(type, section, user_id),
               delivery_breadcrumb: true,
               section: section,
               user: user
             )}
        end
    end
  end

  def handle_params(params, _, socket) do
    text_search = get_param(params, "text_search", "")

    filtered_page_nodes =
      Enum.filter(socket.assigns.page_nodes, fn node ->
        case text_search do
          nil -> true
          "" -> true
          _ -> String.contains?(node.revision.title, text_search)
        end
      end)

    {:ok, table_model} =
      StudentTabelModel.new(
        filtered_page_nodes,
        socket.assigns.resource_accesses,
        socket.assigns.section,
        socket.assigns.user,
        socket.assigns.context
      )

    # Updating from params is what will apply the sort
    table_model =
      SortableTableModel.update_from_params(
        table_model,
        params
      )

    {:noreply,
     assign(socket,
       table_model: table_model,
       text_search: text_search
     )}
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
        <h3>Progress Details for {name(@user)}</h3>
        <TextSearch id="text_search" text={@text_search}/>
        <div class="mt-4"/>
        <Table model={@table_model} sort="do_sort"/>
      </div>
    """
  end

  def handle_event("text_search_change", %{"value" => value}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           socket.assigns.section.slug,
           socket.assigns.user.id,
           %{
             sort_by: socket.assigns.table_model.sort_by_spec.name,
             sort_order: socket.assigns.table_model.sort_order,
             text_search: value
           }
         )
     )}
  end

  def handle_event("text_search_reset", _, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           socket.assigns.section.slug,
           socket.assigns.user.id,
           %{
             sort_by: socket.assigns.table_model.sort_by_spec.name,
             sort_order: socket.assigns.table_model.sort_order,
             text_search: nil
           }
         )
     )}
  end

  def handle_event("do_sort", %{"sort_by" => name}, socket) do
    sort_order =
      case Atom.to_string(socket.assigns.table_model.sort_by_spec.name) do
        ^name ->
          case socket.assigns.table_model.sort_order do
            :asc -> :desc
            _ -> :asc
          end

        _ ->
          socket.assigns.table_model.sort_order
      end

    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           socket.assigns.section.slug,
           socket.assigns.user.id,
           %{
             sort_by: name,
             sort_order: sort_order,
             text_search: socket.assigns.text_search
           }
         )
     )}
  end
end
