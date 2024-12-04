defmodule OliWeb.Admin.Institutions.SectionsAndStudentsView do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, :live}

  import OliWeb.DelegatedEvents

  alias OliWeb.InstitutionController
  alias Oli.Institutions
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.{PagedTable, Params, SessionContext, SearchInput, TextSearch}
  alias Oli.Delivery.Sections.{Browse, BrowseOptions, Section}
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.Table.SortableTableModel
  alias Phoenix.LiveView.JS
  alias Oli.Repo

  @default_params %{
    offset: 0,
    limit: 10,
    sort_order: :asc,
    sort_by: :title,
    text_search: nil
  }

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def mount(
        %{"institution_id" => institution_id, "selected_tab" => selected_tab},
        session,
        socket
      ) do
    ctx = SessionContext.init(socket, session)

    institutions = Oli.Institutions.list_institutions()
    institution = Enum.find(institutions, fn i -> i.id == String.to_integer(institution_id) end)

    {:ok,
     assign(socket,
       title: institution.name,
       breadcrumbs:
         InstitutionController.root_breadcrumbs()
         |> InstitutionController.named(institution.name),
       institution: institution,
       institutions: institutions,
       selected_tab: String.to_existing_atom(selected_tab),
       ctx: ctx,
       modal_assigns: %{show: false}
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
          project_id: nil,
          text_search: decoded_params.text_search,
          active_today: false,
          filter_status: nil,
          filter_type: nil,
          institution_id: socket.assigns.institution.id
        }
      )

    {:ok, table_model} =
      OliWeb.Sections.SectionsTableModel.new(socket.assigns.ctx, sections, true)

    table_model =
      SortableTableModel.update_from_params(table_model, params)
      |> Map.put(:rows, sections)

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
       total_count: determine_total(students)
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="container">
      <.modal modal_assigns={@modal_assigns} />
      <h4 class="torus-h4 mb-2">
        <%= @institution.name %>
      </h4>
      <div class="flex flex-row justify-between items-center">
        <.tabs active_tab={@selected_tab} institution_id={@institution.id} />

        <form for="search" phx-change="text_search_change" class="w-44">
          <SearchInput.render id="search_input" name="value" text={@params.text_search} />
        </form>
      </div>
      <PagedTable.render
        total_count={@total_count}
        limit={@params.limit}
        offset={@params.offset}
        table_model={@table_model}
        sort="paged_table_sort"
        page_change="paged_table_page_change"
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
      <ul
        class="nav nav-tabs flex flex-col md:flex-row flex-wrap list-none border-b-0 pl-0 mb-4"
        id="tabs-tab"
        role="tablist"
      >
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
            <.link
              patch={path}
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
                "}
            >
              <%= if is_function(label), do: label.(), else: label %>
              <%= if badge do %>
                <span class="text-xs inline-block py-1 px-2 ml-2 leading-none text-center whitespace-nowrap align-baseline font-bold bg-delivery-primary text-white rounded">
                  <%= badge %>
                </span>
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

  def handle_event("edit_section", %{"value" => section_id}, socket) do
    changeset =
      socket.assigns.table_model.rows
      |> Enum.find(&(&1.id == String.to_integer(section_id)))
      |> Section.changeset()

    options_for_select =
      Enum.map(socket.assigns.institutions, fn i -> {i.name, i.id} end)
      |> Enum.sort_by(fn {name, _id} -> name end)

    {:noreply,
     assign(socket,
       modal_assigns: %{
         show: "edit_institution_for_section",
         changeset: changeset,
         options_for_select: options_for_select
       }
     )}
  end

  def handle_event("submit_modal", %{"institution_id" => institution_id}, socket) do
    socket.assigns.modal_assigns.changeset
    |> Section.changeset(%{institution_id: String.to_integer(institution_id)})
    |> Repo.update()
    |> case do
      {:ok, _section} ->
        socket
        |> assign(modal_assigns: %{show: false})
        |> put_flash(:info, "Institution updated")
        |> patch_with(%{})

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(modal_assigns: %{show: false})
         |> put_flash(:error, "Institution could not be updated")}
    end
  end

  def handle_event("hide_modal", _params, socket) do
    {:noreply, assign(socket, modal_assigns: %{show: false})}
  end

  def handle_event(event, params, socket) do
    delegate_to(
      {event, params, socket, &__MODULE__.patch_with/2},
      [&TextSearch.handle_delegated/4, &PagedTable.handle_delegated/4]
    )
  end

  def modal(%{modal_assigns: %{show: false}} = assigns),
    do: ~H"""
    """

  def modal(%{modal_assigns: %{show: "edit_institution_for_section"}} = assigns) do
    ~H"""
    <div
      id="edit_institution_for_section_modal"
      class="modal fade show bg-gray-900 bg-opacity-50"
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      style="display: block;"
      phx-window-keydown={JS.dispatch("click", to: "#modal_cancel_button")}
      phx-key="Escape"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              Assign institution for <%= @modal_assigns.changeset.data.title %>
            </h5>
            <button
              type="button"
              class="btn-close box-content w-4 h-4 p-1 border-none rounded-none opacity-50 focus:shadow-none focus:outline-none focus:opacity-100 hover:opacity-75 hover:no-underline"
              aria-label="Close"
              phx-click={JS.dispatch("click", to: "#modal_cancel_button")}
            >
              <i class="fa-solid fa-xmark fa-xl" />
            </button>
          </div>
          <div class="modal-body">
            <.form for={@modal_assigns.changeset} phx-submit="submit_modal">
              <div class="flex flex-col space-y-2">
                <div class="flex flex-col space-y-1">
                  <label
                    for="institution_id"
                    class="text-sm font-medium text-gray-700 dark:text-gray-300"
                  >
                    Institution
                  </label>
                  <select
                    id="institution_id"
                    name="institution_id"
                    class="form-select block w-full mt-1"
                  >
                    <%= for {label, value} <- @modal_assigns.options_for_select do %>
                      <option
                        value={value}
                        selected={value == @modal_assigns.changeset.data.institution_id}
                      >
                        <%= label %>
                      </option>
                    <% end %>
                  </select>
                </div>
              </div>
              <div class="flex space-x-3 mt-6 justify-end">
                <button
                  type="button"
                  id="modal_cancel_button"
                  class="btn btn-link"
                  phx-click="hide_modal"
                >
                  Cancel
                </button>

                <button type="submit" class="btn btn-primary">Save</button>
              </div>
            </.form>
          </div>
        </div>
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
