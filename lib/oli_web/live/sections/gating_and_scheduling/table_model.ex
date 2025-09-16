defmodule OliWeb.Delivery.Sections.GatingAndScheduling.TableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.Utils
  alias Oli.Resources.Revision
  alias Oli.Delivery.Gating.{GatingCondition, GatingConditionData}
  alias OliWeb.Common.SessionContext
  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do
    ~H"""
    <div></div>
    """
  end

  def new(%SessionContext{} = ctx, gating_condition_rows, section, is_parent_gate?) do
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
        ctx: ctx
      }
    )
  end

  def render_resource_column(
        assigns,
        %GatingCondition{
          revision: %Revision{title: title},
          id: id
        },
        _
      ) do
    assigns = Map.merge(assigns, %{title: title, id: id})

    ~H"""
    <.link href={
      Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.GatingAndScheduling.Edit, @section_slug, @id)
    }>
      {@title}
    </.link>
    """
  end

  def render_type_column(
        assigns,
        %GatingCondition{
          type: type
        },
        _
      ) do
    assigns = Map.merge(assigns, %{type: type})

    ~H"""
    {@type |> Atom.to_string() |> String.capitalize()}
    """
  end

  def render_details_column(
        %{ctx: ctx} = assigns,
        %GatingCondition{
          type: :schedule,
          data:
            %GatingConditionData{
              start_datetime: start_datetime,
              end_datetime: end_datetime
            } = data
        },
        _
      ) do
    assigns =
      Map.merge(assigns, %{
        data: data,
        ctx: ctx,
        start_datetime: start_datetime,
        end_datetime: end_datetime
      })

    ~H"""
    <%= if @start_datetime do %>
      <div>
        <b>Start:</b> {Utils.render_precise_date(@data, :start_datetime, @ctx)}
      </div>
    <% end %>
    <%= if @end_datetime do %>
      <div>
        <b>End:</b> {Utils.render_precise_date(@data, :end_datetime, @ctx)}
      </div>
    <% end %>
    """
  end

  def render_details_column(
        %{ctx: _} = assigns,
        %GatingCondition{
          type: :started
        },
        _
      ) do
    ~H"""
    <div>
      A resource must be started
    </div>
    """
  end

  def render_details_column(
        %{ctx: _} = assigns,
        %GatingCondition{
          type: :finished,
          data: %GatingConditionData{
            minimum_percentage: nil
          }
        },
        _
      ) do
    ~H"""
    <div>
      A resource must be completed
    </div>
    """
  end

  def render_details_column(
        %{ctx: _} = assigns,
        %GatingCondition{
          type: :finished
        },
        _
      ) do
    ~H"""
    <div>
      A resource must be completed with a minimum score
    </div>
    """
  end

  def render_details_column(
        %{ctx: _} = assigns,
        %GatingCondition{
          type: :progress,
          data: %GatingConditionData{
            minimum_percentage: nil
          }
        },
        _
      ) do
    ~H"""
    <div>
      A resource must be completed
    </div>
    """
  end

  def render_details_column(
        %{ctx: _} = assigns,
        %GatingCondition{
          type: :progress
        },
        _
      ) do
    ~H"""
    <div>
      A resource must be completed with a minimum of progress
    </div>
    """
  end

  def render_details_column(
        %{ctx: _ctx} = assigns,
        %GatingCondition{
          type: :always_open
        },
        _
      ) do
    ~H"""
    <div>
      Allows access to this resource
    </div>
    """
  end

  def render_user_column(
        assigns,
        %GatingCondition{
          user_id: user_id,
          user: user,
          id: id
        },
        _
      ) do
    assigns = Map.merge(assigns, %{user_id: user_id, user: user, id: id})

    ~H"""
    <%= if @user_id do %>
      <div>
        <.link href={
          Routes.live_path(
            OliWeb.Endpoint,
            OliWeb.Sections.GatingAndScheduling.Edit,
            @section_slug,
            @id
          )
        }>
          {OliWeb.Common.Utils.name(@user)}
        </.link>
      </div>
    <% end %>
    """
  end
end
