defmodule OliWeb.Insights.PageTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  use Phoenix.Component

  import OliWeb.Live.Insights.Common
  alias OliWeb.Router.Helpers, as: Routes

  def new(rows, project_slug, ctx) do
    SortableTableModel.new(
      rows: rows,
      column_specs: [
        %ColumnSpec{
          name: :title,
          label: "Page",
          render_fn: &__MODULE__.render_title/3
        },
        %ColumnSpec{
          name: :num_attempts,
          label: "# Attempts"
        },
        %ColumnSpec{
          name: :num_first_attempts,
          label: "# First Attempts"
        },
        %ColumnSpec{
          name: :first_attempt_correct,
          label: "First Attempt Correct%",
          render_fn: &render_percentage/3
        },
        %ColumnSpec{
          name: :eventually_correct,
          label: "Eventually Correct%",
          render_fn: &render_percentage/3
        },
        %ColumnSpec{
          name: :relative_difficulty,
          label: "Relative Difficulty",
          render_fn: &render_float/3
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{
        ctx: ctx,
        project_slug: project_slug
      }
    )
  end

  def render_title(%{project_slug: project_slug}, row, assigns) do
    assigns = Map.put(assigns, :project_slug, project_slug)
    assigns = Map.put(assigns, :row, row)

    ~H"""
    <a href={Routes.resource_path(OliWeb.Endpoint, :edit, @project_slug, @row.slug)}>
      {@row.title}
    </a>
    """
  end

  def render_type(%{graded: graded}, _row, assigns) do
    assigns = assign(assigns, :graded, graded)

    case assigns.graded do
      true -> "Graded"
      false -> "Practice"
    end
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
