defmodule OliWeb.Sections.SectionsView do
  use Surface.LiveView
  alias Oli.Repo

  alias OliWeb.Common.Filter
  alias OliWeb.Common.PagedTable
  alias OliWeb.Common.Breadcrumb
  alias Oli.Accounts.Author
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes

  prop author, :any
  data breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "All Course Sections"})]
  data title, :string, default: "All Course Sections"

  data sections, :list, default: []
  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: 50
  data filter, :string, default: ""
  data applied_filter, :string, default: ""

  @table_filter_fn &OliWeb.Sections.SectionsView.filter_rows/2
  @table_push_patch_path &OliWeb.Sections.SectionsView.live_path/2

  def filter_rows(socket, filter) do
    case String.downcase(filter) do
      "" ->
        socket.assigns.sections

      str ->
        Enum.filter(socket.assigns.sections, fn p ->
          amount_str =
            if p.requires_payment do
              case Money.to_string(p.amount) do
                {:ok, money} -> String.downcase(money)
                _ -> ""
              end
            else
              "none"
            end

          String.contains?(String.downcase(p.title), str) or String.contains?(amount_str, str)
        end)
    end
  end

  def live_path(socket, params) do
    Routes.live_path(socket, OliWeb.Sections.SectionsView, params)
  end

  def mount(_, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)

    sections = Oli.Delivery.Sections.list_enrollable_with_details()
    total_count = length(sections)

    {:ok, table_model} = OliWeb.Sections.SectionsTableModel.new(sections)

    {:ok,
     assign(socket,
       author: author,
       sections: sections,
       total_count: total_count,
       table_model: table_model
     )}
  end

  def render(assigns) do
    ~F"""
    <div>

      <Filter change={"change_filter"} reset="reset_filter" apply="apply_filter"/>

      <div class="mb-3"/>

      <PagedTable
        filter={@filter}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
        sort="sort"
        page_change="page_change"/>

    </div>

    """
  end

  use OliWeb.Common.SortableTable.TableHandlers
end
