defmodule OliWeb.CommunityLive.Invitation do
  use OliWeb, :html

  attr(:list_id, :string, required: true)
  attr(:invite, :any, required: true)
  attr(:remove, :any, required: true)
  attr(:suggest, :any)
  attr(:collaborators, :any, default: [])
  attr(:matches, :any, default: [])
  attr(:to_invite, :any, default: :collaborator)
  attr(:search_field, :any, default: :email)
  attr(:main_fields, :list, default: [primary: :name, secondary: :email])
  attr(:placeholder, :string, default: "collaborator@example.edu")
  attr(:button_text, :string, default: "Send invite")
  attr(:allow_removal, :boolean, default: true)

  def render(assigns) do
    ~H"""
    <.form for={@to_invite} phx-submit={@invite} phx-change={@suggest} class="d-flex mb-5">
      <div class="w-100">
        <.input
          name={@search_field}
          value=""
          class="form-control"
          placeholder={@placeholder}
          autocomplete="off"
          list={@list_id}
        />
        <datalist id={@list_id}>
          <%= for match <- @matches do %>
            <option value={Map.get(match, @search_field)}>
              <%= Map.get(match, @main_fields[:primary]) %>
            </option>
          <% end %>
        </datalist>
      </div>
      <button class="form-button btn btn-outline-primary" type="submit"><%= @button_text %></button>
    </.form>
    <%= for collaborator <- @collaborators do %>
      <div class="d-flex justify-content-between align-items-center mb-3">
        <div class="d-flex flex-column">
          <div><%= Map.get(collaborator, @main_fields[:primary]) %></div>
          <div class="text-muted"><%= Map.get(collaborator, @main_fields[:secondary]) %></div>
        </div>
        <div :if={@allow_removal} class="user-actions">
          <button
            class="btn btn-link text-danger"
            phx-click={@remove}
            phx-value-collaborator-id={collaborator.id}
          >
            Remove
          </button>
        </div>
      </div>
    <% end %>
    """
  end
end
