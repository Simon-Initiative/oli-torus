defmodule OliWeb.Admin.MCPTokens.TableModel do
  use OliWeb, :html

  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(tokens, ctx) do
    SortableTableModel.new(
      rows: tokens,
      column_specs: [
        %ColumnSpec{
          name: :author_name,
          label: "Author",
          render_fn: &render_author_name_column/3
        },
        %ColumnSpec{
          name: :project_title,
          label: "Project",
          render_fn: &render_project_title_column/3
        },
        %ColumnSpec{
          name: :hint,
          label: "Token Hint",
          render_fn: &render_hint_column/3
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
        },
        %ColumnSpec{
          name: :actions,
          label: "Actions",
          render_fn: &render_actions_column/3,
          sortable: false
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
        :active -> "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
        :disabled -> "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"
        _ -> "bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200"
      end
    ]}>
      {String.capitalize(to_string(@status))}
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

  def render_actions_column(assigns, row, _) do
    assigns =
      Map.merge(assigns, %{
        token: row.bearer_token,
        token_id: row.bearer_token.id,
        current_status: row.bearer_token.status
      })

    ~H"""
    <button
      type="button"
      class={[
        "px-3 py-1 text-xs font-medium rounded-md transition-colors",
        case @current_status do
          :active -> "text-red-700 bg-red-50 hover:bg-red-100 border border-red-200"
          :disabled -> "text-green-700 bg-green-50 hover:bg-green-100 border border-green-200"
        end
      ]}
      phx-click="toggle_token_status"
      phx-value-token-id={@token_id}
      phx-value-current-status={@current_status}
      data-confirm={
        case @current_status do
          :active ->
            "Are you sure you want to disable this token? This will prevent all API access using this token."

          :disabled ->
            "Are you sure you want to reactivate this token? This will restore API access."
        end
      }
    >
      <%= case @current_status do %>
        <% :active -> %>
          Disable
        <% :disabled -> %>
          Enable
      <% end %>
    </button>
    """
  end

  def render_author_name_column(assigns, row, _) do
    assigns = Map.merge(assigns, %{author_name: row.author.name})

    ~H"""
    {@author_name}
    """
  end

  def render_project_title_column(assigns, row, _) do
    assigns =
      Map.merge(assigns, %{
        project_title: row.project.title,
        project_slug: row.project.slug
      })

    ~H"""
    <.link
      navigate={~p"/workspaces/course_author/#{@project_slug}/overview"}
      class="text-blue-600 hover:text-blue-800 underline"
    >
      {@project_title}
    </.link>
    """
  end

  def render_hint_column(assigns, row, _) do
    assigns = Map.merge(assigns, %{hint: row.bearer_token.hint})

    ~H"""
    {@hint}
    """
  end
end
