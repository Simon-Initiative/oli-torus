defmodule OliWeb.Common.TextSearch do
  use Surface.LiveComponent

  prop apply, :event, default: "text_search_apply"
  prop reset, :event, default: "text_search_reset"
  prop change, :event, default: "text_search_change"
  prop text, :string, default: ""
  prop event_target, :any, required: false, default: :live_view

  def render(%{id: id} = assigns) do
    ~F"""
      <div class="input-group" style="max-width: 350px;">
        <input id={"#{id}-input"} type="text" class="form-control" placeholder="Search..." value={@text} phx-hook="TextInputListener" phx-hook-target={@event_target} phx-value-change={@change}>
        {#if @text != ""}
          <div class="input-group-append">
            <button class="btn btn-outline-secondary" phx-click={@reset} phx-value-id={@id}><i class="las la-times"></i></button>
          </div>
        {/if}
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
