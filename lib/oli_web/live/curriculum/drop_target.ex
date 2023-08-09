defmodule OliWeb.Curriculum.DropTarget do
  @moduledoc """
  Drop target component.
  """

  use Phoenix.Component

  attr :index, :integer, required: true

  def render(assigns) do
    ~H"""
    <div
      phx-hook="DropTarget"
      id={"drop-target-#{@index}"}
      data-drop-index={@index}
      class="drop-target"
    />
    """
  end
end
