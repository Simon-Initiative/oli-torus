defmodule OliWeb.Common.TextSearch do
  use OliWeb, :live_component

  attr(:id, :string)
  attr(:reset, :string, default: "text_search_reset")
  attr(:change, :string, default: "text_search_change")
  attr(:placeholder, :string, default: "Search...")
  attr(:text, :string, default: "")
  attr(:event_target, :any, required: false, default: :live_view)
  attr(:tooltip, :string, required: false, default: nil)
  attr(:class, :string, default: "")

  def render(assigns) do
    ~H"""
    <div class={"input-group max-w-[350px] #{@class}"}>
      <i id={"#{@id}-icon"} class="absolute fa-solid fa-magnifying-glass pl-3 pt-3 h-4 w-4 "></i>
      <input
        id={"#{@id}-input"}
        type="text"
        class="h-9 w-full rounded border !pl-9 focus:ring-1 focus:ring-delivery-primary animate-none focus:outline-2 dark:bg-[#0F0D0F] dark:text-violet-100 text-base font-normal font-['Roboto']"
        placeholder={@placeholder}
        value={@text}
        phx-hook="TextInputListener"
        phx-hook-target={@event_target}
        phx-target={@event_target}
        phx-value-change={@change}
      />
      <%= if @text not in [nil, ""] do %>
        <div class="input-group-append">
          <button
            class="btn btn-outline-secondary"
            phx-click={@reset}
            phx-target={@event_target}
            phx-value-id={@id}
          >
            <i class="fas fa-times"></i>
          </button>
        </div>
      <% end %>
      <div :if={@tooltip} class="m-2 opacity-50 hover:cursor-help">
        <span
          id={@id <> "_tooltip"}
          title={@tooltip}
          class="fas fa-info-circle"
          phx-hook="TooltipInit"
        />
      </div>
    </div>
    """
  end

  def handle_delegated(event, params, socket, patch_fn) do
    delegate_handle_event(event, params, socket, patch_fn)
  end

  def delegate_handle_event("text_search_reset", %{"id" => _id}, socket, patch_fn) do
    patch_fn.(socket, %{text_search: "", offset: 0})
  end

  def delegate_handle_event("text_search_change", %{"value" => value}, socket, patch_fn) do
    patch_fn.(socket, %{text_search: value, offset: 0})
  end

  def delegate_handle_event(_, _, _, _) do
    :not_handled
  end
end
