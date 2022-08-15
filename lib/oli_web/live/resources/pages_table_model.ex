defmodule OliWeb.Resources.PagesTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Resources.Revision
  alias OliWeb.Curriculum.Actions
  use Surface.LiveComponent

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end

  def new(pages, project, context) do
    column_specs = [
      %ColumnSpec{name: :title, label: "Title", render_fn: &__MODULE__.render_title_column/3},
      %ColumnSpec{
        name: :page_type,
        label: "Type"
      },
      %ColumnSpec{
        name: :graded,
        label: "Graded",
        render_fn: &__MODULE__.render_graded_column/3
      },
      %ColumnSpec{
        name: :updated_at,
        label: "Last Updated",
        render_fn: &OliWeb.Common.Table.Common.render_date/3
      },
      %ColumnSpec{
        name: :actions,
        label: "",
        render_fn: &__MODULE__.render_actions_column/3
      }
    ]

    SortableTableModel.new(
      rows: pages,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        context: context,
        project_slug: project.slug
      }
    )
  end

  def render_title_column(
        assigns,
        %Revision{
          slug: slug,
          title: title
        },
        _
      ) do
    ~F"""
    <a href={Routes.resource_path(OliWeb.Endpoint, :edit, assigns.project_slug, slug)}>
      {title}
    </a>
    """
  end

  def render_graded_column(_, %Revision{graded: true}, _), do: "Graded"
  def render_graded_column(_, %Revision{graded: false}, _), do: "Practice"

  def render_actions_column(_, %Revision{} = revision, _) do
    live_component(Actions, child: revision, disable_move: true)
  end
end
