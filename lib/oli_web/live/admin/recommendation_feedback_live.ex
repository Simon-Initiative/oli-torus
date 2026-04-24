defmodule OliWeb.Admin.RecommendationFeedbackLive do
  use OliWeb, :live_view

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.InstructorDashboard.Recommendations
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Admin.RecommendationFeedback.TableModel
  alias OliWeb.Common.{Breadcrumb, PagingParams, StripedPagedTable}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes

  @limit 20

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb()
    |> breadcrumb()
  end

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "AI Custom Feedback",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  def mount(_, _session, socket) do
    feedback =
      Recommendations.browse_custom_feedback(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :desc, field: :inserted_at}
      )

    total_count = SortableTableModel.determine_total(feedback)
    {:ok, table_model} = TableModel.new(feedback, socket.assigns.ctx)

    {:ok,
     assign(socket,
       title: "AI Custom Feedback",
       breadcrumbs: set_breadcrumbs(),
       table_model: table_model,
       total_count: total_count,
       offset: 0,
       limit: @limit
     )}
  end

  def handle_params(params, _, socket) do
    table_model = SortableTableModel.update_from_params(socket.assigns.table_model, params)
    offset = get_int_param(params, "offset", 0)
    limit = get_int_param(params, "limit", @limit)

    feedback =
      Recommendations.browse_custom_feedback(
        %Paging{offset: offset, limit: limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name}
      )

    table_model = Map.put(table_model, :rows, feedback)
    total_count = SortableTableModel.determine_total(feedback)

    {:noreply,
     assign(socket,
       table_model: table_model,
       total_count: total_count,
       offset: offset,
       limit: limit
     )}
  end

  attr(:table_model, :map)
  attr(:total_count, :integer, default: 0)
  attr(:offset, :integer, default: 0)
  attr(:limit, :integer, default: @limit)

  def render(assigns) do
    ~H"""
    <div>
      <div class="flex flex-row justify-between items-center px-4">
        <span class="text-2xl font-bold text-[#353740] dark:text-[#EEEBF5] leading-loose">
          AI Custom Feedback
        </span>
      </div>

      <div class="mt-4">
        <StripedPagedTable.render
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
          render_top_info={false}
          additional_table_class="instructor_dashboard_table"
          sort="paged_table_sort"
          page_change="paged_table_page_change"
          limit_change="paged_table_limit_change"
          show_limit_change={true}
          sticky_header_offset={64}
        />
      </div>
    </div>
    """
  end

  def patch_with(socket, changes) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           Map.merge(
             %{
               sort_by: socket.assigns.table_model.sort_by_spec.name,
               sort_order: socket.assigns.table_model.sort_order,
               offset: socket.assigns.offset,
               limit: socket.assigns.limit
             },
             changes
           )
         ),
       replace: true
     )}
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by_str}, socket) do
    current_sort_by = socket.assigns.table_model.sort_by_spec.name
    current_sort_order = socket.assigns.table_model.sort_order
    new_sort_by = String.to_existing_atom(sort_by_str)

    sort_order =
      if new_sort_by == current_sort_by, do: toggle_sort_order(current_sort_order), else: :asc

    patch_with(socket, %{sort_by: new_sort_by, sort_order: sort_order})
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    patch_with(socket, %{limit: limit, offset: offset})
  end

  def handle_event("paged_table_limit_change", params, socket) do
    new_limit = get_int_param(params, "limit", @limit)

    new_offset =
      PagingParams.calculate_new_offset(
        socket.assigns.offset,
        new_limit,
        socket.assigns.total_count
      )

    patch_with(socket, %{limit: new_limit, offset: new_offset})
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([&StripedPagedTable.handle_delegated/4])
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(_), do: :asc
end
