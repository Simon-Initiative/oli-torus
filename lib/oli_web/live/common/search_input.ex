defmodule OliWeb.Common.SearchInput do
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :class, :string, default: nil
  attr :placeholder, :string, default: ""
  attr :text, :string, default: ""
  attr :id, :string, required: true
  attr :name, :string, required: true

  def render(assigns) do
    ~H"""
      <div>
        <i id={"#{@id}-icon"} class="absolute fa-solid fa-magnifying-glass pl-3 pt-3 h-4 w-4 "></i>
        <input id={"#{@id}-input"} phx-debounce="300" phx-focus={JS.add_class("text-delivery-primary", to: "##{@id}-icon")} phx-blur={JS.remove_class("text-delivery-primary", to: "##{@id}-icon")} type="text" class="h-9 w-44 rounded border pl-9 focus:ring-1 focus:ring-delivery-primary focus:outline-2" placeholder={@placeholder} value={@text} name={@name}>
      </div>
    """
  end
end
