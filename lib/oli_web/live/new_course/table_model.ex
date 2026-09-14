defmodule OliWeb.Delivery.NewCourse.TableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}

  def new(products, ctx) do
    column_specs = [
      %ColumnSpec{
        name: :action,
        label: "",
        render_fn: &__MODULE__.render_action_column/3
      },
      %ColumnSpec{
        name: :title,
        label: "Title",
        render_fn: &__MODULE__.render_title_column/3,
        sort_fn: &__MODULE__.sort_title_column/2
      },
      %ColumnSpec{
        name: :type,
        label: "Type",
        render_fn: &__MODULE__.render_type_column/3
      },
      %ColumnSpec{
        name: :requires_payment,
        label: "Cost",
        render_fn: &__MODULE__.render_payment_column/3,
        sort_fn: &__MODULE__.sort_payment_column/2
      },
      %ColumnSpec{
        name: :inserted_at,
        label: "Created",
        render_fn: &Common.render_date/3,
        sort_fn: &OliWeb.Common.Table.Common.sort_date/2
      }
    ]

    SortableTableModel.new(
      rows: products,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:unique_id],
      sort_by_spec: Enum.at(column_specs, 1),
      sort_order: :desc,
      data: %{
        ctx: ctx
      }
    )
  end

  @doc "Returns whether a source-list item is a reusable course template."
  def is_product?(item),
    do: Map.has_key?(item, :type) and Map.get(item, :type) == :blueprint

  @doc "Returns whether a source-list item is an existing enrollable course."
  def is_course?(item),
    do: Map.has_key?(item, :type) and Map.get(item, :type) == :enrollable

  @doc "Returns the display title for a project publication, template, or course source."
  def source_title(item) do
    case {is_product?(item), is_course?(item)} do
      {true, _} -> item.title
      {_, true} -> item.title
      _ -> item.project.title
    end
  end

  @doc "Returns the description for a project publication, template, or course source."
  def source_description(item) do
    case {is_product?(item), is_course?(item)} do
      {true, _} -> item.description
      {_, true} -> item.description
      _ -> item.project.description
    end
  end

  @doc "Returns the typed source identifier consumed by the course-creation workflow."
  def source_identifier(item) do
    case {is_product?(item), is_course?(item)} do
      {true, _} -> "product:#{item.id}"
      {_, true} -> "section:#{item.id}"
      _ -> "publication:#{item.id}"
    end
  end

  def render_payment_column(_, item, _) do
    if payable_source?(item) do
      case Money.to_string(item.amount) do
        {:ok, m} -> m
        _ -> "Yes"
      end
    else
      "Free"
    end
  end

  def sort_payment_column(sort_order, sort_spec) do
    {fn item ->
       amount =
         if payable_source?(item) do
           case Money.to_string(item.amount) do
             {:ok, m} -> m
             _ -> 0
           end
         else
           0
         end

       %{requires_payment: amount}
     end, ColumnSpec.default_sort_fn(sort_order, sort_spec)}
  end

  def render_title_column(_assigns, item, _) do
    source_title(item)
  end

  def sort_title_column(sort_order, sort_spec) do
    {fn item ->
       Map.put(item, :title, String.downcase(source_title(item)))
     end, ColumnSpec.default_sort_fn(sort_order, sort_spec)}
  end

  def render_action_column(assigns, item, _) do
    id = source_identifier(item)

    assigns = Map.merge(assigns, %{id: id})

    ~H"""
    <button class="btn btn-primary btn-sm" phx-click="source_selection" phx-value-id={@id}>
      Select
    </button>
    """
  end

  def render_type_column(_, item, _) do
    case {is_product?(item), is_course?(item)} do
      {true, _} -> "Template"
      {_, true} -> "Course"
      _ -> "Project"
    end
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  defp payable_source?(item),
    do: (is_product?(item) or is_course?(item)) and Map.get(item, :requires_payment, false)
end
