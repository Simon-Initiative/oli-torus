defmodule OliWeb.Products.Payments.TableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias Surface.Components.Link
  alias OliWeb.Router.Helpers, as: Routes
  use Surface.LiveComponent

  def new(payments) do
    SortableTableModel.new(
      rows: payments,
      column_specs: [
        %ColumnSpec{
          name: :type,
          label: "Type",
          render_fn: &__MODULE__.render_type_column/3,
          sort_fn: &__MODULE__.sort/2
        },
        %ColumnSpec{
          name: :generated_date,
          label: "Created Date",
          render_fn: &__MODULE__.render_gen_date_column/3
        },
        %ColumnSpec{
          name: :applicaton_date,
          label: "Application Date",
          render_fn: &__MODULE__.render_app_date_column/3
        },
        %ColumnSpec{
          name: :user,
          label: "User",
          render_fn: &__MODULE__.render_user_column/3
        },
        %ColumnSpec{
          name: :user,
          label: "Section",
          render_fn: &__MODULE__.render_section_column/3
        }
      ],
      event_suffix: "",
      id_field: [:unique_id]
    )
  end

  def render_section_column(_, %{section: section}, _) do
    case section do
      nil -> ""
      s -> s.title
    end
  end

  def render_user_column(_, %{user: user}, _) do
    case user do
      nil -> ""
      user -> user.family_name <> ", " <> user.given_name
    end
  end

  def render_type_column(assigns, %{payment: payment, code: code}, _) do
    case payment.type do
      :direct ->
        "Direct"

      :deferred ->
        ~F"""
        Code: <code>{code}</code>
        """
    end
  end

  def sort(direction, spec) do
    fn row1, row2 ->
      value1 =
        case row1.payment.type do
          :direct -> "Direct"
          :deferred -> "Code: [#{row1.code}]"
        end

      value2 =
        case row2.payment.type do
          :direct -> "Direct"
          :deferred -> "Code: [#{row2.code}]"
        end

      case direction do
        :asc -> value1 < value2
        _ -> value2 < value1
      end
    end
  end

  def render_gen_date_column(_, %{payment: payment}, _) do
    case payment.generation_date do
      nil -> ""
      d -> Timex.format!(d, "{relative}", :relative)
    end
  end

  def render_app_date_column(_, %{payment: payment}, _) do
    case payment.application_date do
      nil -> ""
      d -> Timex.format!(d, "{relative}", :relative)
    end
  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
