defmodule OliWeb.Components.Delivery.AssignmentCard do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
      <div class="flex justify-between bg-delivery-header p-8">
        <h3 class="text-white">1.0 Essential Ideas</h3>
        <div class="flex gap-2">
          <span class="bg-white bg-opacity-10 rounded-sm text-white px-16 py-2">
            Due by 10-03-2022
          </span>
          <button class="torus-button primary px-2">Quiz</button>
        </div>
      </div>
    """
  end
end
