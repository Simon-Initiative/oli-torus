defmodule OliWeb.ManualGrading.RenderedActivity do
  use Surface.LiveComponent

  prop rendered_activity, :any, required: true

  def render(%{rendered_activity: nil} = assigns) do
    ~F"""
      <div/>
    """
  end

  def render(assigns) do
    ~F"""
    <hr class="mb-3 mt-3"/>
    <div id={@id} phx-update="none">{raw(@rendered_activity)}</div>
    """
  end

end
