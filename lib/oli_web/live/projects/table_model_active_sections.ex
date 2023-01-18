defmodule OliWeb.Projects.TableModelActiveSections do
  use Surface.LiveComponent

  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(%SessionContext{} = context, sections, project) do
    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "Title"
      },
      %ColumnSpec{
        name: :blueprint_id,
        label: "Type",
        render_fn: &__MODULE__.custom_render/3
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

  def custom_render(assigns, section, %ColumnSpec{name: name}) do
    case name do
      :section_project_publications ->
        %{edition: edition, major: major, minor: minor} =
          List.first(section.section_project_publications).publication

        ~F"""
          <span class="badge badge-primary">{"v#{edition}.#{major}.#{minor}"}</span>
        """

      :base_project_id ->
        if section.base_project_id == assigns.project.id, do: "Base Project", else: "Remixed"

      :blueprint_id ->
        if is_nil(section.blueprint_id), do: "Enrollable", else: "Blueprint"
    end
  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
