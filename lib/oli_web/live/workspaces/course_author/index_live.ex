defmodule OliWeb.Workspaces.CourseAuthor.IndexLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Institutions
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Tags
  alias OliWeb.Admin.BrowseFilters
  alias OliWeb.Backgrounds
  alias OliWeb.Common.{Params, SearchInput, StripedPagedTable}
  alias OliWeb.Components.FilterPanel
  alias OliWeb.Icons
  alias OliWeb.Projects.CreateProjectModal
  alias OliWeb.Projects.TableModel

  @limit 20
  @min_search_length 3
  @visibility_options [
    {:global, "Open"},
    {:selected, "Restricted"},
    {:authors, "Author Only"}
  ]
  @status_options [
    {:active, "Active"},
    {:deleted, "Deleted"}
  ]
  @published_options [
    {true, "Yes"},
    {false, "No"}
  ]
  @date_field_options [{"inserted_at", "Created Date"}]
  @filter_fields [:date, :tags, :visibility, :published, :status, :institution]
  @projects_table_dom_id "course-author-projects-table"

  @impl Phoenix.LiveView
  def mount(_params, _session, %{assigns: %{ctx: %{author: nil}}} = socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "author")

    authentication_providers =
      Oli.AssentAuth.AuthorAssentAuth.authentication_providers() |> Keyword.keys()

    {:ok,
     assign(socket,
       current_author: nil,
       active_workspace: :course_author,
       footer_enabled?: false,
       form: form,
       authentication_providers: authentication_providers
     )}
  end

  def mount(_params, _session, %{assigns: %{ctx: %{author: %Author{} = author} = ctx}} = socket) do
    is_admin = Accounts.has_admin_role?(author, :content_admin)

    show_all =
      if is_admin,
        do: Accounts.get_author_preference(author, :admin_show_all_projects, true),
        else: true

    show_deleted = Accounts.get_author_preference(author, :admin_show_deleted_projects, false)

    filters = BrowseFilters.default()
    course_filters = BrowseFilters.to_course_filters(filters)
    institutions = Institutions.list_institutions()
    applied_search = sanitize_search_term("")

    projects =
      Course.browse_projects(
        author,
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :desc, field: :inserted_at},
        include_deleted: show_deleted,
        admin_show_all: show_all,
        text_search: applied_search,
        filters: course_filters
      )

    {:ok, table_model} =
      TableModel.new(ctx, projects,
        sort_by_spec: :inserted_at,
        sort_order: :desc,
        search_term: applied_search,
        is_admin: is_admin,
        table_dom_id: @projects_table_dom_id
      )

    total_count = determine_total(projects)
    export_filename = "projects-" <> Date.to_iso8601(Date.utc_today()) <> ".csv"

    {:ok,
     assign(socket,
       ctx: ctx,
       author: author,
       projects: projects,
       table_model: table_model,
       total_count: total_count,
       is_admin: is_admin,
       show_all: show_all,
       show_deleted: show_deleted,
       active_workspace: :course_author,
       text_search: "",
       sort_by: :inserted_at,
       sort_order: :desc,
       offset: 0,
       limit: @limit,
       filters: filters,
       filter_panel_open: false,
       filter_active_count: BrowseFilters.active_count(filters),
       tag_search: "",
       tag_suggestions: [],
       visibility_options: @visibility_options,
       status_options: @status_options,
       published_options: @published_options,
       institution_options: institutions,
       date_field_options: @date_field_options,
       export_filename: export_filename,
       filter_fields: @filter_fields
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _session, %{assigns: %{ctx: %{author: nil}}} = socket),
    do: {:noreply, socket}

  def handle_params(params, _, socket) do
    %{
      is_admin: is_admin,
      show_all: show_all,
      show_deleted: show_deleted,
      author: author,
      ctx: ctx,
      sort_by: current_sort_by,
      sort_order: current_sort_order,
      offset: current_offset,
      limit: current_limit
    } = socket.assigns

    filters_state = BrowseFilters.parse(params)
    course_filters = BrowseFilters.to_course_filters(filters_state)

    {show_all, author} =
      case get_boolean_param(params, "show_all", show_all) do
        new_value when new_value != show_all and is_admin ->
          {:ok, author} =
            Accounts.set_author_preference(author, :admin_show_all_projects, new_value)

          {new_value, author}

        old_value ->
          {old_value, author}
      end

    {show_deleted, author} =
      case get_boolean_param(params, "show_deleted", show_deleted) do
        new_value when new_value != show_deleted ->
          {:ok, author} =
            Accounts.set_author_preference(author, :admin_show_deleted_projects, new_value)

          {new_value, author}

        old_value ->
          {old_value, author}
      end

    sort_by = resolve_sort_by(params, socket.assigns.table_model.column_specs, current_sort_by)

    sort_order =
      case Map.get(params, "sort_order") do
        "asc" -> :asc
        "desc" -> :desc
        _ -> current_sort_order
      end

    offset = Params.get_int_param(params, "offset", current_offset)
    limit = Params.get_int_param(params, "limit", current_limit)
    raw_search = Params.get_param(params, "text_search", socket.assigns.text_search)
    applied_search = sanitize_search_term(raw_search)

    projects =
      Course.browse_projects(
        author,
        %Paging{offset: offset, limit: limit},
        %Sorting{direction: sort_order, field: sort_by},
        include_deleted: show_deleted,
        admin_show_all: show_all,
        text_search: applied_search,
        filters: course_filters
      )

    {:ok, table_model} =
      TableModel.new(ctx, projects,
        sort_by_spec: sort_by,
        sort_order: sort_order,
        search_term: applied_search,
        is_admin: is_admin,
        table_dom_id: @projects_table_dom_id
      )

    total_count = determine_total(projects)

    {:noreply,
     assign(socket,
       author: author,
       projects: projects,
       table_model: table_model,
       total_count: total_count,
       show_deleted: show_deleted,
       show_all: show_all,
       text_search: raw_search,
       sort_by: sort_by,
       sort_order: sort_order,
       offset: offset,
       limit: limit,
       filters: filters_state,
       filter_active_count: BrowseFilters.active_count(filters_state),
       tag_search: socket.assigns.tag_search,
       tag_suggestions: socket.assigns.tag_suggestions,
       filter_panel_open: socket.assigns.filter_panel_open,
       filter_fields: socket.assigns.filter_fields
     )}
  end

  defp determine_total(projects) do
    case(projects) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  attr(:author, :any)
  attr(:is_admin, :boolean, default: false)
  attr(:total_count, :integer, default: 0)
  attr(:show_all, :boolean, default: true)
  attr(:show_deleted, :boolean, default: false)
  attr(:params, :map, default: %{})

  @impl Phoenix.LiveView

  def render(%{current_author: nil} = assigns) do
    ~H"""
    <div class="flex-1 flex justify-center items-center min-h-screen">
      <div class="absolute h-full w-full top-0 left-0">
        <Backgrounds.course_author_workspace_sign_in />
      </div>
      <div class="z-20 flex justify-center gap-2 lg:gap-12 xl:gap-32 px-6 sm:px-0">
        <div class="w-1/4 lg:w-1/2 flex items-start justify-center">
          <div class="w-96 flex-col justify-start items-start gap-0 lg:gap-3.5 inline-flex">
            <div class="text-left lg:text-3xl xl:text-4xl">
              <span class="text-white font-normal font-['Open Sans'] leading-10">
                Welcome to
              </span>
              <span class="text-white font-bold font-['Open Sans'] leading-10">
                {Oli.VendorProperties.product_short_name()}
              </span>
            </div>
            <div class="w-48 h-11 justify-start items-center gap-1 inline-flex">
              <div class="justify-start items-center gap-2 lg:gap-px flex">
                <div class="grow shrink basis-0 self-start px-1 py-2 justify-center items-center flex">
                  <OliWeb.Icons.writing_pencil
                    class="w-7 h-6 lg:w-[36px] lg:h-[36px]"
                    stroke_class="stroke-white"
                  />
                </div>
                <div class="w-40 lg:text-center text-white lg:text-3xl xl:text-4xl font-bold font-['Open Sans'] whitespace-nowrap">
                  Course Author
                </div>
              </div>
            </div>
            <div class="lg:mt-6 text-white lg:text-lg xl:text-xl font-normal leading-normal">
              Create, deliver, and continuously improve course materials.
            </div>
          </div>
        </div>
        <div class="lg:w-1/2 flex items-center justify-center dark">
          <Components.Auth.login_form
            title="Course Author Sign In"
            form={@form}
            action={~p"/authors/log_in"}
            registration_link={~p"/authors/register"}
            reset_password_link={~p"/authors/reset_password"}
            authentication_providers={@authentication_providers}
            auth_provider_path_fn={&~p"/authors/auth/#{&1}/new"}
          />
        </div>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    {render_modal(assigns)}
    <div class="flex-1 flex flex-col">
      <div class="relative flex items-center h-[247px]">
        <div class="absolute top-0 h-full w-full">
          <Backgrounds.course_author_header />
        </div>
        <div class="flex-col justify-start items-start gap-[15px] z-10 px-[63px] font-['Open Sans']">
          <div class="flex flex-row items-center gap-3">
            <Icons.pencil_writing class="stroke-black dark:stroke-white" />
            <h1 class="text-[#353740] dark:text-white text-[32px] font-bold leading-normal">
              Course Author
            </h1>
          </div>
          <h2 class="text-[#353740] dark:text-white text-base font-normal leading-normal">
            Create, deliver, and continuously improve course materials.
          </h2>
        </div>
      </div>

      <div class="flex flex-col items-start mt-[40px] gap-9 py-[60px] px-[63px]">
        <div class="flex flex-col gap-4 w-full">
          <h3 class="dark:text-violet-100 text-xl font-bold font-['Open Sans'] leading-normal whitespace-nowrap">
            Projects
          </h3>
          <div class="dark:text-violet-100 text-base font-normal font-['Inter'] leading-normal">
            <div class="mx-auto">
              <div class="projects-title-row mb-4">
                <div class="d-flex justify-content-between align-items-baseline">
                  <div class="flex flex-row">
                    <%= if @is_admin do %>
                      <div class="flex items-center gap-x-2 form-check">
                        <input
                          type="checkbox"
                          class="form-check-input"
                          id="allCheck"
                          checked={@show_all}
                          phx-click="toggle_show_all"
                        />
                        <label class="dark:text-[#eeebf5] text-base font-normal font-['Roboto'] mt-1">
                          Show all projects
                        </label>
                      </div>
                    <% end %>
                    <div class={"flex items-center gap-x-2 form-check #{if @is_admin, do: "ml-4", else: ""}"}>
                      <input
                        type="checkbox"
                        class="form-check-input"
                        id="deletedCheck"
                        checked={@show_deleted}
                        phx-click="toggle_show_deleted"
                      />
                      <label class="dark:text-[#eeebf5] text-base font-normal font-['Roboto'] mt-1">
                        Show deleted projects
                      </label>
                    </div>
                  </div>

                  <div class="flex-grow-1"></div>
                </div>
              </div>

              <div class="container mx-0 mb-12">
                <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
                  <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:gap-6">
                    <.form for={%{}} phx-change="text_search_change" class="w-full lg:w-72">
                      <SearchInput.render id="text-search" name="project_name" text={@text_search} />
                    </.form>

                    <FilterPanel.render
                      id="projects-filter-panel"
                      filters={Map.from_struct(@filters)}
                      fields={@filter_fields}
                      open={@filter_panel_open}
                      active_count={@filter_active_count}
                      toggle_event="toggle_filters"
                      close_event="close_filters"
                      cancel_event="cancel_filters"
                      clear_event="clear_all_filters"
                      apply_event="apply_filters"
                      visibility_options={@visibility_options}
                      status_options={@status_options}
                      published_options={@published_options}
                      institution_options={@institution_options}
                      date_field_options={@date_field_options}
                      tag_search={@tag_search}
                      tag_suggestions={@tag_suggestions}
                      tag_search_event="filter_tag_search"
                      tag_add_event="filter_add_tag"
                      tag_remove_event="filter_remove_tag"
                    />
                  </div>

                  <div class="flex items-center gap-3 self-start">
                    <a
                      role="button"
                      class="group inline-flex items-center gap-1 text-sm text-Text-text-button font-bold leading-none hover:text-Text-text-button-hover"
                      href={~p"/workspaces/course_author/projects/export?#{current_params(assigns)}"}
                      download={@export_filename}
                    >
                      Download CSV
                      <Icons.download stroke_class="group-hover:stroke-Text-text-button-hover stroke-Text-text-button" />
                    </a>

                    <button
                      id="button-new-project"
                      phx-click="show_create_project_modal"
                      class={[
                        "h-12 px-5 py-3 hover:no-underline rounded-md justify-center items-center gap-2 inline-flex bg-[#0080FF] hover:bg-[#0075EB] dark:bg-[#0062F2] dark:hover:bg-[#0D70FF]"
                      ]}
                    >
                      <div class="w-3 h-5 relative">
                        <Icons.plus
                          class="w-5 h-5 left-[-8px] top-0 absolute"
                          path_class="stroke-white"
                        />
                      </div>
                      <div class="text-white text-base font-normal font-['Inter'] leading-normal whitespace-nowrap">
                        New Project
                      </div>
                    </button>
                  </div>
                </div>
              </div>

              <div class="grid grid-cols-12">
                <div id="projects-table" class="col-span-12">
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
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :ctx, OliWeb.Common.SessionContext

  # when a user has already a linked author account the "Create Account" link should not be shown
  def create_authoring_account_link(%{ctx: %{user: %{author_id: author_id}}} = assigns)
      when not is_nil(author_id) do
    ~H"""
    """
  end

  def create_authoring_account_link(assigns) do
    ~H"""
    <div class="w-[341px] h-[0px] border border-white"></div>
    <.link
      href={create_authoring_account_path(@ctx.user)}
      class="text-center text-[#4ca6ff] text-xl font-bold font-['Open Sans'] leading-7"
    >
      Create Account
    </.link>
    """
  end

  defp create_authoring_account_path(nil),
    do: ~p"/authors/register?#{[request_path: ~p"/workspaces/course_author"]}"

  defp create_authoring_account_path(_user),
    do:
      ~p"/authors/register?#{[link_to_user_account?: "true", request_path: ~p"/workspaces/course_author"]}"

  def handle_event("toggle_filters", _, socket) do
    {:noreply, assign(socket, filter_panel_open: !socket.assigns.filter_panel_open)}
  end

  def handle_event("close_filters", _, socket) do
    {:noreply, assign(socket, filter_panel_open: false)}
  end

  def handle_event("cancel_filters", _, socket) do
    {:noreply, assign(socket, filter_panel_open: false, tag_suggestions: [], tag_search: "")}
  end

  def handle_event("toggle_show_all", _, socket) do
    patch_with(socket, %{show_all: !socket.assigns.show_all, offset: 0})
  end

  def handle_event("toggle_show_deleted", _, socket) do
    patch_with(socket, %{show_deleted: !socket.assigns.show_deleted, offset: 0})
  end

  def handle_event("filter_tag_search", %{"value" => value}, socket) do
    term = value || ""
    trimmed = String.trim(term)

    suggestions =
      if trimmed == "" do
        []
      else
        Tags.list_tags(%{search: trimmed, limit: 8})
        |> Enum.map(&%{id: &1.id, name: &1.name})
      end

    {:noreply, assign(socket, tag_search: term, tag_suggestions: suggestions)}
  end

  def handle_event("filter_add_tag", %{"id" => id_str} = params, socket) do
    with {:ok, id} <- parse_positive_int(id_str),
         {:ok, tag} <- fetch_tag_from_params(params, id) do
      filters = BrowseFilters.add_tag(socket.assigns.filters, tag)
      suggestions = Enum.reject(socket.assigns.tag_suggestions, &(&1.id == id))

      {:noreply,
       assign(socket,
         filters: filters,
         filter_active_count: BrowseFilters.active_count(filters),
         tag_search: "",
         tag_suggestions: suggestions
       )}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("filter_remove_tag", %{"id" => id_str}, socket) do
    with {:ok, id} <- parse_positive_int(id_str) do
      filters = BrowseFilters.remove_tag(socket.assigns.filters, id)

      {:noreply,
       assign(socket,
         filters: filters,
         filter_active_count: BrowseFilters.active_count(filters)
       )}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("apply_filters", %{"filters" => filters_params}, socket) do
    normalized = BrowseFilters.normalize_form_params(filters_params)
    filters = BrowseFilters.parse(normalized)
    filter_params = BrowseFilters.to_query_params(filters, as: :atoms)

    socket =
      assign(socket,
        filters: filters,
        filter_active_count: BrowseFilters.active_count(filters),
        filter_panel_open: false,
        tag_search: "",
        tag_suggestions: []
      )

    patch_with(socket, Map.merge(filter_params, %{offset: 0}))
  end

  def handle_event("apply_filters", _params, socket) do
    handle_event("apply_filters", %{"filters" => %{}}, socket)
  end

  def handle_event("clear_all_filters", _params, socket) do
    filters = BrowseFilters.default()

    socket =
      assign(socket,
        filters: filters,
        filter_active_count: 0,
        filter_panel_open: false,
        tag_search: "",
        tag_suggestions: []
      )

    patch_with(socket, %{offset: 0})
  end

  def handle_event("show_create_project_modal", _, socket) do
    modal_assigns = %{
      id: "create_project",
      changeset: Project.new_project_changeset(%Project{title: ""})
    }

    modal = fn assigns ->
      ~H"""
      <CreateProjectModal.render {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate_project", %{"project" => %{"title" => _title}}, socket) do
    {:noreply, socket}
  end

  def handle_event("text_search_change", %{"project_name" => project_name}, socket) do
    patch_with(socket, %{text_search: String.trim(project_name), offset: 0})
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by_str}, socket) do
    new_sort_by =
      resolve_sort_by(
        %{"sort_by" => sort_by_str},
        socket.assigns.table_model.column_specs,
        socket.assigns.sort_by
      )

    sort_order =
      if new_sort_by == socket.assigns.sort_by,
        do: toggle_sort_order(socket.assigns.sort_order),
        else: :asc

    patch_with(socket, %{sort_by: new_sort_by, sort_order: sort_order, offset: 0})
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    patch_with(socket, %{limit: String.to_integer(limit), offset: String.to_integer(offset)})
  end

  def handle_event("paged_table_limit_change", %{"limit" => limit}, socket) do
    new_limit = String.to_integer(limit)

    new_offset =
      OliWeb.Common.PagingParams.calculate_new_offset(
        socket.assigns.offset,
        new_limit,
        socket.assigns.total_count
      )

    patch_with(socket, %{limit: new_limit, offset: new_offset})
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &StripedPagedTable.handle_delegated/4
    ])
  end

  def patch_with(socket, changes) do
    params =
      socket.assigns
      |> current_params()
      |> Map.merge(changes)

    {:noreply, push_patch(socket, to: ~p"/workspaces/course_author?#{params}", replace: true)}
  end

  defp current_params(assigns) do
    base = %{
      sort_by: assigns.sort_by,
      sort_order: assigns.sort_order,
      offset: assigns.offset,
      limit: assigns.limit,
      text_search: assigns.text_search,
      show_deleted: assigns.show_deleted,
      show_all: assigns.show_all
    }

    filter_params =
      assigns.filters
      |> BrowseFilters.to_query_params(as: :atoms)

    Map.merge(base, filter_params)
  end

  defp resolve_sort_by(params, column_specs, default) do
    case Map.get(params, "sort_by") do
      nil ->
        default

      value when is_atom(value) ->
        if Enum.any?(column_specs, &(&1.name == value)), do: value, else: default

      value when is_binary(value) ->
        try do
          atom = String.to_existing_atom(value)

          if Enum.any?(column_specs, &(&1.name == atom)), do: atom, else: default
        rescue
          ArgumentError -> default
        end
    end
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(_), do: :asc

  defp sanitize_search_term(nil), do: ""

  defp sanitize_search_term(search) when is_binary(search) do
    trimmed = String.trim(search)

    cond do
      trimmed == "" -> ""
      String.length(trimmed) < @min_search_length -> ""
      true -> trimmed
    end
  end

  defp parse_positive_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= 0 -> {:ok, int}
      _ -> :error
    end
  end

  defp parse_positive_int(value) when is_integer(value) and value >= 0, do: {:ok, value}
  defp parse_positive_int(_), do: :error

  defp fetch_tag_from_params(%{"name" => name}, id) when is_binary(name) and name != "" do
    {:ok, %{id: id, name: name}}
  end

  defp fetch_tag_from_params(_params, id) do
    case Tags.list_tags_by_ids([id]) do
      [tag] -> {:ok, %{id: tag.id, name: tag.name}}
      _ -> :error
    end
  end
end
