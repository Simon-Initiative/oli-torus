defmodule OliWeb.Delivery.Student.IndexLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_tab: :index)}
  end

  def render(assigns) do
    ~H"""
    <.hero_banner class="bg-index">
      <h1 class="text-6xl mb-8">Hi, <span class="font-bold"><%= user_given_name(@ctx) %></span></h1>
      <div class="my-2 uppercase gap-2 lg:gap-8 columns-2 lg:columns-3">
        <div class="font-bold">Course Progress</div>
        <div>0%</div>
      </div>
      <div class="my-2 uppercase gap-2 lg:gap-8 columns-2 lg:columns-3">
        <div class="font-bold">Average Score</div>
        <div>0/60</div>
      </div>
    </.hero_banner>

    <div class="container mx-auto">
      <.up_next />
    </div>
    """
  end

  def up_next(assigns) do
    ~H"""
    <div class="my-8 px-16">
      <div class="font-bold text-2xl mb-4">Up Next</div>
      <div class="flex flex-row">
        <div class="mr-8 uppercase">Week 2:</div>
        <div class="flex-1 flex flex-col">
          <div>Mon, 15 - Tue, 16</div>
          <div class="flex flex-row">
            <div class="basis-1/4 flex flex-col">
              <div class="font-bold">Pre-Read</div>
              <div>Module 2.1</div>
            </div>
            <div class="flex-1 flex flex-col">
              <div>Atomic Theory and the Periodic Table</div>
              <div>Due: Fri, Sept 20, 2024</div>
            </div>
            <div class="basis-1/4 flex flex-col"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
