defmodule OliWeb.Common.TextSearch do
  use OliWeb, :live_component

  attr(:id, :string)
  attr(:apply, :string, default: "text_search_apply")
  attr(:reset, :string, default: "text_search_reset")
  attr(:change, :string, default: "text_search_change")
  attr(:placeholder, :string, default: "Search...")
  attr(:text, :string, default: "")
  attr(:event_target, :any, required: false, default: :live_view)

  def render(assigns) do
    ~H"""
    <div class="input-group" style="max-width: 350px;">
      <input
        id={"#{@id}-input"}
        type="text"
        class="form-control"
        placeholder={@placeholder}
        value={@text}
        phx-hook="TextInputListener"
        phx-hook-target={@event_target}
        phx-target={@event_target}
        phx-value-change={@change}
      />
      <%= if @text != "" do %>
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
