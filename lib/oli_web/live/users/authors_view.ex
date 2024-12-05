defmodule OliWeb.Users.AuthorsView do
  use OliWeb, :live_view

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Accounts
  alias Oli.Accounts.AuthorBrowseOptions
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{Breadcrumb, PagedTable, SessionContext, TextSearch}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Users.AuthorsTableModel

  @limit 25
  @default_options %AuthorBrowseOptions{
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
          full_title: "All Authors",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  def mount(_, %{"current_author_id" => author_id} = session, socket) do
    author = socket.assigns.current_author

    authors =
      Accounts.browse_authors(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :name},
        @default_options
      )

    ctx = socket.assigns.ctx
    total_count = SortableTableModel.determine_total(authors)
    {:ok, table_model} = AuthorsTableModel.new(authors, ctx)

    {:ok,
     assign(socket,
       breadcrumbs: set_breadcrumbs(),
       author: author,
       authors: authors,
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

    options = %AuthorBrowseOptions{
      text_search: get_param(params, "text_search", "")
    }

    authors =
      Accounts.browse_authors(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, authors)
    total_count = SortableTableModel.determine_total(authors)

    {:noreply,
     assign(socket,
       offset: offset,
       authors: authors,
       table_model: table_model,
       total_count: total_count,
       options: options
     )}
  end

  attr :author, :any
  attr :breadcrumbs, :any
  attr :title, :string, default: "All Authors"
  attr :authors, :list, default: []
  attr :tabel_model, :map
  attr :total_count, :integer, default: 0
  attr :offset, :integer, default: 0
  attr :limit, :integer, default: @limit
  attr :options, :any

  def render(assigns) do
    ~H"""
    <div>
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
               text_search: socket.assigns.options.text_search
             },
             changes
           )
         ),
       replace: true
     )}
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end
end
