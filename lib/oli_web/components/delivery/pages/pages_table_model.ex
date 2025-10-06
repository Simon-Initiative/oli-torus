defmodule OliWeb.Components.Delivery.Pages.PagesTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Delivery.InstructorDashboard.HTMLComponents
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  def new(pages, ctx, active_tab, target) do
    column_specs =
      [
        %ColumnSpec{
          name: :order,
          label: "#",
          th_class: "w-2"
        },
        %ColumnSpec{
          name: :title,
          label: "Page Title",
          render_fn: &render_assessment_column/3,
          th_class: "pl-2"
        }
      ] ++
        if(active_tab == :scored_pages,
          do: [
            %ColumnSpec{
              name: :due_date,
              label: "Due Date",
              render_fn: &render_due_date_column/3
            }
          ],
          else: []
        ) ++
        [
          %ColumnSpec{
            name: :avg_score,
            label:
              HTMLComponents.render_label(%{
                title: "Avg Score",
                info_tooltip: "Average score across all student attempts on this page."
              }),
            render_fn: &render_avg_score_column/3,
            td_class: "!pl-10"
          },
          %ColumnSpec{
            name: :total_attempts,
            label:
              HTMLComponents.render_label(%{
                title: "Total Attempts",
                info_tooltip:
                  "Total number of attempts made by all students. Some students may have multiple attempts based on your course settings."
              }),
            render_fn: &render_attempts_column/3,
            td_class: "!pl-10"
          },
          %ColumnSpec{
            name: :students_completion,
            label:
              HTMLComponents.render_label(%{
                title: "Student Progress",
                info_tooltip: "Average progress on this page across all students."
              }),
            render_fn: &render_students_completion_column/3,
            td_class: "!pl-10"
          }
        ]

    SortableTableModel.new(
      rows: pages,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        ctx: ctx,
        target: target
      }
    )
  end

  def render_assessment_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        title: assessment.title,
        container_label: assessment.container_label,
        id: assessment.id,
        score_as_you_go: !assessment.batch_scoring
      })

    ~H"""
    <div class="pl-0 pr-4 flex flex-col gap-y-1 py-2">
      <%= if @container_label do %>
        <span class="text-Text-text-high text-sm font-bold leading-none">{@container_label}</span>
      <% end %>
      <a
        class="text-Text-text-link text-base font-medium leading-normal"
        href="#"
        phx-click={JS.push("paged_table_selection_change", target: @target)}
        phx-value-id={@id}
      >
        <%= if @score_as_you_go do %>
          <Icons.score_as_you_go />
        <% end %>
        {@title}
      </a>
    </div>
    """
  end

  def render_due_date_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        due_date: assessment.end_date,
        scheduling_type: assessment.scheduling_type
      })

    ~H"""
    {parse_due_date(@due_date, @ctx, @scheduling_type)}
    """
  end

  def render_avg_score_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{avg_score: assessment.avg_score})

    ~H"""
    <div class={"text-Text-text-high text-sm font-bold leading-none #{if @avg_score < 0.40, do: "text-Text-text-danger"}"}>
      {format_value(@avg_score)}
    </div>
    """
  end

  def render_attempts_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{total_attempts: assessment.total_attempts})

    ~H"""
    <div class="text-Text-text-high text-sm font-bold leading-none">
      {@total_attempts || "-"}
    </div>
    """
  end

  def render_students_completion_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        students_completion: assessment.students_completion,
        avg_score: assessment.avg_score
      })

    ~H"""
    <%= if @avg_score != nil do %>
      <div class={"text-Text-text-high text-sm font-bold leading-none #{if @students_completion < 0.40, do: "text-Text-text-danger"}"}>
        {format_value(@students_completion)}
      </div>
    <% else %>
      -
    <% end %>
    """
  end

  defp parse_due_date(datetime, ctx, :due_by) do
    if is_nil(datetime),
      do: "No due date",
      else:
        datetime
        |> FormatDateTime.convert_datetime(ctx)
        |> Timex.format!("{Mshort}. {0D}, {YYYY} - {h12}:{m} {AM}")
  end

  defp parse_due_date(_datetime, _ctx, _scheduling_type), do: "No due date"

  defp format_value(nil), do: "-"
  defp format_value(value), do: "#{parse_percentage(value)}%"

  defp parse_percentage(value) when is_integer(value) do
    value * 100
  end

  defp parse_percentage(value) when is_float(value) do
    {value, _} =
      Float.round(value * 100)
      |> Float.to_string()
      |> Integer.parse()

    value
  end
end
