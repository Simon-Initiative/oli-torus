defmodule OliWeb.Components.EmailList do
  use Phoenix.Component

  attr :id, :string, required: true
  attr :emails_list, :list, required: true
  attr :invalid_emails, :list, required: true
  attr :on_update, :string, required: true
  attr :on_remove, :string, required: true
  attr :target, :string, required: false, default: nil

  attr :is_list_empty, :boolean, default: true
  attr :current_email, :string, default: ""

  def render(assigns) do
    assigns = assign(assigns, :is_list_empty, List.first(assigns.emails_list) == nil)

    ~H"""
    <div>
      <div
        id={@id}
        class="flex flex-wrap rounded-md border border-gray-300 p-4 gap-2 cursor-text"
        phx-hook="EmailList"
        phx-event={@on_update}
        phx-target-id={@target}
      >
        <div id="email-list-container">
          <%= for email <- @emails_list do %>
            <div class="rounded-md bg-gray-100 dark:bg-neutral-600 cursor-default p-2 shadow-md flex items-center gap-2 user-email max-h-80 scroll-y-overflow">
              <p>{email}</p>
              <button
                phx-click={@on_remove}
                phx-target={if @target, do: "##{@target}"}
                phx-value-email={email}
                class="close"
              >
                <i class="fa-solid fa-xmark mt-0" />
              </button>
            </div>
          <% end %>
        </div>
        <input
          placeholder={if @is_list_empty, do: "user@email.com", else: nil}
          class="p-2 outline-none"
          value={@current_email}
        />
      </div>
      <div class="text-sm text-rose-600 mt-2">
        <%= if !Enum.empty?(@invalid_emails) do %>
          Invalid emails below will not be included in the invitation.
        <% end %>
      </div>

      <div id="invalid-email-list-container" class="flex flex-wrap gap-2">
        <%= for email <- @invalid_emails do %>
          <div class="rounded-md bg-gray-100 dark:bg-neutral-600 cursor-default p-2 shadow-md flex items-center gap-2 user-email max-h-80 scroll-y-overflow">
            <p class="text-sm text-rose-600">{email}</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
