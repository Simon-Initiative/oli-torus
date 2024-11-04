defmodule OliWeb.Workspaces.CourseAuthor.IndexLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Backgrounds
  alias OliWeb.Common.{PagedTable, Params, TextSearch}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Icons
  alias OliWeb.Projects.CreateProjectModal
  alias OliWeb.Workspaces.CourseAuthor.OverviewTableModel

  @default_params %{
    sidebar_expanded: true,
    offset: 0,
    limit: 25,
    text_search: "",
    direction: :asc,
    field: :title
  }

  @impl Phoenix.LiveView
  def mount(_params, _session, %{assigns: %{ctx: %{author: nil}}} = socket) do
    app_conf = %{phoenix_router: OliWeb.Router, phoenix_endpoint: OliWeb.Endpoint, otp_app: :oli}
    secret_key_base = Application.get_env(:oli, OliWeb.Endpoint)[:secret_key_base]

    provider_links =
      %Plug.Conn{}
      |> Map.replace(:private, app_conf)
      |> Map.replace(:secret_key_base, secret_key_base)
      |> OliWeb.Pow.PowHelpers.use_pow_config(:author)
      |> OliWeb.Pow.PowHelpers.provider_links()

    {:ok,
     assign(socket,
       current_author: nil,
       active_workspace: :course_author,
       header_enabled?: false,
       footer_enabled?: false,
       provider_links: provider_links
     )}
  end

  def mount(params, _session, %{assigns: %{ctx: %{author: %Author{} = author} = ctx}} = socket) do
    is_admin = Accounts.has_admin_role?(author)

    show_all =
      if is_admin,
        do: Accounts.get_author_preference(author, :admin_show_all_projects, true),
        else: true

    show_deleted = Accounts.get_author_preference(author, :admin_show_deleted_projects, false)

    params = decode_params(params)

    projects =
      Course.browse_projects(
        author,
        %Paging{offset: params.offset, limit: params.limit},
        %Sorting{direction: params.direction, field: params.field},
        include_deleted: show_deleted,
        admin_show_all: show_all
      )

    {:ok, table_model} = OverviewTableModel.new(ctx, projects)

    total_count = determine_total(projects)

    {:ok,
     assign(
       socket,
       ctx: ctx,
       author: author,
       projects: projects,
       table_model: table_model,
       total_count: total_count,
       is_admin: is_admin,
       show_all: show_all,
       show_deleted: show_deleted,
       active_workspace: :course_author,
       params: params
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
      table_model: table_model
    } =
      socket.assigns

    table_model = SortableTableModel.update_from_params(table_model, params)

    # if author is an admin, get the show_all value and update if its changed
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

    params = decode_params(params)

    projects =
      Course.browse_projects(
        author,
        %Paging{offset: params[:offset], limit: params[:limit]},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        include_deleted: show_deleted,
        admin_show_all: show_all,
        text_search: params[:text_search]
      )

    table_model = Map.put(table_model, :rows, projects)

    total_count = determine_total(projects)

    {:noreply,
     assign(socket,
       author: author,
       projects: projects,
       table_model: table_model,
       total_count: total_count,
       show_deleted: show_deleted,
       show_all: show_all,
       params: params
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
                <%= Oli.VendorProperties.product_short_name() %>
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
        <div class="lg:w-1/2 flex items-center justify-center">
          <div class="w-[360px] lg:w-96 bg-neutral-700 rounded-md">
            <div class="text-center text-white text-xl font-normal font-['Open Sans'] leading-7 py-8">
              Course Author Sign In
            </div>
            <%= for link <- @provider_links, do: raw(link) %>
            <div
              :if={@provider_links != []}
              class="my-4 text-center text-white text-base font-normal font-['Open Sans'] leading-snug"
            >
              OR
            </div>
            <%= form_for :user, Routes.authoring_pow_session_path(OliWeb.Endpoint, :create, request_path: ~p"/workspaces/course_author"), [as: :user], fn f -> %>
              <div class="flex flex-col gap-y-2">
                <div class="w-80 h-11 m-auto form-label-group border-none">
                  <%= email_input(f, Pow.Ecto.Schema.user_id_field(@socket),
                    class:
                      "form-control placeholder:text-zinc-300 !pl-6 h-11 !bg-stone-900 !rounded-md !border !border-zinc-300 !text-zinc-300 text-base font-normal font-['Open Sans'] leading-snug",
                    placeholder: "Email",
                    required: true,
                    autofocus: true
                  ) %>
                  <%= error_tag(f, Pow.Ecto.Schema.user_id_field(@socket)) %>
                </div>
                <div class="w-80 h-11 m-auto form-label-group border-none">
                  <%= password_input(f, :password,
                    class:
                      "form-control placeholder:text-zinc-300 !pl-6 h-11 !bg-stone-900 !rounded-md !border !border-zinc-300 !text-zinc-300 text-base font-normal font-['Open Sans'] leading-snug",
                    placeholder: "Password",
                    required: true
                  ) %>
                  <%= error_tag(f, :password) %>
                </div>
              </div>
              <div class="mb-4 d-flex flex-row justify-between px-8 pb-2 pt-6">
                <%= unless Application.fetch_env!(:oli, :always_use_persistent_login_sessions) do %>
                  <div class="flex items-center gap-x-2 custom-control custom-checkbox">
                    <%= checkbox(f, :persistent_session,
                      class: "w-4 h-4 !border !border-white",
                      style: "background-color: #171717"
                    ) %>
                    <%= label(f, :persistent_session, "Remember me",
                      class:
                        "text-center text-white text-base font-normal font-['Open Sans'] leading-snug"
                    ) %>
                  </div>
                <% else %>
                  <div></div>
                <% end %>
                <div class="custom-control">
                  <%= link("Forgot password?",
                    to: Routes.pow_reset_password_reset_password_path(@socket, :new),
                    tabindex: "1",
                    class:
                      "text-center text-[#4ca6ff] text-base font-bold font-['Open Sans'] leading-snug"
                  ) %>
                </div>
              </div>

              <div class="flex flex-col justify-center items-center gap-10 mb-16">
                <%= submit("Sign In",
                  class:
                    "w-80 h-11 bg-[#0062f2] mx-auto text-white text-xl font-normal leading-7 rounded-md btn btn-md btn-block mt-2"
                ) %>
                <.create_authoring_account_link ctx={@ctx} />
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <%= render_modal(assigns) %>
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
                <div class="flex flex-row items-center justify-between">
                  <div class="col-span-12 min-w-80 w-full">
                    <TextSearch.render
                      event_target={:live_view}
                      id="text-search"
                      reset="text_search_reset"
                      change="text_search_change"
                      text={@params.text_search}
                      placeholder="Search my projects..."
                    />
                  </div>
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

              <div class="grid grid-cols-12">
                <div id="projects-table" class="col-span-12">
                  <PagedTable.render
                    page_change="paged_table_page_change"
                    sort="paged_table_sort"
                    total_count={@total_count}
                    filter={@params.text_search}
                    allow_selection={false}
                    limit={@params.limit}
                    offset={@params.offset}
                    table_model={@table_model}
                    show_bottom_paging={true}
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
    do:
      Routes.authoring_pow_registration_path(OliWeb.Endpoint, :new,
        request_path: ~p"/workspaces/course_author"
      )

  defp create_authoring_account_path(_user),
    do:
      Routes.authoring_pow_registration_path(OliWeb.Endpoint, :new,
        link_to_user_account?: "true",
        request_path: ~p"/workspaces/course_author"
      )

  def patch_with(socket, changes) do
    %{table_model: table_model, params: params, show_all: show_all, show_deleted: show_deleted} =
      socket.assigns

    params =
      Map.merge(
        %{
          sort_by: table_model.sort_by_spec.name,
          sort_order: table_model.sort_order,
          offset: params.offset,
          limit: params.limit,
          text_search: params.text_search,
          show_deleted: show_deleted,
          show_all: show_all
        },
        changes
      )

    {:noreply, push_patch(socket, to: ~p"/workspaces/course_author?#{params}", replace: true)}
  end

  def handle_event("toggle_show_all", _, socket) do
    patch_with(socket, %{show_all: !socket.assigns.show_all})
  end

  def handle_event("toggle_show_deleted", _, socket) do
    patch_with(socket, %{show_deleted: !socket.assigns.show_deleted})
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

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  defp decode_params(params) do
    %{
      sidebar_expanded:
        Params.get_boolean_param(params, "sidebar_expanded", @default_params.sidebar_expanded),
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      direction: Params.get_param(params, "direction", @default_params.direction),
      field: Params.get_param(params, "field", @default_params.field)
    }
  end
end
