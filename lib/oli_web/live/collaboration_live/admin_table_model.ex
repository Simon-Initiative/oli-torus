defmodule OliWeb.CollaborationLive.AdminTableModel do
  use OliWeb, :verified_routes

  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(rows, ctx) do
    SortableTableModel.new(
      rows: rows,
      column_specs: [
        %ColumnSpec{
          name: :project_title,
          label: "Project Title",
          render_fn: &__MODULE__.render_project_title/3,
          sort_fn: &__MODULE__.custom_sort/2
        },
        %ColumnSpec{
          name: :page_title,
          label: "Page Title",
          render_fn: &__MODULE__.render_page_title/3,
          sort_fn: &__MODULE__.custom_sort/2
        },
        %ColumnSpec{
          name: :status,
          label: "Status",
          render_fn: &__MODULE__.render_status/3,
          sort_fn: &__MODULE__.custom_sort/2
        },
        %ColumnSpec{
          name: :number_of_posts,
          label: "# of Posts"
        },
        %ColumnSpec{
          name: :number_of_posts_pending_approval,
          label: "# of Posts Pending Approval"
        },
        %ColumnSpec{
          name: :most_recent_post,
          label: "Most Recent Post",
          render_fn: &Common.render_date/3,
          sort_fn: &Common.sort_date/2
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{
        ctx: ctx
      }
    )
  end

  def render_project_title(assigns, %{project: %{title: title, slug: project_slug}}, _) do
    route_path = ~p"/workspaces/course_author/#{project_slug}/overview"
    SortableTableModel.render_link_column(assigns, title, route_path)
  end

  def render_page_title(
        assigns,
        %{page: %{title: title, slug: page_revision_slug}, project: %{slug: project_slug}},
        _
      ) do
    route_path = Routes.resource_path(OliWeb.Endpoint, :edit, project_slug, page_revision_slug)
    SortableTableModel.render_link_column(assigns, title, route_path)
  end

  def render_status(assigns, %{collab_space_config: %{status: :enabled}}, _),
    do: SortableTableModel.render_span_column(assigns, "Enabled", "text-success")

  def render_status(assigns, %{collab_space_config: %{"status" => "enabled"}}, _),
    do: SortableTableModel.render_span_column(assigns, "Enabled", "text-success")

  def render_status(assigns, %{collab_space_config: %{status: :disabled}}, _),
    do: SortableTableModel.render_span_column(assigns, "Disabled", "text-danger")

  def render_status(assigns, %{collab_space_config: %{"status" => "disabled"}}, _),
    do: SortableTableModel.render_span_column(assigns, "Disabled", "text-danger")

  def render_status(assigns, %{collab_space_config: %{status: :archived}}, _),
    do: SortableTableModel.render_span_column(assigns, "Archived", "text-info")

  def render_status(assigns, %{collab_space_config: %{"status" => "archived"}}, _),
    do: SortableTableModel.render_span_column(assigns, "Archived", "text-info")

  def custom_sort(direction, %ColumnSpec{name: :project_title}),
    do: {fn row -> row.project.title end, direction}

  def custom_sort(direction, %ColumnSpec{name: :page_title}),
    do: {fn row -> row.page.title end, direction}

  def custom_sort(direction, %ColumnSpec{name: :status}),
    do:
      {fn row ->
         status =
           Map.get(row.collab_space_config, "status") || Map.get(row.collab_space_config, :status)

         if is_atom(status), do: Atom.to_string(status), else: status
       end, direction}
end
