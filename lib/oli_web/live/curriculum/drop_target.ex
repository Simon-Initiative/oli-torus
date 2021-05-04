defmodule OliWeb.Curriculum.DropTarget do
  @moduledoc """
  Drop target component.
  """

  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div phx-hook="DropTarget" id="<%= @id %>"
      data-drop-index="<%= assigns.index %>"
      style="height: 15px;"
    >
    </div>
    """
  end
end
