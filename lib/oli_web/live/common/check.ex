defmodule OliWeb.Common.Check do
  use Surface.Component

  prop checked, :boolean, required: true
  prop click, :event, required: true
  prop class, :string
  slot default, required: true

  def render(assigns) do
    ~F"""
    <div class={"form-check #{@class}"} style="display: inline;">
      <input type="checkbox" class="form-check-input" checked={@checked} :on-click={@click}>
      <label class="form-check-label" :on-click={@click}>
        <#slot />
      </label>
    </div>
    """
  end
end
