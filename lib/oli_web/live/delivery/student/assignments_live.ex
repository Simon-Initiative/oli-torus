defmodule OliWeb.Delivery.Student.AssignmentsLive do
  use OliWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_tab: :assignments)}
  end

  def render(assigns) do
    ~H"""
    <div
      role="hero banner"
      class="w-full bg-cover bg-center bg-no-repeat h-[247px]"
      style="background-image: url('/images/gradients/assignments-bg.png');"
    >
      <div class="h-[247px] bg-gradient-to-r from-[#e4e4ea] dark:from-[#0a0b11] to-transparent">
        <h1 class="py-20 pl-[76px] text-4xl md:text-6xl font-normal tracking-tight dark:text-white">
          Assignments
        </h1>
      </div>
    </div>
    Placeholder for new Assignments Live View
    """
  end
end
