defmodule OliWeb.Admin.ExternalTools.UsageView do
  use OliWeb, :live_view

  import Ecto.Query
  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Delivery.Sections
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{Breadcrumb, PagedTable}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Sections.SectionsTableModel
  alias Oli.Repo

  @limit 25
  @sort_by :base
  @sort_order :asc
  @default_options %Sections.BrowseOptions{
    institution_id: nil,
    blueprint_id: nil,
    project_id: nil,
    text_search: "",
    active_today: false,
    filter_status: nil,
    filter_type: nil
  }

  on_mount OliWeb.LiveSessionPlugs.SetCtx

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Manage LTI 1.3 External Tools",
          link: ~p"/admin/external_tools"
        })
      ] ++ [Breadcrumb.new(%{full_title: "Usage Count: Course Sections"})]
  end

  def mount(%{"platform_instance_id" => platform_instance_id}, _session, socket) do
    case PlatformExternalTools.get_platform_instance(platform_instance_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "The LTI Tool you are trying to view does not exist.")
         |> redirect(to: ~p"/admin/external_tools")}

      platform_instance ->
        sections =
          browse_sections(platform_instance_id, %Paging{offset: 0, limit: @limit}, %Sorting{
            direction: @sort_order,
            field: @sort_by
          })

        total_count = SortableTableModel.determine_total(sections)

        {:ok, table_model} = SectionsTableModel.new(socket.assigns.ctx, sections)

        {:ok,
         assign(socket,
           title: "Usage Count: Course Sections",
           breadcrumbs: set_breadcrumbs(),
           platform_instance_id: platform_instance.id,
           total_count: total_count,
           table_model: table_model,
           limit: @limit,
           options: @default_options
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <PagedTable.render
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        limit={@limit}
        offset={@offset}
      />
    </div>
    """
  end

  def handle_params(params, _, socket) do
    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)

    sections =
      browse_sections(
        socket.assigns.platform_instance_id,
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name}
      )

    table_model = Map.put(table_model, :rows, sections)
    total_count = SortableTableModel.determine_total(sections)

    {:noreply,
     assign(socket,
       offset: offset,
       table_model: table_model,
       total_count: total_count
     )}
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &PagedTable.handle_delegated/4
    ])
  end

  defp browse_sections(platform_instance_id, paging, sorting) do
    section_ids =
      platform_instance_id
      |> PlatformExternalTools.get_sections_with_lti_activities_for_platform_instance_id()
      |> Enum.map(fn section -> section.id end)

    Sections.Browse.browse_sections_query(paging, sorting, @default_options)
    |> where([s], s.id in ^section_ids)
    |> Repo.all()
  end

  def patch_with(socket, changes) do
    params = %{
      sort_by: socket.assigns.table_model.sort_by_spec.name,
      sort_order: socket.assigns.table_model.sort_order,
      offset: socket.assigns.offset
    }

    piid = socket.assigns.platform_instance_id

    {:noreply,
     push_patch(socket,
       to: ~p"/admin/external_tools/#{piid}/usage?#{Map.merge(params, changes)}",
       replace: true
     )}
  end
end
