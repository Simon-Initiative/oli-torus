defmodule OliWeb.ManualGrading.RenderedActivity do
  use OliWeb, :html

  attr :rendered_activity, :any, required: true
  attr :id, :string, default: nil

  def render(%{rendered_activity: nil} = assigns) do
    ~H"""
    <div />
    """
  end

  def render(assigns) do
    ~H"""
    <div class="mt-5 rendered-activity" id={@id}>{raw(@rendered_activity)}</div>
    """
  end
end
