defmodule OliWeb.Projects.ActiveSectionsTableModel do
  use Phoenix.Component

  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.Utils
  alias Oli.Authoring.Publishing

  def new(%SessionContext{} = ctx, sections, project) do
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
        name: :creator,
        label: "Creator",
        render_fn: &__MODULE__.custom_render/3
      },
      %ColumnSpec{
        name: :instructors,
        label: "Instructors",
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
        ctx: ctx,
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

    assigns = Map.merge(assigns, %{edition: edition, major: major, minor: minor})

    ~H"""
    <span class="badge badge-primary"><%= Utils.render_version(@edition, @major, @minor) %></span>
    """
  end

  def custom_render(assigns, section, %ColumnSpec{name: :base_project_id}),
    do: if(section.base_project_id == assigns.project.id, do: "Base Project", else: "Remixed")

  def custom_render(_assigns, section, %ColumnSpec{name: :creator}) do
    case Publishing.find_oldest_enrolled_instructor(section) do
      nil -> "Creator not found"
      user -> Utils.name(user)
    end
  end

  def custom_render(_assigns, section, %ColumnSpec{name: :instructors}) do
    case Publishing.find_instructors_enrolled_in(section) do
      [] -> "Instructors not found"
      instructors -> Enum.map(instructors, &Utils.name/1) |> Enum.join("; ")
    end
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
