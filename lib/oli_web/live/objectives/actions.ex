defmodule OliWeb.Objectives.Actions do


  use Phoenix.LiveComponent
  use Phoenix.HTML

  def render(assigns) do
    ~L"""

    <div style="min-width: 50px">
      <div phx-update="ignore">
        <button
          title="Edit the selected objecive"
          id="action_edit"
          <%= if @selected != nil do "" else "disabled" end %>
          data-toggle="tooltip"
          class="ml-1 btn btn-sm btn-outline-primary"
          phx-click="modify"
          phx-value-slug="<%= @selected %>"
        >
        <i class="fas fa-pencil-alt fa-lg"></i>
        </button>

        <button
          title="Add a new child objective"
          id="action_sub"
          data-toggle="tooltip"
          <%= if @is_root? and @selected != nil do "" else "disabled" end %>
          class="ml-1 btn btn-sm btn-outline-primary"
          phx-click="add_sub"
          phx-value-slug="add_sub_<%= @selected %>"
        >
        <i class="fas fa-plus fa-lg"></i>
        </button>

        <button
          title="Delete the selected objective"
          id="action_delete"
          <%= if @selected != nil and @can_delete? do "" else "disabled" end %>
          data-toggle="tooltip"
          phx-click="prepare_delete"
          data-backdrop="static"
          data-keyboard="false"
          class="ml-1 btn btn-sm btn-outline-danger"
        >
        <i class="fas fa-trash fa-lg"></i>
        </button>
      </div>
    </div>

    """

  end

end
