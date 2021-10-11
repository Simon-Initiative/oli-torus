defmodule OliWeb.Common.TextSearch do
  use Surface.LiveComponent

  prop apply, :event, default: "text_search_apply"
  prop reset, :event, default: "text_search_reset"
  data text, :string, default: ""

  def render(assigns) do
    ~F"""
      <div class="input-group" style="max-width: 500px;">
        <input type="text" class="form-control" placeholder="Search..." :on-change="change" :on-blur="change">
        <div class="input-group-append">
          <button class="btn btn-outline-secondary" :on-click={@apply, target: :live_view} phx-value-text={@text}>Search</button>
          <button class="btn btn-outline-secondary" :on-click={@reset, target: :live_view} phx-value-text={""}>Reset</button>
        </div>
      </div>
    """
  end

  def handle_event("change", %{"value" => value}, socket) do
    {:noreply, assign(socket, text: value)}
  end

  def handle_delegated(event, params, socket, patch_fn) do
    delegate_handle_event(event, params, socket, patch_fn)
  end

  def delegate_handle_event("text_search_reset", _, socket, patch_fn) do
    patch_fn.(socket, %{text_search: ""})
  end

  def delegate_handle_event("text_search_apply", %{"text" => text}, socket, patch_fn) do
    patch_fn.(socket, %{text_search: text})
  end

  def delegate_handle_event(_, _, _, _) do
    :not_handled
  end
end
