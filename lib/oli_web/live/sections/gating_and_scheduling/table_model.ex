defmodule OliWeb.Delivery.Sections.GatingAndScheduling.TableModel do
  use Surface.LiveComponent

  import OliWeb.ViewHelpers

  alias OliWeb.Router.Helpers, as: Routes
  alias Surface.Components.{Link}
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias Oli.Resources.Revision
  alias Oli.Delivery.Gating.{GatingCondition, GatingConditionData}

  def render(assigns) do
    ~F"""
    <div></div>
    """
  end

  def new(gating_condition_rows, section) do
    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "Resource",
        render_fn: &__MODULE__.render_resource_column/3
      },
      %ColumnSpec{
        name: :type,
        label: "Type",
        render_fn: &__MODULE__.render_type_column/3
      },
      %ColumnSpec{
        name: :details,
        label: "Details",
        render_fn: &__MODULE__.render_details_column/3
      },
      %ColumnSpec{
        name: :user,
        label: "User",
        render_fn: &__MODULE__.render_user_column/3
      },
      %ColumnSpec{
        name: :actions,
        label: "Actions",
        render_fn: &__MODULE__.render_actions_column/3
      }
    ]

    {:ok, model} =
      SortableTableModel.new(
        rows: gating_condition_rows,
        column_specs: column_specs,
        event_suffix: "",
        id_field: [:id]
      )

    {:ok, Map.put(model, :data, %{section_slug: section.slug})}
  end

  def render_resource_column(
        assigns,
        %GatingCondition{
          revision: %Revision{title: title}
        },
        _
      ) do
    ~F"""
    {title}
    """
  end

  def render_type_column(
        assigns,
        %GatingCondition{
          type: type
        },
        _
      ) do
    ~F"""
    {type |> Atom.to_string() |> String.capitalize()}
    """
  end

  def render_details_column(
        assigns,
        %GatingCondition{
          type: :schedule,
          data: %GatingConditionData{
            start_datetime: start_datetime,
            end_datetime: end_datetime
          }
        },
        _
      ) do
    local_tz = Map.get(assigns, :local_tz)

    ~F"""
      <div :if={start_datetime}>
        Start: {dt(start_datetime, local_tz: local_tz)}
      </div>
      <div :if={end_datetime}>
        End: {dt(end_datetime, local_tz: local_tz)}
      </div>
    """
  end

  def render_user_column(
        assigns,
        %GatingCondition{
          user_id: user_id,
          user: user
        },
        _
      ) do
    ~F"""
      <div :if={user_id}>
        {user.name}
      </div>
    """
  end

  def render_actions_column(
        %{section_slug: section_slug} = assigns,
        %GatingCondition{
          id: id
        },
        _
      ) do
    ~F"""
      <div>
        <Link to={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.GatingAndScheduling.Edit, section_slug, id)} class="btn btn-sm btn-primary">Edit</Link>
      </div>
    """
  end
end
