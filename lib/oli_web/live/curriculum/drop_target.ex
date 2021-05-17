defmodule OliWeb.Curriculum.DropTarget do
  @moduledoc """
  Drop target component.
  """

  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div phx-hook="DropTarget"
      id="drop-target-<%= assigns.index %>"
      data-drop-index="<%= assigns.index %>"
      class="drop-target"
    >
    </div>
    """
  end
end
