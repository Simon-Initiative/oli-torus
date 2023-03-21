defmodule OliWeb.Common.SearchInput do
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  # prop apply, :event, default: "text_search_apply"
  # prop reset, :event, default: "text_search_reset"
  # prop change, :event, default: "text_search_change"
  # prop placeholder, :string, default: "Search..."
  # prop text, :string, default: ""
  # prop event_target, :any, required: false, default: :live_view
  attr :class, :string, default: nil
  attr :placeholder, :string, default: ""
  attr :text, :string, default: ""
  attr :id, :string, required: true
  attr :name, :string, required: true

  # attr :on_change, :string, required: true
  # attr :phx_target, :any, required: true

  def render(assigns) do
    ~H"""
      <div>
        <i id={"#{@id}-icon"} class="absolute fa-solid fa-magnifying-glass pl-3 pt-3 h-4 w-4 "></i>
        <input id={"#{@id}-input"} phx-debounce="300" phx-focus={JS.add_class("text-delivery-primary", to: "##{@id}-icon")} phx-blur={JS.remove_class("text-delivery-primary", to: "##{@id}-icon")} type="text" class="h-9 w-44 rounded border pl-9 focus:ring-1 focus:ring-delivery-primary focus:outline-2" placeholder={@placeholder} value={@text} name={@name}>
      </div>
    """
  end

  # def handle_delegated(event, params, socket, patch_fn) do
  #   delegate_handle_event(event, params, socket, patch_fn)
  # end

  # def delegate_handle_event("text_search_reset", %{"id" => _id}, socket, patch_fn) do
  #   patch_fn.(socket, %{text_search: "", offset: 0})
  # end

  # def delegate_handle_event("text_search_change", %{"value" => value}, socket, patch_fn) do
  #   patch_fn.(socket, %{text_search: value, offset: 0})
  # end

  # def delegate_handle_event(_, _, _, _) do
  #   :not_handled
  # end
end
