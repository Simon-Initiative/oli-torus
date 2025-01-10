defmodule OliWeb.Workspaces.CourseAuthor.Datasets.DatasetsTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(rows, indclude_admin_fields? \\ false) do

    standard_columns = [
      %ColumnSpec{
        name: :status,
        label: "Status",
        render_fn: &render_status/3
      },
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
        label: "Details",
        render_fn: &render_config/3
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

  defp render_config(assigns, job, _a) do

    assigns = Map.merge(assigns, %{job: job})

    ~H"""
    <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Workspaces.CourseAuthor.DatasetDetailsLive, @job.project_slug, @job.id)}>
      Details
    </a>
    """
  end

  defp render_status(assigns, job, _a) do

    assigns = Map.merge(assigns, %{job: job})

    ~H"""
    <div class={badge_class(@job.status)}>
      <%= @job.status %>
    </div>
    """
  end

  defp render_project(assigns, job, _) do

    assigns = Map.merge(assigns, %{job: job})

    ~H"""
    <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Workspaces.CourseAuthor.OverviewLive, @job.project_slug)}>
      <%= @job.project_title %>
    </a>
    """
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  defp badge_class(status) do
    case status do
      :submitted -> "badge badge-info"
      :scheduled -> "badge badge-info"
      :running -> "badge badge-primary"
      :success -> "badge badge-success"
      :pending -> "badge badge-info"
      :failed -> "badge badge-danger"
      :cancelling -> "badge badge-warning"
      :cancelled -> "badge badge-warning"
      :queued -> "badge badge-info"
    end
  end
end
