defmodule OliWeb.Curriculum.DropTarget do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div phx-hook="DropTarget"
      data-drop-index="<%= assigns.index %>"
      style="height: 15px;"
    >
    </div>
    """
  end
end
