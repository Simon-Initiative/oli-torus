defmodule OliWeb.Admin.ExternalTools.TableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(tools, ctx) do
    SortableTableModel.new(
      rows: tools,
      column_specs: [
        %ColumnSpec{
          name: :name,
          label: "Tool Name"
        },
        %ColumnSpec{
          name: :description,
          label: "Description"
        },
        %ColumnSpec{
          name: :status,
          label: "Status",
          render_fn: &render_status_column/3
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Date Added",
          render_fn: &render_date_column/3
        },
        %ColumnSpec{
          name: :usage_count,
          label: "Usage Count",
          render_fn: &render_usage_count_column/3
        },
        %ColumnSpec{
          name: :actions,
          label: "Actions",
          render_fn: &render_actions_column/3,
          sortable: false
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{ctx: ctx}
    )
  end

  def render_status_column(assigns, row, _) do
    assigns = Map.merge(assigns, %{status: row.status})

    ~H"""
    <span class={[
      "text-sm font-bold text-center",
      case @status do
        :enabled -> "text-[#006CD9] dark:text-[#4CA6FF]"
        :disabled -> "text-[#CE2C31] dark:text-[#FF8787]"
        :deleted -> "text-gray-500 dark:text-gray-400"
        _ -> ""
      end
    ]}>
      {String.capitalize(Atom.to_string(@status))}
    </span>
    """
  end

  def render_date_column(assigns, row, _) do
    assigns = Map.merge(assigns, %{inserted_at: row.inserted_at})

    ~H"""
    {FormatDateTime.parse_datetime(@inserted_at, @ctx, "{0M}/{D}/{YY}")}
    """
  end

  def render_usage_count_column(assigns, row, _) do
    assigns = Map.merge(assigns, %{usage_count: row.usage_count, platform_instance_id: row.id})

    ~H"""
    <.link
      href={~p"/admin/external_tools/#{@platform_instance_id}/usage"}
      class="text-base font-bold underline"
    >
      {@usage_count}
    </.link>
    """
  end

  def render_actions_column(assigns, row, _) do
    assigns = Map.merge(assigns, %{platform_instance_id: row.id})

    ~H"""
    <.link
      href={~p"/admin/external_tools/#{@platform_instance_id}/details"}
      class="w-20 text-center text-sm font-semibold leading-none h-7 rounded-lg shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] outline outline-1 outline-offset-[-1px] inline-flex justify-center items-center"
    >
      Details
    </.link>
    """
  end
end
