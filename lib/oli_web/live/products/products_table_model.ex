defmodule OliWeb.Products.ProductsTableModel do
  use OliWeb, :verified_routes
  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(products, ctx, project_slug \\ "") do
    SortableTableModel.new(
      rows: products,
      column_specs: [
        %ColumnSpec{
          name: :title,
          label: "Product Title",
          render_fn:
            &__MODULE__.render_title_column(Map.put(&1, :project_slug, project_slug), &2, &3)
        },
        %ColumnSpec{name: :status, label: "Status"},
        %ColumnSpec{
          name: :requires_payment,
          label: "Requires Payment",
          render_fn: &__MODULE__.render_payment_column/3
        },
        %ColumnSpec{
          name: :base_project_id,
          label: "Base Project",
          render_fn:
            &__MODULE__.render_project_column(Map.put(&1, :project_slug, project_slug), &2, &3)
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Created",
          render_fn: &Common.render_date/3
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{ctx: ctx}
    )
  end

  def render_payment_column(_, %{requires_payment: requires_payment, amount: amount}, _) do
    if requires_payment do
      case Money.to_string(amount) do
        {:ok, m} -> m
        _ -> "Yes"
      end
    else
      "None"
    end
  end

  def render_title_column(assigns, %{title: title, slug: slug}, _) do
    route_path =
      case Map.get(assigns, :project_slug) do
        "" -> Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, slug)
        project_slug -> ~p"/workspaces/course_author/#{project_slug}/products/#{slug}"
      end

    SortableTableModel.render_link_column(assigns, title, route_path)
  end

  def render_project_column(assigns, %{base_project: base_project}, _) do
    route_path =
      case Map.get(assigns, :project_slug) do
        "" -> Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.OverviewLive, base_project.slug)
        _project_slug -> ~p"/workspaces/course_author/#{base_project}/overview"
      end

    SortableTableModel.render_link_column(assigns, base_project.title, route_path)
  end
end
