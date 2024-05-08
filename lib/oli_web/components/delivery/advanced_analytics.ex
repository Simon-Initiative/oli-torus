defmodule OliWeb.Components.Delivery.AdvancedAnalytics do
  use OliWeb, :verified_routes
  use Phoenix.Component
  alias OliWeb.Common.React

  attr :section, :integer, required: true
  attr(:ctx, SessionContext)

  def render(assigns) do
    ~H"""
    <div class="flex p-4">
      <%= React.component(@ctx, "Components.AdvancedAnalytics", %{sectionId: @section.id}, id: "advanced") %>
    </div>
    """
  end

end
