defmodule OliWeb.Products.ProductsTableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Common.Utils

  def new(products, ctx, project_slug \\ "", opts \\ []) do
    default_td_class = "!border-r border-Table-table-border"
    default_th_class = "!border-r border-Table-table-border"
    search_term = Keyword.get(opts, :search_term, "")
    is_admin = Keyword.get(opts, :is_admin, false)
    current_author = Keyword.get(opts, :current_author)

    base_columns = [
      %ColumnSpec{
        name: :title,
        label: "Title",
        render_fn: &render_title_column(Map.put(&1, :project_slug, project_slug), &2, &3),
        th_class: "!sticky left-0 z-[60] " <> default_th_class,
        td_class: "!sticky left-0 z-[1] bg-inherit " <> default_td_class
      }
    ]

    tags_column = %ColumnSpec{
      name: :tags,
      label: "Tags",
      render_fn: &render_tags_column/3,
      sortable: false,
      td_class: "w-[200px] min-w-[200px] max-w-[200px] !p-0 " <> default_td_class,
      th_class: "w-[200px] min-w-[200px] max-w-[200px] " <> default_th_class
    }

    remaining_columns = [
      %ColumnSpec{
        name: :inserted_at,
        label: "Created",
        render_fn: &render_created_column/3,
        td_class: default_td_class,
        th_class: default_th_class
      },
      %ColumnSpec{
        name: :requires_payment,
        label: "Requires Payment",
        render_fn: &render_payment_column/3,
        sort_fn: &sort_payment_column/2,
        td_class: default_td_class,
        th_class: default_th_class
      },
      %ColumnSpec{
        name: :base_project_id,
        label: "Base Project",
        render_fn: &render_project_column(Map.put(&1, :project_slug, project_slug), &2, &3),
        td_class: default_td_class,
        th_class: default_th_class
      },
      %ColumnSpec{name: :status, label: "Status", render_fn: &render_status_column/3}
    ]

    column_specs =
      if is_admin do
        base_columns ++ [tags_column] ++ remaining_columns
      else
        base_columns ++ remaining_columns
      end

    sort_by = Keyword.get(opts, :sort_by_spec, :inserted_at)
    sort_order = Keyword.get(opts, :sort_order, :desc)

    sort_by_spec =
      Enum.find(column_specs, fn spec -> spec.name == sort_by end)

    SortableTableModel.new(
      rows: products,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      sort_by_spec: sort_by_spec,
      sort_order: sort_order,
      data: %{ctx: ctx, search_term: search_term, current_author: current_author}
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

    search_term = Map.get(assigns, :search_term, "")

    assigns =
      Map.merge(assigns, %{
        title: title,
        slug: slug,
        route_path: route_path,
        search_term: search_term
      })

    ~H"""
    <div class="flex flex-col">
      <a
        href={@route_path}
        class="text-Text-text-link text-base font-medium leading-normal"
      >
        {highlight_search_term(@title, @search_term)}
      </a>
      <span class="text-Text-text-low text-sm font-normal leading-tight">
        ID: {highlight_search_term(@slug, @search_term)}
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

    search_term = Map.get(assigns, :search_term, "")

    assigns =
      Map.merge(assigns, %{
        base_project: base_project,
        route_path: route_path,
        search_term: search_term
      })

    ~H"""
    <div class="flex flex-col">
      <a
        href={@route_path}
        class="text-Text-text-link text-base font-medium leading-normal"
      >
        {highlight_search_term(@base_project.title, @search_term)}
      </a>
      <span class="text-Text-text-low text-sm font-normal leading-tight">
        ID: {highlight_search_term(@base_project.slug, @search_term)}
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
    <div>
      <.live_component
        module={OliWeb.Live.Components.Tags.TagsComponent}
        id={"tags-#{@product.id}"}
        entity_type={:section}
        entity_id={@product.id}
        current_tags={Map.get(@product, :tags, [])}
        current_author={@current_author}
      />
    </div>
    """
  end

  defp sort_payment_column(order, _spec) do
    {fn
       %{requires_payment: false} -> Decimal.new(-1)
       %{amount: %Money{amount: amount}} -> amount
       _ -> Decimal.new(0)
     end, {order, Decimal}}
  end

  defp highlight_search_term(text, search_term),
    do:
      Phoenix.HTML.raw(
        Utils.multi_highlight_search_term(
          text || "",
          search_term,
          "span class=\"search-highlight\"",
          "span"
        )
      )
end
