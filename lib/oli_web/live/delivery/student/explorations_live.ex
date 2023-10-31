defmodule OliWeb.Delivery.Student.ExplorationsLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  alias OliWeb.Common.SessionContext
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Rendering.Content
  alias Oli.Delivery.{Metrics, Sections}

  def mount(_params, _session, socket) do
    explorations = DeliveryResolver.get_by_purpose(socket.assigns.section.slug, :application)

    # TODO: Replace with real implementation that sorts by week
    explorations_by_week = %{
      1 => explorations
    }

    %{ctx: ctx, section: section} = socket.assigns
    explorations_progress = calculate_explorations_progress(section, ctx.user.id, explorations)

    # TODO: Replace with real average score
    average_score = 46
    average_score_out_of = 60

    {:ok,
     assign(socket,
       explorations_by_week: explorations_by_week,
       explorations_progress: explorations_progress,
       average_score: average_score,
       average_score_out_of: average_score_out_of
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
              <.progress_bar percent={@explorations_progress} width="80%" show_percent={true} />
            </div>
            <div class="my-2 uppercase gap-2 lg:gap-8 columns-2">
              <div class="font-bold">Average Score</div>
              <div class="flex justify-end"><%= "#{@average_score}/#{@average_score_out_of}" %></div>
            </div>
          </div>
        </div>
      </div>
      <div class="container mx-auto flex flex-col px-16">
        <div :if={Enum.count(@explorations_by_week) == 0} class="text-center" role="alert">
          <h6>There are no explorations available</h6>
        </div>

        <%= for {week, explorations} <- @explorations_by_week do %>
          <h2 class="text-sm font-bold my-6 uppercase text-gray-700">Week <%= week %></h2>

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
    assigns =
      assign(
        assigns,
        :description,
        case assigns.exploration.intro_content do
          nil ->
            nil

          intro_content ->
            Content.render(
              %Oli.Rendering.Context{render_opts: %{render_errors: true}},
              intro_content,
              Content.Html
            )
        end
      )

    ~H"""
    <div class="flex flex-col lg:flex-row-reverse items-center rounded-lg bg-black/5 dark:bg-white/5 mb-4">
      <img
        class="object-cover rounded-t-lg lg:rounded-tl-none w-full lg:w-[300px] lg:rounded-r-lg h-64 lg:h-full shrink-0"
        src={@exploration.poster_image}
      />
      <div class="flex-1 flex flex-col justify-between p-8 leading-normal">
        <h5 class="mb-3 text-2xl font-bold tracking-tight text-gray-900 dark:text-white">
          <%= @exploration.title %>
        </h5>
        <div class="text-sm mb-3">
          <%= raw(@description) %>
        </div>
        <div class="flex flex-row justify-end items-center space-x-6">
          <div>
            <span class="font-bold">Due</span> <%= Timex.now()
            |> Timex.shift(days: 7)
            |> Timex.to_date()
            |> date(@ctx) %>
          </div>
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

  defp calculate_explorations_progress(section, user_id, explorations) do
    page_ids =
      explorations
      |> Enum.map(fn exploration -> exploration.resource_id end)

    progress_by_exploration =
      Metrics.progress_across_for_pages(section.id, page_ids, user_id)

    explorations_progress =
      page_ids
      |> Enum.reduce(0, fn page_id, acc ->
        case Map.get(progress_by_exploration, page_id) do
          nil ->
            acc

          progress ->
            acc + progress
        end
      end)
      |> Kernel./(Enum.count(page_ids))
      |> Kernel.*(100)
      |> round()
      |> trunc()

    explorations_progress
  end
end
