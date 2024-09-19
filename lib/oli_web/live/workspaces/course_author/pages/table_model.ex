defmodule OliWeb.Workspaces.CourseAuthor.Pages.TableModel do
  use Phoenix.Component

  alias Oli.Resources.Revision
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Curriculum.Actions
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Workspaces.CourseAuthor.{CurriculumLive, EditorLive}

  def render(assigns) do
    ~H"""
    <div></div>
    """
  end

  def new(pages, project, ctx, child_to_parent) do
    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "Title",
        render_fn: &render_title_column/3
      },
      %ColumnSpec{
        name: :page_type,
        label: "Type"
      },
      %ColumnSpec{
        name: :graded,
        label: "Scoring",
        render_fn: &render_graded_column/3
      },
      %ColumnSpec{
        name: :updated_at,
        label: "Last Updated",
        render_fn: &OliWeb.Common.Table.Common.render_date/3
      },
      %ColumnSpec{
        name: :curriculum,
        label: "Curriculum",
        render_fn: &render_curriculum_column/3,
        sortable: false
      },
      %ColumnSpec{
        name: :actions,
        label: "Actions",
        render_fn: &render_actions_column/3,
        sortable: false,
        th_class: "w-4",
        td_class: "w-4"
      }
    ]

    SortableTableModel.new(
      rows: pages,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        ctx: ctx,
        project_slug: project.slug,
        child_to_parent: child_to_parent
      }
    )
  end

  defp render_title_column(assigns, %Revision{slug: slug, title: title}, _) do
    assigns = Map.merge(assigns, %{slug: slug, title: title})
    IO.inspect(assigns, label: "ASSIGNS")

    ~H"""
    <a href={Routes.live_path(OliWeb.Endpoint, EditorLive, @project_slug, @slug)}>
      <%= @title %>
    </a>
    """
  end

  defp render_curriculum_column(assigns, %Revision{resource_id: resource_id}, _) do
    parent = Map.get(assigns.child_to_parent, resource_id)
    assigns = Map.merge(assigns, %{parent: parent})

    ~H"""
    <%= if @parent do %>
      <a href={Routes.live_path(OliWeb.Endpoint, CurriculumLive, @project_slug, @parent.slug)}>
        <%= @parent.title %>
      </a>
    <% end %>
    """
  end

  defp render_graded_column(_, %Revision{graded: true}, _), do: "Scored"
  defp render_graded_column(_, %Revision{graded: false}, _), do: "Practice"

  defp render_actions_column(_, %Revision{} = revision, _) do
    assigns = %{child: revision}

    ~H"""
    <Actions.render child={@child} />
    """
  end
end
