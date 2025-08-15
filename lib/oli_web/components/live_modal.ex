defmodule OliWeb.Components.LiveModal do
  use Phoenix.LiveComponent

  def mount(socket) do
    {:ok, assign(socket, :show, false)}
  end

  def update(assigns, socket) do
    {:ok,
     assign(
       socket,
       Map.merge(assigns, %{
         title: assigns[:title] || nil,
         class: assigns[:class] || "",
         on_confirm: assigns[:on_confirm],
         on_confirm_label: assigns[:on_confirm_label] || "Confirm",
         on_confirm_disabled: assigns[:on_confirm_disabled] || false,
         on_cancel: assigns[:on_cancel],
         on_cancel_label: assigns[:on_cancel_label] || "Cancel",
         show_actions: !is_nil(assigns[:on_confirm]) || !is_nil(assigns[:on_cancel])
       })
     )}
  end

  attr :title, :string
  attr :class, :string, default: ""
  attr :on_confirm, :string
  attr :on_confirm_disabled, :boolean, default: false
  attr :on_confirm_label, :string, default: "Confirm"
  attr :on_cancel, :string
  attr :on_cancel_label, :string, default: "Cancel"
  attr :show_actions, :boolean, default: false

  def render(assigns) do
    ~H"""
    <div phx-hook="LiveModal" id={@id}>
      <%= if @show do %>
        <div
          id={"#{@id}_backdrop"}
          class="fixed h-full w-full z-50 bg-black/20 left-0 top-0 flex items-center justify-center"
        >
          <div class={"bg-white dark:bg-neutral-800 rounded max-w-xl w-full p-4 #{@class}"}>
            <div class={"flex items-cent #{if assigns[:title], do: "justify-between", else: "justify-end"} p-4"}>
              <%= if @title do %>
                <h5>{@title}</h5>
              <% end %>
              <button phx-target={@myself} phx-click="close">
                <i class="fa-solid fa-xmark" />
              </button>
            </div>
            {render_slot(@inner_block)}
            <%= if @show_actions do %>
              <div class="flex items-center justify-end gap-2 mt-12">
                <%= if @on_cancel do %>
                  <button phx-click={@on_cancel} class="torus-button secondary">
                    {@on_cancel_label}
                  </button>
                <% end %>
                <%= if @on_confirm do %>
                  <button
                    disabled={@on_confirm_disabled}
                    phx-click={@on_confirm}
                    class="torus-button primary"
                  >
                    {@on_confirm_label}
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("open", _, socket) do
    {:noreply, assign(socket, :show, true)}
  end

  def handle_event("close", _, socket) do
    {:noreply, assign(socket, :show, false)}
  end
end
