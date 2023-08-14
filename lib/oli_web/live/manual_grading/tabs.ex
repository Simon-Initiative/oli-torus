defmodule OliWeb.ManualGrading.Tabs do
  use OliWeb, :html

  attr :active, :atom, required: true
  attr :changed, :any, required: true

  def render(assigns) do
    ~H"""
    <ul class="nav nav-tabs">
      <li class="nav-item">
        <a class={active(assigns, :review)} phx-click={@changed} phx-value-tab={:review}>
          Student Submission
        </a>
      </li>
      <li class="nav-item">
        <a class={active(assigns, :preview)} phx-click={@changed} phx-value-tab={:preview}>
          Activity Details
        </a>
      </li>
    </ul>
    """
  end

  def active(assigns, key) do
    if assigns.active == key do
      "nav-link active"
    else
      "nav-link"
    end
  end
end
