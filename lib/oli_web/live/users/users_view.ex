defmodule OliWeb.Users.UsersView do
  use OliWeb, :live_view

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Accounts
  alias Oli.Accounts.UserBrowseOptions
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{Breadcrumb, Check, PagedTable, TextSearch}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Users.UsersTableModel

  @limit 25
  @default_options %UserBrowseOptions{
    include_guests: false,
    text_search: ""
  }

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
          full_title: "All Users",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  def mount(_, session, socket) do
    users =
      Accounts.browse_users(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :name},
        @default_options
      )

    total_count = SortableTableModel.determine_total(users)

    ctx = socket.assigns.ctx
    {:ok, table_model} = UsersTableModel.new(users, ctx)

    {:ok,
     assign(socket,
       title: "All Users",
       breadcrumbs: set_breadcrumbs(),
       users: users,
       total_count: total_count,
       table_model: table_model,
       options: @default_options
     )}
  end

  def handle_params(params, _, socket) do
    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)

    options = %UserBrowseOptions{
      text_search: get_param(params, "text_search", ""),
      include_guests: get_boolean_param(params, "include_guests", false)
    }

    users =
      Accounts.browse_users(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, users)
    total_count = SortableTableModel.determine_total(users)

    {:noreply,
     assign(socket,
       offset: offset,
       users: users,
       table_model: table_model,
       total_count: total_count,
       options: options
     )}
  end

  attr(:breadcrumbs, :any)
  attr(:users, :list, default: [])
  attr(:tabel_model, :map)
  attr(:total_count, :integer, default: 0)
  attr(:offset, :integer, default: 0)
  attr(:limit, :integer, default: @limit)
  attr(:options, :any)

  def render(assigns) do
    ~H"""
    <div>
      <Check.render class="mr-4" checked={@options.include_guests} click="include_guests">
        Show guest users
      </Check.render>

      <div class="mb-3" />

      <TextSearch.render id="text-search" text={@options.text_search} />

      <div class="mb-3" />

      <PagedTable.render
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
      />
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
               text_search: socket.assigns.options.text_search,
               include_guests: socket.assigns.options.include_guests
             },
             changes
           )
         ),
       replace: true
     )}
  end

  def handle_event("include_guests", _, socket),
    do: patch_with(socket, %{include_guests: !socket.assigns.options.include_guests})

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end
end
