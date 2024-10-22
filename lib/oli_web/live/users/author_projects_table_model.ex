defmodule OliWeb.Users.AuthorProjectsTableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.FormatDateTime

  def new(projects, ctx) do
    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "TITLE",
        render_fn: &__MODULE__.render_title_column/3,
        th_class: "whitespace-nowrap"
      },
      %ColumnSpec{
        name: :role,
        label: "ROLE",
        render_fn: &__MODULE__.render_role_column/3,
        th_class: "whitespace-nowrap"
      },
      %ColumnSpec{
        name: :created_at,
        label: "DATE CREATED",
        render_fn: &__MODULE__.render_date_created_column/3,
        th_class: "whitespace-nowrap"
      },
      %ColumnSpec{
        name: :most_recent_edit,
        label: "MOST RECENT EDIT",
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
      <%= @title %>
    </a>
    """
  end

  def render_role_column(assigns, project, _) do
    case project.role do
      "owner" ->
        ~H"""
        <span class="badge badge-primary">Owner</span>
        """

      "contributor" ->
        ~H"""
        <span class="badge badge-dark">Collaborator</span>
        """
    end
  end

  def render_date_created_column(assigns, project, _) do
    assigns = Map.merge(assigns, %{date_created: project.created_at})

    ~H"""
    <%= parse_datetime(@date_created, @ctx) %>
    """
  end

  def render_most_recent_edit_column(assigns, project, _) do
    assigns = Map.merge(assigns, %{most_recent_edit: project.most_recent_edit})

    ~H"""
    <%= parse_datetime(@most_recent_edit, @ctx) %>
    """
  end

  defp parse_datetime(nil, _ctx), do: ""

  defp parse_datetime(datetime, ctx) do
    datetime
    |> FormatDateTime.convert_datetime(ctx)
    |> Timex.format!("{Mshort}. {0D}, {YYYY} - {h12}:{m} {AM}")
  end
end
