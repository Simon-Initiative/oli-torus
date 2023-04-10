defmodule OliWeb.CollaborationLive.IndexView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.SortableTable.TableHandlers

  alias Oli.Resources.Collaboration
  alias OliWeb.Admin.AdminView
  alias OliWeb.Common.{Breadcrumb, Filter, Listing, SessionContext}
  alias OliWeb.CollaborationLive.{AdminTableModel, InstructorTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias alias OliWeb.Sections.Mount

  @title "Collaborative Spaces"

  data title, :string, default: @title
  data breadcrumbs, :any
  data filter, :any, default: %{}
  data query, :string, default: ""
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: 20
  data sort, :string, default: "sort"
  data page_change, :string, default: "page_change"
  data show_bottom_paging, :boolean, default: false
  data additional_table_class, :string, default: ""

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  def filter_rows(socket, query, _filter) do
    query_str = String.downcase(query)

    Enum.filter(socket.assigns.collab_spaces, fn cs ->
      String.contains?(String.downcase(cs.page.title), query_str) or
        (socket.assigns.live_action == :admin and
           String.contains?(String.downcase(cs.project.title), query_str))
    end)
  end

  def live_path(%{assigns: %{live_action: :admin}} = socket, params),
    do: Routes.collab_spaces_index_path(socket, :admin, params)

  def live_path(
        %{assigns: %{live_action: :instructor, section_slug: section_slug}} = socket,
        params
      ),
      do: Routes.collab_spaces_index_path(socket, :instructor, section_slug, params)

  def breadcrumb(:admin, _) do
    AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: @title,
          link: Routes.collab_spaces_index_path(OliWeb.Endpoint, :admin)
        })
      ]
  end

  def breadcrumb(:instructor, section_slug) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(:instructor, %{slug: section_slug}) ++
      [
        Breadcrumb.new(%{
          full_title: @title,
          link: Routes.collab_spaces_index_path(OliWeb.Endpoint, :instructor, section_slug)
        })
      ]
  end

  def mount(params, session, socket) do
    live_action = socket.assigns.live_action
    context = SessionContext.init(session)
    section_slug = params["section_slug"]

    do_mount = fn ->
      {collab_spaces, table_model} =
        get_collab_spaces_and_table_model(live_action, context, section_slug)

      {:ok,
       assign(socket,
         breadcrumbs: breadcrumb(live_action, section_slug),
         section_slug: section_slug,
         collab_spaces: collab_spaces,
         table_model: table_model,
         total_count: length(collab_spaces)
       )}
    end

    case live_action do
      :instructor ->
        case Mount.for(section_slug, session) do
          {:error, e} ->
            Mount.handle_error(socket, {:error, e})

          {_type, _user, _section} ->
            do_mount.()
        end

      :admin ->
        do_mount.()
    end
  end

  def render(assigns) do
    ~F"""
      <div class="d-flex p-3 justify-content-between">
        <Filter
          change="change_search"
          reset="reset_search"
          apply="apply_search"
          query={@query}/>
      </div>

      <div id="collaborative-spaces-table" class="p-4">
        <Listing
          filter={@query}
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
          sort={@sort}
          page_change={@page_change}
          show_bottom_paging={@show_bottom_paging}
          additional_table_class={@additional_table_class}/>
      </div>
    """
  end

  defp get_collab_spaces_and_table_model(:admin, context, _) do
    collab_spaces = Collaboration.list_collaborative_spaces()
    {:ok, table_model} = AdminTableModel.new(collab_spaces, context)

    {collab_spaces, table_model}
  end

  defp get_collab_spaces_and_table_model(:instructor, context, section_slug) do
    {_, collab_spaces} = Collaboration.list_collaborative_spaces_in_section(section_slug)
    {:ok, table_model} = InstructorTableModel.new(collab_spaces, context)

    {collab_spaces, table_model}
  end
end
