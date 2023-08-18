defmodule OliWeb.Components.EmailList do
  use Phoenix.Component

  attr :id, :string, required: true
  attr :users_list, :list, required: true
  attr :on_update, :string, required: true
  attr :on_remove, :string, required: true

  attr :is_list_empty, :boolean, default: true
  attr :current_user, :string, default: ""

  def render(assigns) do
    assigns = assign(assigns, :is_list_empty, List.first(assigns.users_list) == nil)

    ~H"""
      <div id={@id} class="flex flex-wrap rounded-md border border-gray-300 p-4 gap-2 cursor-text" phx-hook="EmailList" phx-event={@on_update}>
        <%= for user <- @users_list do %>
          <div class="rounded-md bg-gray-100 cursor-default p-2 shadow-md flex items-center gap-2 user-email max-h-80 scroll-y-overflow">
            <p><%= user %></p>
            <button
              phx-click={@on_remove}
              phx-value-user={user}
              class="close"
            >
              <i class="fa-solid fa-xmark mt-0" />
            </button>
          </div>
        <% end %>
        <input placeholder={if @is_list_empty, do: "user@email.com", else: nil} class="p-2 outline-none" value={@current_user} />
      </div>
    """
  end
end
