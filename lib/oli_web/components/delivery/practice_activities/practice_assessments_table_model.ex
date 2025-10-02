defmodule OliWeb.Delivery.PracticeActivities.PracticeAssessmentsTableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Icons
  alias OliWeb.Delivery.InstructorDashboard.HTMLComponents

  def new(assessments, ctx, target) do
    column_specs = [
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
      },
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
            title: "Students Progress",
            info_tooltip: "Average progress on this page across all students."
          }),
        render_fn: &render_students_completion_column/3,
        td_class: "!pl-10"
      }
    ]

    SortableTableModel.new(
      rows: assessments,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:resource_id],
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
        slug: assessment.slug,
        container_label: assessment.container_label,
        resource_id: assessment.resource_id,
        has_lti_activity: assessment.has_lti_activity,
        section_slug: assigns.ctx.section.slug
      })

    ~H"""
    <%= if @has_lti_activity do %>
      <div
        id={"lti_title_#{@resource_id}"}
        phx-hook="GlobalTooltip"
        data-tooltip="<div>LTI 1.3 External Tool</div>"
        data-tooltip-align="left"
        class="flex items-center gap-2"
      >
        <Icons.plug />
        <.question_text
          container_label={@container_label}
          title={@title}
          slug={@slug}
          section_slug={@section_slug}
        />
      </div>
    <% else %>
      <.question_text
        container_label={@container_label}
        title={@title}
        slug={@slug}
        section_slug={@section_slug}
      />
    <% end %>
    """
  end

  defp question_text(assigns) do
    ~H"""
    <div class="pl-0 pr-4 flex flex-col gap-y-1 py-2">
      <%= if @container_label do %>
        <span class="text-Text-text-high text-sm font-bold leading-none">{@container_label}</span>
      <% end %>
      <span>
        <a
          href={~p"/sections/#{@section_slug}/preview/page/#{@slug}"}
          class="text-Text-text-link text-base font-medium leading-normal"
        >
          {@title}
        </a>
      </span>
    </div>
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
    <div class={"text-Text-text-high text-sm font-bold leading-none #{if @students_completion < 0.40, do: "text-Text-text-danger"}"}>
      {format_value(@students_completion)}
    </div>
    """
  end

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
