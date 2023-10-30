defmodule OliWeb.Delivery.Student.ExplorationsLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  alias OliWeb.Common.SessionContext
  alias Oli.Publishing.DeliveryResolver

  defp sample_explorations_by_unit() do
    %{
      1 => [
        %{
          title: "Do you really want to drink that?",
          poster_image:
            "https://images.pexels.com/photos/928854/pexels-photo-928854.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
          intro_content: %{
            description:
              "Everyone needs water, but what's in it? In this exploration, you'll use your chemistry skills to uncover the hidden elements in various water sources. From tap water to natural springs, what we drink may hold surprises. Through hands-on analysis, you'll investigate what makes water safe or not. This unit challenges you to question and understand what's in the glass you're about to drink. Get ready to uncover the truth about your water: Are You Going to Drink That? Join us in this fascinating investigation!"
          },
          due_date: Timex.now() |> Timex.shift(days: 7) |> Timex.to_date(),
          slug: "do-you-really-want-to-drink-that"
        }
      ]
    }
  end

  def mount(_params, _session, socket) do
    # explorations = DeliveryResolver.get_by_purpose(socket.assigns.section.slug, :application)
    explorations_by_unit = sample_explorations_by_unit()

    {:ok,
     assign(socket,
       explorations_by_unit: explorations_by_unit
     )}
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
        <div :if={Enum.count(@explorations_by_unit) == 0} class="text-center" role="alert">
          <h6>There are no explorations available</h6>
        </div>

        <%= for {unit, explorations} <- @explorations_by_unit do %>
          <h2 class="text-sm font-bold my-6 uppercase text-gray-700">Unit <%= unit %></h2>

          <.exploration_card
            :for={exploration <- explorations}
            ctx={@ctx}
            exploration={exploration}
            section_slug={@section.slug}
            preview_mode={@preview_mode}
          />
        <% end %>
      </div>
    </.header_with_sidebar_nav>
    """
  end

  attr :ctx, SessionContext, required: true
  attr :exploration, :map, required: true
  attr :section_slug, :string, required: true
  attr :preview_mode, :boolean, default: false

  defp exploration_card(assigns) do
    ~H"""
    <div class="flex flex-col lg:flex-row-reverse items-center rounded-lg bg-black/5 dark:bg-white/5">
      <img
        class="object-cover rounded-t-lg lg:rounded-tl-none w-full lg:w-[300px] xl:w-[400px] lg:rounded-r-lg h-64 lg:h-full"
        src={@exploration.poster_image}
      />
      <div class="flex flex-col justify-between p-8 leading-normal">
        <h5 class="mb-3 text-2xl font-bold tracking-tight text-gray-900 dark:text-white">
          <%= @exploration.title %>
        </h5>
        <p class="text-sm mb-3">
          <%= @exploration.intro_content.description %>
        </p>
        <div class="flex flex-row justify-end items-center space-x-6">
          <div><span class="font-bold">Due</span> <%= date(@exploration.due_date, @ctx) %></div>
          <.button
            variant={:primary}
            href={exploration_link(@section_slug, @exploration, @preview_mode)}
          >
            Let's Begin
          </.button>
        </div>
      </div>
    </div>
    """
  end

  defp exploration_link(section_slug, exploration, preview_mode) do
    if preview_mode do
      ~p"/sections/#{section_slug}/preview/page/#{exploration.slug}"
    else
      ~p"/sections/#{section_slug}/page/#{exploration.slug}"
    end
  end
end
