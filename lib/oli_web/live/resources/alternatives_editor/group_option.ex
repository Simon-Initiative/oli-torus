defmodule OliWeb.Resources.AlternativesEditor.GroupOption do
  use Phoenix.Component

  import OliWeb.Common.Components

  def group_option(assigns) do
    ~H"""
    <li class="list-group-item">
      <div class="d-flex flex-row align-items-center">
        <div>{@option["name"]}</div>
        <div class="flex-grow-1"></div>
        <%= if @show_actions do %>
          <.icon_button
            class="mr-1"
            icon="fa-solid fa-pencil"
            on_click="show_edit_option_modal"
            values={[
              "phx-value-resource-id": @group.resource_id,
              "phx-value-option-id": @option["id"]
            ]}
          />
          <.icon_button
            class="danger-icon-button mr-1"
            icon="fa-solid fa-trash"
            on_click="show_delete_option_modal"
            values={[
              "phx-value-resource-id": @group.resource_id,
              "phx-value-option-id": @option["id"]
            ]}
          />
        <% end %>
      </div>
    </li>
    """
  end
end
