defmodule OliWeb.CollaborationLive.InstructorTableModel do
  alias OliWeb.CollaborationLive.AdminTableModel
  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(rows, context) do
    SortableTableModel.new(
      rows: rows,
      column_specs: [
        %ColumnSpec{
          name: :page_title,
          label: "Page Title",
          render_fn: &__MODULE__.render_page_title/3,
          sort_fn: &AdminTableModel.custom_sort/2
        },
        %ColumnSpec{
          name: :status,
          label: "Status",
          render_fn: &AdminTableModel.render_status/3,
          sort_fn: &AdminTableModel.custom_sort/2
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
        context: context
      }
    )
  end

  def render_page_title(
        assigns,
        %{page: %{title: title, slug: page_revision_slug}, section: %{slug: section_slug}},
        _
      ) do
    route_path = Routes.page_delivery_path(OliWeb.Endpoint, :page_preview, section_slug, page_revision_slug)
    SortableTableModel.render_link_column(assigns, title, route_path)
  end
end
