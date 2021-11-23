defmodule OliWeb.Users.AuthorsView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb}
  alias Oli.Accounts
  alias Oli.Accounts.{AuthorBrowseOptions, Author}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Users.AuthorsTableModel

  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params

  @limit 25
  @default_options %AuthorBrowseOptions{
    text_search: ""
  }

  prop author, :any
  data breadcrumbs, :any
  data title, :string, default: "All Authors"

  data authors, :list, default: []

  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: @limit
  data options, :any

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

  def mount(_, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)

    authors =
      Accounts.browse_authors(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :name},
        @default_options
      )

    total_count = determine_total(authors)

    {:ok, table_model} = AuthorsTableModel.new(authors)

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

  defp determine_total(projects) do
    case(projects) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
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
    total_count = determine_total(authors)

    {:noreply,
     assign(socket,
       offset: offset,
       authors: authors,
       table_model: table_model,
       total_count: total_count,
       options: options
     )}
  end

  def render(assigns) do
    ~F"""
    <div>

      <TextSearch id="text-search" text={@options.text_search} />

      <div class="mb-3"/>

      <PagedTable
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}/>

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
