defmodule OliWeb.ManualGrading.FilterButton do
  use OliWeb, :html

  attr :clicked, :any, required: true
  attr :label, :string, required: true
  attr :active, :boolean, required: true
  attr :tooltip, :string, required: true
  attr :selection, :boolean, required: true
  attr :key, :any, required: true

  def render(assigns) do
    ~H"""
    <button
      disabled={!@selection}
      type="button"
      data-bs-toggle="tooltip"
      title={@tooltip}
      class={if @active, do: "btn btn-info", else: "btn btn-outline-secondary"}
      phx-click={@clicked}
      phx-value-key={@key}
      phx-value-active={if @active, do: "false", else: "true"}
    >
      {@label}
    </button>
    """
  end
end
