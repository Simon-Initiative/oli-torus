defmodule OliWeb.Resources.PagesTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Resources.Revision
  alias OliWeb.Curriculum.Actions
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def new(pages, project, ctx, child_to_parent) do
    column_specs = [
      %ColumnSpec{name: :title, label: "Title", render_fn: &__MODULE__.render_title_column/3},
      %ColumnSpec{
        name: :page_type,
        label: "Type"
      },
      %ColumnSpec{
        name: :graded,
        label: "Scoring",
        render_fn: &__MODULE__.render_graded_column/3
      },
      %ColumnSpec{
        name: :updated_at,
        label: "Last Updated",
        render_fn: &OliWeb.Common.Table.Common.render_date/3
      },
      %ColumnSpec{
        name: :curriculum,
        label: "Curriculum",
        render_fn: &__MODULE__.render_curriculum_column/3,
        sortable: false
      },
      %ColumnSpec{
        name: :actions,
        label: "Actions",
        render_fn: &__MODULE__.render_actions_column/3,
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

  def render_title_column(
        assigns,
        %Revision{
          slug: slug,
          title: title
        },
        _
      ) do
    assigns = Map.merge(assigns, %{slug: slug, title: title})

    ~H"""
    <a href={Routes.resource_path(OliWeb.Endpoint, :edit, @project_slug, @slug)}>
      {@title}
    </a>
    """
  end

  def render_curriculum_column(
        assigns,
        %Revision{
          resource_id: resource_id
        },
        _
      ) do
    parent = Map.get(assigns.child_to_parent, resource_id)
    assigns = Map.merge(assigns, %{parent: parent})

    ~H"""
    <%= if @parent !== nil do %>
      <a href={Routes.container_path(OliWeb.Endpoint, :index, @project_slug, @parent.slug)}>
        {@parent.title}
      </a>
    <% end %>
    """
  end

  def render_graded_column(_, %Revision{graded: true}, _), do: "Scored"
  def render_graded_column(_, %Revision{graded: false}, _), do: "Practice"

  def render_actions_column(_, %Revision{} = revision, _) do
    assigns = %{child: revision}

    ~H"""
    <Actions.render child={@child} />
    """
  end
end
