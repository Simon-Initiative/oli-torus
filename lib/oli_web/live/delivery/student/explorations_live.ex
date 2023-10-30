defmodule OliWeb.Delivery.Student.ExplorationsLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.header_with_sidebar_nav
      ctx={@ctx}
      section={@section}
      brand={@brand}
      preview_mode={@preview_mode}
      active_tab={:explorations}
    >
      <div class="w-full bg-cover bg-center bg-no-repeat bg-gray-700 text-white py-24 px-16">
        <div class="container mx-auto flex flex-col lg:flex-row">
          <div class="lg:flex-1">
            <h1 class="text-4xl mb-8">Your Explorations</h1>
            <p>All your explorations in one place.</p>
            <p>You unlock explorations as you solve problems and gain useful skills.</p>
          </div>
          <div class="lg:flex-1 flex flex-col mt-8 lg:mt-0 lg:ml-8">
            <div class="my-2 uppercase gap-2 lg:gap-8 columns-2">
              <div class="font-bold">Exploration Progress</div>
              <div>0%</div>
            </div>
            <div class="my-2 uppercase gap-2 lg:gap-8 columns-2">
              <div class="font-bold">Average Score</div>
              <div>0/60</div>
            </div>
          </div>
        </div>
      </div>
      <div class="container mx-auto flex flex-col px-16">
        <h2 class="text-sm font-bold my-6 uppercase text-gray-700">Unit 1</h2>

        <div class="flex flex-col lg:flex-row-reverse items-center rounded-lg bg-black/5 dark:bg-white/5">
          <img
            class="object-cover rounded-t-lg lg:rounded-tl-none w-full lg:w-[300px] xl:w-[400px] lg:rounded-r-lg h-64 lg:h-full"
            src="https://images.pexels.com/photos/928854/pexels-photo-928854.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1"
          />
          <div class="flex flex-col justify-between p-8 leading-normal">
            <h5 class="mb-3 text-2xl font-bold tracking-tight text-gray-900 dark:text-white">
              Do you really want to drink that?
            </h5>
            <p class="text-sm mb-3">
              Everyone needs water, but what's in it? In this exploration, you'll use your chemistry skills to uncover the hidden elements in various water sources. From tap water to natural springs, what we drink may hold surprises. Through hands-on analysis, you'll investigate what makes water safe or not. This unit challenges you to question and understand what's in the glass you're about to drink. Get ready to uncover the truth about your water: Are You Going to Drink That? Join us in this fascinating investigation!
            </p>
            <div class="flex flex-row justify-end items-center space-x-6">
              <div><span class="font-bold">Due:</span> Fri, 20 Sept, 2024</div>
              <.button variant={:primary}>Let's Begin</.button>
            </div>
          </div>
        </div>
      </div>
    </.header_with_sidebar_nav>
    """
  end
end
