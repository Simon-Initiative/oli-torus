defmodule OliWeb.ManualGrading.Tabs do
  use Surface.Component

  prop active, :atom, required: true
  prop changed, :event, required: true

  def render(assigns) do
    ~F"""
    <ul class="nav nav-tabs">
      <li class="nav-item">
        <a class={active(assigns, :review)} :on-click={@changed} phx-value-tab={:review}>Student Submission</a>
      </li>
      <li class="nav-item">
        <a class={active(assigns, :preview)} :on-click={@changed} phx-value-tab={:preview}>Activity Details</a>
      </li>
    </ul>
    """
  end

  def active(assigns, key) do
    if assigns.active == key do "nav-link active" else "nav-link" end
  end

end
