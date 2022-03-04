defmodule OliWeb.Delivery.Sections.GatingAndScheduling.TableModel do
  use OliWeb, :surface_component

  alias Surface.Components.{Link}
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias Oli.Resources.Revision
  alias Oli.Delivery.Gating.{GatingCondition, GatingConditionData}
  alias OliWeb.Common.SessionContext

  def render(assigns) do
    ~F"""
    <div></div>
    """
  end

  def new(%SessionContext{} = context, gating_condition_rows, section, is_parent_gate?) do
    resource_column = %ColumnSpec{
      name: :title,
      label: "Resource",
      render_fn: &__MODULE__.render_resource_column/3
    }

    type_column = %ColumnSpec{
      name: :type,
      label: "Type",
      render_fn: &__MODULE__.render_type_column/3
    }

    details_column = %ColumnSpec{
      name: :details,
      label: "Details",
      render_fn: &__MODULE__.render_details_column/3
    }

    user_column = %ColumnSpec{
      name: :user,
      label: "User",
      render_fn: &__MODULE__.render_user_column/3
    }

    column_specs =
      if is_parent_gate? do
        [resource_column, type_column, details_column]
      else
        [user_column, type_column, details_column]
      end

    SortableTableModel.new(
      rows: gating_condition_rows,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        section_slug: section.slug,
        context: context
      }
    )
  end

  def render_resource_column(
        %{section_slug: section_slug} = assigns,
        %GatingCondition{
          revision: %Revision{title: title},
          id: id
        },
        _
      ) do
    ~F"""
    <Link to={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.GatingAndScheduling.Edit, section_slug, id)}>{title}</Link>
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
        %{context: context} = assigns,
        %GatingCondition{
          type: :schedule,
          data: %GatingConditionData{
            start_datetime: start_datetime,
            end_datetime: end_datetime
          }
        },
        _
      ) do
    ~F"""
      <div :if={start_datetime}>
        <b>Start:</b> {date(start_datetime, context: context, precision: :minutes)}
      </div>
      <div :if={end_datetime}>
        <b>End:</b> {date(end_datetime, context: context, precision: :minutes)}
      </div>
    """
  end

  def render_details_column(
        %{context: _} = assigns,
        %GatingCondition{
          type: :started
        },
        _
      ) do
    ~F"""
    <div>
      A resource must be started
    </div>
    """
  end

  def render_details_column(
        %{context: _} = assigns,
        %GatingCondition{
          type: :finished,
          data: %GatingConditionData{
            minimum_percentage: nil
          }
        },
        _
      ) do
    ~F"""
    <div>
      A resource must be completed
    </div>
    """
  end

  def render_details_column(
        %{context: _} = assigns,
        %GatingCondition{
          type: :finished
        },
        _
      ) do
    ~F"""
    <div>
      A resource must be completed with a minimum score
    </div>
    """
  end

  def render_details_column(
        %{context: _context} = assigns,
        %GatingCondition{
          type: :always_open
        },
        _
      ) do
    ~F"""
      <div>
        Allows access to this resource
      </div>
    """
  end

  def render_user_column(
        %{section_slug: section_slug} = assigns,
        %GatingCondition{
          user_id: user_id,
          user: user,
          id: id
        },
        _
      ) do
    ~F"""
      <div :if={user_id}>
        <Link to={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.GatingAndScheduling.Edit, section_slug, id)}>{user.name}</Link>

      </div>
    """
  end
end
