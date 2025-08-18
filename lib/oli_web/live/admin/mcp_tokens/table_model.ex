defmodule OliWeb.Admin.MCPTokens.TableModel do
  use Phoenix.Component

  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(tokens, ctx) do
    SortableTableModel.new(
      rows: tokens,
      column_specs: [
        %ColumnSpec{
          name: :author_name,
          label: "Author"
        },
        %ColumnSpec{
          name: :project_title,
          label: "Project"
        },
        %ColumnSpec{
          name: :hint,
          label: "Token Hint"
        },
        %ColumnSpec{
          name: :status,
          label: "Status",
          render_fn: &render_status_column/3
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Created",
          render_fn: &render_date_column/3
        },
        %ColumnSpec{
          name: :last_used_at,
          label: "Last Used",
          render_fn: &render_last_used_column/3
        },
        %ColumnSpec{
          name: :usage_last_7_days,
          label: "Usage (7d)",
          render_fn: &render_usage_count_column/3
        },
        %ColumnSpec{
          name: :total_usage,
          label: "Total Usage",
          render_fn: &render_total_usage_column/3
        }
      ],
      event_suffix: "",
      id_field: [:bearer_token_id],
      data: %{ctx: ctx}
    )
  end

  def render_status_column(assigns, row, _) do
    assigns = Map.merge(assigns, %{status: row.bearer_token.status})

    ~H"""
    <span class={[
      "px-2 py-1 rounded-full text-xs font-medium",
      case @status do
        "enabled" -> "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
        "disabled" -> "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"
        _ -> "bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200"
      end
    ]}>
      {String.capitalize(@status)}
    </span>
    """
  end

  def render_date_column(assigns, row, _) do
    assigns = Map.merge(assigns, %{inserted_at: row.bearer_token.inserted_at})

    ~H"""
    {FormatDateTime.parse_datetime(@inserted_at, @ctx, "{0M}/{D}/{YY}")}
    """
  end

  def render_last_used_column(assigns, row, _) do
    assigns = Map.merge(assigns, %{last_used_at: row.bearer_token.last_used_at})

    ~H"""
    <%= if @last_used_at do %>
      {FormatDateTime.parse_datetime(@last_used_at, @ctx, "{0M}/{D}/{YY}")}
    <% else %>
      <span class="text-gray-500 dark:text-gray-400">Never</span>
    <% end %>
    """
  end

  def render_usage_count_column(assigns, row, _) do
    assigns = Map.merge(assigns, %{count: row.usage_last_7_days || 0})

    ~H"""
    <span class="text-sm font-semibold">{@count}</span>
    """
  end

  def render_total_usage_column(assigns, row, _) do
    assigns = Map.merge(assigns, %{count: row.total_usage || 0})

    ~H"""
    <span class="text-sm font-semibold">{@count}</span>
    """
  end
end