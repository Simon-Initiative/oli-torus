defmodule OliWeb.Qa.WarningFilter do

  use Phoenix.LiveComponent
  import OliWeb.Qa.Utils

  def render(assigns) do
    ~L"""
    <div class="mr-2">
      <div class="input-group mb-3 w-0">
        <div class="input-group-prepend">
          <div class="input-group-text">
            <input class="warning-filter" id="filter-<%= @type %>"
              phx-click="filter" phx-value-type="<%= @type %>"
              <%= if @active do "checked" else "" end %>
              type="checkbox"
              style="width: 20px; height: 20px;"
              aria-label="Checkbox for <%= @type %>">
          </div>
        </div>
        <span class="form-control d-flex align-items-center">
          <span class="badge badge-info"><%= length(@warnings) %></span>&nbsp;
          <%= title_case(@type) %>
        </span>
      </div>
    </div>
    """
  end
end
