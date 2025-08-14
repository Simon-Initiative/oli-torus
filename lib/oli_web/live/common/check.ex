defmodule OliWeb.Common.Check do
  use OliWeb, :html

  attr :id, :string, default: nil
  attr :checked, :boolean, required: true
  attr :click, :string, required: true
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <div class={"form-check inline-flex items-center gap-x-1.5 #{@class}"}>
      <input id={@id} type="checkbox" class="form-check-input" checked={@checked} phx-click={@click} />
      <label for={@id} class="form-check-label">
        {render_slot(@inner_block)}
      </label>
    </div>
    """
  end
end
