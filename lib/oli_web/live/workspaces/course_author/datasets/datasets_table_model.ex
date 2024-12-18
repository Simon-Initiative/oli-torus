defmodule OliWeb.Workspaces.CourseAuthor.Datasets.DatasetsTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(rows, indclude_admin_fields? \\ false) do

    standard_columns = [
      %ColumnSpec{
        name: :job_type,
        label: "Type"
      },
      %ColumnSpec{
        name: :inserted_at,
        label: "Started"
      },
      %ColumnSpec{
        name: :finished_on,
        label: "Finished"
      },
      %ColumnSpec{
        name: :initiator_email,
        label: "Started By"
      },
      %ColumnSpec{
        name: :configuration,
        label: "Details"
      }
    ]

    admin_columns = [
      %ColumnSpec{
        name: :application_id,
        label: "App Id"
      },
      %ColumnSpec{
        name: :job_run_id,
        label: "Job Run Id"
      },
      %ColumnSpec{
        name: :job_id,
        label: "Job Id"
      },
      %ColumnSpec{
        name: :project_title,
        label: "Project",
        render_fn: &render_project/3
      }
    ]

    columns = if indclude_admin_fields? do
      admin_columns ++ standard_columns
    else
      standard_columns
    end

    SortableTableModel.new(
      rows: rows,
      column_specs: columns,
      event_suffix: "",
      id_field: [:id],
      data: %{}
    )
  end

  defp render_project(_data, row, assigns) do
    ~H"""
    <a href={Routes.live_path(OliWeb.Projects.OverviewLive, @row.project_slug)}>
      <%= @row.project_title %>
    </a>
    """
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
