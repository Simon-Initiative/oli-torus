defmodule OliWeb.Components.Delivery.SectionTitle do
  use Phoenix.Component

  attr :title, :string, required: true

  def section_title(assigns) do
    ~H"""
    <div class="text-white bg-delivery-instructor-dashboard-header border-b border-slate-300">
      <div class="container mx-auto md:px-10 py-2 flex flex-row justify-between text-sm md:text-lg">
        <div class="flex items-center gap-2">
          <h4 class="p-2 md:p-0 md:leading-loose">
            {@title}
          </h4>
        </div>
      </div>
    </div>
    """
  end
end
