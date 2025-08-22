defmodule OliWeb.Products.ProductsTableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.FormatDateTime

  def new(products, ctx, project_slug \\ "") do
    SortableTableModel.new(
      rows: products,
      column_specs: [
        %ColumnSpec{
          name: :title,
          label: "Title",
          render_fn: &render_title_column(Map.put(&1, :project_slug, project_slug), &2, &3)
        },
        %ColumnSpec{
          name: :tags,
          label: "Tags",
          render_fn: &render_tags_column/3,
          sortable: false
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Created",
          render_fn: &render_created_column/3
        },
        %ColumnSpec{
          name: :requires_payment,
          label: "Requires Payment",
          render_fn: &render_payment_column/3,
          sort_fn: &sort_payment_column/2
        },
        %ColumnSpec{
          name: :base_project_id,
          label: "Base Project",
          render_fn: &render_project_column(Map.put(&1, :project_slug, project_slug), &2, &3)
        },
        %ColumnSpec{
          name: :institution_name,
          label: "Institution",
          render_fn: &render_institution_column/3
        },
        %ColumnSpec{name: :status, label: "Status", render_fn: &render_status_column/3}
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{ctx: ctx}
    )
  end

  def render_payment_column(_, %{requires_payment: false}, _), do: "None"

  def render_payment_column(_, %{amount: amount}, _) do
    case Money.to_string(amount) do
      {:ok, m} -> m
      _ -> "Yes"
    end
  end

  def render_title_column(assigns, %{title: title, slug: slug}, _) do
    route_path =
      case Map.get(assigns, :project_slug) do
        "" -> ~p"/authoring/products/#{slug}"
        project_slug -> ~p"/workspaces/course_author/#{project_slug}/products/#{slug}"
      end

    assigns = Map.merge(assigns, %{title: title, slug: slug, route_path: route_path})

    ~H"""
    <div class="flex flex-col">
      <a
        href={@route_path}
        class="text-Text-text-link text-base font-medium leading-normal"
      >
        {@title}
      </a>
      <span class="text-Text-text-low text-sm font-normal leading-tight">
        ID: {@slug}
      </span>
    </div>
    """
  end

  def render_project_column(assigns, %{base_project: base_project}, _) do
    route_path =
      case Map.get(assigns, :project_slug) do
        "" -> ~p"/workspaces/course_author/#{base_project.slug}/overview"
        _project_slug -> ~p"/workspaces/course_author/#{base_project}/overview"
      end

    assigns = Map.merge(assigns, %{base_project: base_project, route_path: route_path})

    ~H"""
    <div class="flex flex-col">
      <a
        href={@route_path}
        class="text-Text-text-link text-base font-medium leading-normal"
      >
        {@base_project.title}
      </a>
      <span class="text-Text-text-low text-sm font-normal leading-tight">
        ID: {@base_project.slug}
      </span>
    </div>
    """
  end

  def render_status_column(assigns, product, _) do
    assigns = Map.merge(assigns, %{product: product})

    case product.status do
      :active ->
        SortableTableModel.render_span_column(
          assigns,
          "Active",
          "text-Table-text-accent-green"
        )

      _ ->
        SortableTableModel.render_span_column(
          assigns,
          String.capitalize(to_string(product.status)),
          "text-Table-text-danger"
        )
    end
  end

  defp render_created_column(assigns, %{inserted_at: inserted_at}, _) do
    assigns = Map.merge(assigns, %{inserted_at: inserted_at})

    ~H"""
    <span class="text-Text-text-high text-base font-medium">
      {FormatDateTime.to_formatted_datetime(
        @inserted_at,
        @ctx,
        "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
      )}
    </span>
    """
  end

  defp render_tags_column(assigns, product, _) do
    assigns = Map.merge(assigns, %{product: product})

    ~H"""
    <span class="text-Text-text-high text-base font-medium">
      {Map.get(@product, :tags, "")}
    </span>
    """
  end

  defp render_institution_column(_assigns, %{institution_name: nil}, _), do: ""

  defp render_institution_column(
         assigns,
         %{institution_name: institution_name, institution_id: institution_id},
         _
       ) do
    assigns =
      Map.merge(assigns, %{institution_name: institution_name, institution_id: institution_id})

    ~H"""
    <a
      href={~p"/admin/institutions/#{@institution_id}"}
      class="text-Text-text-link text-base font-medium leading-normal"
    >
      {@institution_name}
    </a>
    """
  end

  defp sort_payment_column(order, _spec) do
    {fn
       %{requires_payment: false} -> Decimal.new(-1)
       %{amount: %Money{amount: amount}} -> amount
       _ -> Decimal.new(0)
     end, {order, Decimal}}
  end
end
