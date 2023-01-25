defmodule OliWeb.Projects.ActiveSectionsTableModel do
  use Surface.LiveComponent

  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.Utils

  def new(%SessionContext{} = context, sections, project) do
    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "Title"
      },
      %ColumnSpec{
        name: :section_project_publications,
        label: "Current Publication",
        render_fn: &__MODULE__.custom_render/3
      },
      %ColumnSpec{
        name: :base_project_id,
        label: "Relationship Type",
        render_fn: &__MODULE__.custom_render/3
      },
      %ColumnSpec{
        name: :start_date,
        label: "Start Date",
        render_fn: &OliWeb.Common.Table.Common.render_date/3,
        sort_fn: &OliWeb.Common.Table.Common.sort_date/2
      },
      %ColumnSpec{
        name: :end_date,
        label: "End Date",
        render_fn: &OliWeb.Common.Table.Common.render_date/3,
        sort_fn: &OliWeb.Common.Table.Common.sort_date/2
      }
    ]

    SortableTableModel.new(
      rows: sections,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        context: context,
        project: project
      }
    )
  end

  def custom_render(assigns, section, %ColumnSpec{name: :section_project_publications}) do
    %{edition: edition, major: major, minor: minor} =
      section
      |> Map.get(:section_project_publications)
      |> hd()
      |> Map.get(:publication)

    ~F"""
      <span class="badge badge-primary">{Utils.render_version(edition, major, minor)}</span>
    """
  end

  def custom_render(assigns, section, %ColumnSpec{name: :base_project_id}),
    do: if(section.base_project_id == assigns.project.id, do: "Base Project", else: "Remixed")

  def render(assigns) do
    ~F"""
      <div>nothing</div>
    """
  end
end
