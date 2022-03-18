defmodule OliWeb.ManualGrading.FilterButton do
  use Surface.Component

  prop clicked, :event, required: true
  prop label, :string, required: true
  prop active, :boolean, required: true
  prop key, :any, required: true

  def render(%{active: true} = assigns) do
    ~F"""
    <button type="button" class="btn btn-info" :on-click={@clicked} phx-value-key={@key} phx-value-active={"false"}>{@label}</button>
    """
  end

  def render(assigns) do
    ~F"""
    <button type="button" class="btn btn-outline-info" :on-click={@clicked} phx-value-key={@key} phx-value-active={"true"}>{@label}</button>
    """
  end
end
