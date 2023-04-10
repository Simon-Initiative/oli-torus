defmodule OliWeb.Curriculum.DropTarget do
  @moduledoc """
  Drop target component.
  """

  use Surface.LiveComponent

  prop index, :integer, required: true

  def render(assigns) do
    ~F"""
    <div
      phx-hook="DropTarget"
      id={"drop-target-#{@index}"}
      data-drop-index={@index}
      class="drop-target"
    >
    </div>
    """
  end
end
