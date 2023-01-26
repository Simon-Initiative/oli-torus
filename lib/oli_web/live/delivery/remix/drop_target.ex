defmodule OliWeb.Delivery.Remix.DropTarget do
  @moduledoc """
  Drop target component.
  """

  use Phoenix.Component

  def droptarget(assigns) do
    ~H"""
    <div
      phx-hook="DropTarget"
      id={"drop-target-#{assigns.index}"}
      data-drop-index={assigns.index}
      class="drop-target"
    >
    </div>
    """
  end
end
