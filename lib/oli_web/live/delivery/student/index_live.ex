defmodule OliWeb.Delivery.Student.IndexLive do
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
      active_tab={:index}
    >
      <.welcome_banner ctx={@ctx} />
      <div class="container mx-auto"></div>
    </.header_with_sidebar_nav>
    """
  end

  attr(:ctx, SessionContext)

  def welcome_banner(assigns) do
    ~H"""
    <div class="w-full bg-cover bg-center bg-no-repeat bg-colorful py-24 px-16">
      <div class="container mx-auto flex flex-col">
        <h1 class="text-4xl mb-8">Hi, <span class="font-bold"><%= user_given_name(@ctx) %></span></h1>
        <div class="my-2 uppercase gap-2 lg:gap-8 columns-2 lg:columns-3">
          <div class="font-bold">Course Progress</div>
          <div>0%</div>
        </div>
        <div class="my-2 uppercase gap-2 lg:gap-8 columns-2 lg:columns-3">
          <div class="font-bold">Average Grade</div>
          <div>0/60</div>
        </div>
      </div>
    </div>
    """
  end
end
