defmodule OliWeb.Resources.AuthoredActivity do
  use Surface.LiveComponent

  prop rendered_authoring, :string, required: true

  def render(assigns) do
    ~F"""
    <div id={@id} phx-update="replace">
      {raw(@rendered_authoring)}
    </div>
    """
  end
end
