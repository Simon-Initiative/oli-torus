defmodule OliWeb.ManualGrading.FilterButton do
  use Surface.Component

  prop clicked, :event, required: true
  prop label, :string, required: true
  prop active, :boolean, required: true
  prop tooltip, :string, required: true
  prop selection, :boolean, required: true
  prop key, :any, required: true

  def render(%{active: true} = assigns) do
    do_render(assigns, "btn btn-info", "false")
  end

  def render(assigns) do
    do_render(assigns, "btn btn-outline-secondary", "true")
  end

  def do_render(assigns, classes, active) do
    ~F"""
      <button
        disabled={!@selection}
        type="button"
        data-toggle="tooltip"
        title={@tooltip}
        class={classes}
        :on-click={@clicked} phx-value-key={@key} phx-value-active={active}>
        {@label}
      </button>
    """
  end
end
