defmodule OliWeb.Admin.Institutions.SectionsAndStudentsView do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  import OliWeb.DelegatedEvents

  alias OliWeb.InstitutionController
  alias Oli.Institutions
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.{PagedTable, Params, SessionContext, SearchInput, TextSearch}
  alias Oli.Delivery.Sections.{Browse, BrowseOptions}
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.Table.SortableTableModel

  @default_params %{
    offset: 0,
    limit: 1,
    sort_order: :asc,
    sort_by: :title,
    text_search: nil
  }

  def mount(
        %{"institution_id" => institution_id, "selected_tab" => selected_tab},
        session,
        socket
      ) do
    ctx = SessionContext.init(socket, session)
    institution = Oli.Institutions.get_institution!(institution_id)

    {:ok,
     assign(socket,
       title: institution.name,
       breadcrumbs:
         InstitutionController.root_breadcrumbs()
         |> InstitutionController.named(institution.name),
       institution: institution,
       selected_tab: String.to_existing_atom(selected_tab),
       ctx: ctx
     )}
  end

  def handle_params(%{"selected_tab" => "sections"} = params, _uri, socket) do
    decoded_params = decode_params(params)

    sections =
      Browse.browse_sections(
        %Paging{offset: decoded_params.offset, limit: decoded_params.limit},
        %Sorting{direction: decoded_params.sort_order, field: decoded_params.sort_by},
        %BrowseOptions{
          blueprint_id: nil,
          text_search: decoded_params.text_search,
          active_today: false,
          filter_status: nil,
          filter_type: nil,
          institution_id: socket.assigns.institution.id
        }
      )

    {:ok, table_model} = OliWeb.Sections.SectionsTableModel.new(socket.assigns.ctx, sections)
    table_model = SortableTableModel.update_from_params(table_model, params)

    {:noreply,
     assign(socket,
       table_model: table_model,
       total_count: determine_total(sections),
       selected_tab: :sections,
       params: decoded_params
     )}
  end

  def handle_params(%{"selected_tab" => "students"} = params, _uri, socket) do
    decoded_params = decode_params(params)

    students =
      Institutions.get_students_by_institution(
        socket.assigns.institution.id,
        params["text_search"],
        decoded_params.limit,
        decoded_params.offset
      )

    {:ok, table_model} = OliWeb.Users.UsersTableModel.new(students, socket.assigns.ctx)
    table_model = SortableTableModel.update_from_params(table_model, params)

    {:noreply,
     assign(socket,
       selected_tab: :students,
       params: decoded_params,
       table_model: table_model,
       total_count: determine_total(students) |> IO.inspect(label: "total_count!!")
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="container">
      <div class="flex flex-row justify-between items-center">
        <.tabs active_tab={@selected_tab} institution_id={@institution.id} />

        <form for="search" phx-change="text_search_change" class="w-44">
          <SearchInput.render id="search_input" name="value" text={@params.text_search} />
        </form>
      </div>
      <PagedTable.render
        __context__={assigns[:__context_]}
        total_count={@total_count}
        filter=""
        limit={@params.limit}
        offset={@params.offset}
        table_model={@table_model}
        allow_selection={false}
        sort="paged_table_sort"
        page_change="paged_table_page_change"
        selection_change=""
        show_top_paging={true}
        show_bottom_paging={false}
        additional_table_class="instructor_dashboard_table"
        render_top_info={false}
      />
    </div>
    """
  end

  defp is_active_tab?(tab, active_tab), do: tab == active_tab

  attr(:institution_id, :string, required: true)
  attr(:active_tab, :string, required: true)

  def tabs(assigns) do
    ~H"""
      <div class="container mx-auto my-4">
        <ul class="nav nav-tabs flex flex-col md:flex-row flex-wrap list-none border-b-0 pl-0 mb-4" id="tabs-tab"
          role="tablist">

        <%= for %{label: label, path: path, badge: badge, active: active} <- [
        %{
          label: "Sections",
          path:
            Routes.live_path(
              OliWeb.Endpoint,
              __MODULE__,
              @institution_id,
              :sections
            ),
          badge: nil,
          active: is_active_tab?(:sections, @active_tab)
        },
        %{
          label: "Students",
          path:
            Routes.live_path(
              OliWeb.Endpoint,
              __MODULE__,
              @institution_id,
              :students
            ),
          badge: nil,
          active: is_active_tab?(:students, @active_tab)
        }
      ] do %>
            <li class="nav-item" role="presentation">
              <.link patch={path}
                class={"
                  block
                  border-x-0 border-t-0 border-b-2
                  px-3
                  py-3
                  my-2
                  text-body-color
                  dark:text-body-color-dark
                  bg-transparent
                  hover:no-underline
                  hover:text-body-color
                  hover:border-delivery-primary-200
                  focus:border-delivery-primary-200
                  #{if active, do: "!border-delivery-primary active", else: "border-transparent"}
                "}>
                <%= if is_function(label), do: label.(), else: label %>
                  <%= if badge do %>
                  <span class="text-xs inline-block py-1 px-2 ml-2 leading-none text-center whitespace-nowrap align-baseline font-bold bg-delivery-primary text-white rounded"><%= badge %></span>
                  <% end %>
              </.link>
            </li>
          <% end %>
        </ul>
      </div>
    """
  end

  defp decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      sort_order:
        Params.get_atom_param(
          params,
          "sort_order",
          [:asc, :desc],
          @default_params.sort_order
        ),
      sort_by:
        Params.get_atom_param(
          params,
          "sort_by",
          [
            :title,
            :type,
            :enrollments_count,
            :requires_payment,
            :start_date,
            :end_date,
            :status,
            :base,
            :instructor,
            :institution
          ],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search)
    }
  end

  def handle_event(event, params, socket) do
    delegate_to(
      {event, params, socket, &__MODULE__.patch_with/2},
      [&TextSearch.handle_delegated/4, &PagedTable.handle_delegated/4]
    )
  end

  def patch_with(socket, changes) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           socket.assigns.institution.id,
           socket.assigns.selected_tab,
           Map.merge(
             %{
               sort_by: socket.assigns.table_model.sort_by_spec.name,
               sort_order: socket.assigns.table_model.sort_order,
               offset: socket.assigns.params.offset,
               text_search: socket.assigns.params.text_search
             },
             changes
           )
         ),
       replace: true
     )}
  end

  defp determine_total(rows) do
    case rows do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end
end
