defmodule OliWeb.Delivery.StudentOnboarding.Explorations do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
      <div class="h-full text-center">
        <h2>Exploration Activities</h2>
        <span class="text-gray-500 text-sm">Explorations dig into how the course subject matter affects you</span>
        <p class="mt-14">You’ll have access to both simulations and digital versions of tools used in the real world to help you explore the topics brought up in the course from a real-world perspective.</p>
      </div>
    """
  end
end
