defmodule OliWeb.Workspaces.CourseAuthor.Publish.ActiveSectionsTableModel do
  use Phoenix.Component

  alias OliWeb.Common.{SessionContext, Utils}
  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}

  def new(%SessionContext{} = ctx, sections, project) do
    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "Title"
      },
      %ColumnSpec{
        name: :section_project_publications,
        label: "Current Publication",
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :creator,
        label: "Creator",
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :instructors,
        label: "Instructors",
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :base_project_id,
        label: "Relationship Type",
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :start_date,
        label: "Start Date",
        render_fn: &Common.render_date/3,
        sort_fn: &Common.sort_date/2
      },
      %ColumnSpec{
        name: :end_date,
        label: "End Date",
        render_fn: &Common.render_date/3,
        sort_fn: &Common.sort_date/2
      }
    ]

    SortableTableModel.new(
      rows: sections,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{ctx: ctx, project: project}
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
    case section.creator do
      nil -> "Creator not found"
      creator -> process_name(creator)
    end
  end

  def custom_render(_assigns, section, %ColumnSpec{name: :instructors}) do
    case section.instructors do
      instructors when is_list(instructors) and length(instructors) > 0 ->
        instructors |> Enum.map(&process_name/1) |> Enum.join("; ")

      _ ->
        "Instructors not found"
    end
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  defp process_name(user_name) do
    apply(Utils, :name, String.split(user_name, "|"))
  end
end
