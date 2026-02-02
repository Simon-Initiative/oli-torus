defmodule OliWeb.Users.AuthorProjectsTableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Common.Utils

  def new(projects, ctx) do
    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "Title",
        render_fn: &__MODULE__.render_title_column/3,
        th_class: "whitespace-nowrap"
      },
      %ColumnSpec{
        name: :role,
        label: "Role",
        render_fn: &__MODULE__.render_role_column/3,
        th_class: "whitespace-nowrap"
      },
      %ColumnSpec{
        name: :created_at,
        label: "Date Created",
        render_fn: &__MODULE__.render_date_created_column/3,
        th_class: "whitespace-nowrap"
      },
      %ColumnSpec{
        name: :most_recent_edit,
        label: "Most Recent Edit",
        render_fn: &__MODULE__.render_most_recent_edit_column/3,
        th_class: "whitespace-nowrap"
      }
    ]

    SortableTableModel.new(
      rows: projects,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        ctx: ctx
      }
    )
  end

  def render_title_column(assigns, project, _) do
    assigns = Map.merge(assigns, %{title: project.title, slug: project.slug})

    ~H"""
    <a href={~p"/workspaces/course_author/#{@slug}/overview"}>
      {@title}
    </a>
    """
  end

  def render_role_column(assigns, project, _) do
    {bg_color, text_color} =
      case project.role do
        "contributor" -> {"bg-Fill-Accent-fill-accent-green-bold", "text-Text-text-white"}
        "owner" -> {"bg-Fill-Accent-fill-accent-blue-bold", "text-Text-text-white"}
        _ -> {"bg-Fill-Chip-Gray", "text-Text-Chip-Gray"}
      end

    label =
      case project.role do
        "owner" -> "Owner"
        "contributor" -> "Collaborator"
        other -> other
      end

    assigns =
      Map.merge(assigns, %{
        label: label,
        bg_color: bg_color,
        text_color: text_color
      })

    ~H"""
    <span class={[
      "inline-flex items-center rounded-full shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] px-3 py-1 text-sm font-normal",
      @bg_color,
      @text_color
    ]}>
      {@label}
    </span>
    """
  end

  def render_date_created_column(assigns, project, _) do
    assigns = Map.merge(assigns, %{date_created: project.created_at})

    ~H"""
    {parse_datetime(@date_created, @ctx)}
    """
  end

  def render_most_recent_edit_column(assigns, project, _) do
    assigns = Map.merge(assigns, %{most_recent_edit: project.most_recent_edit})

    ~H"""
    {Utils.render_relative_date(%{most_recent_edit: @most_recent_edit}, :most_recent_edit, @ctx)}
    """
  end

  defp parse_datetime(nil, _ctx), do: ""

  defp parse_datetime(datetime, ctx) do
    datetime
    |> FormatDateTime.convert_datetime(ctx)
    |> Timex.format!("{Mshort}. {0D}, {YYYY} - {h12}:{m} {AM}")
  end
end
