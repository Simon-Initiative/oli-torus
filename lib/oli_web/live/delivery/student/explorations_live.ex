defmodule OliWeb.Delivery.Student.ExplorationsLive do
  use OliWeb, :live_view

  alias Oli.Rendering.Content
  alias Oli.Delivery.Sections
  alias OliWeb.Common.SessionContext
  alias OliWeb.Delivery.Student.Utils

  def mount(_params, _session, socket) do
    explorations_by_container =
      Sections.get_explorations_by_containers(socket.assigns.section, socket.assigns.ctx.user)

    {:ok,
     assign(socket,
       active_tab: :explorations,
       explorations_by_container: explorations_by_container
     )}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.hero_banner class="bg-explorations">
      <h1 class="text-4xl md:text-6xl mb-8">Your Explorations</h1>
      <p>All your explorations in one place.</p>
      <p>You unlock explorations as you solve problems and gain useful skills.</p>
    </.hero_banner>
    <div class="overflow-x-scroll md:overflow-x-auto container mx-auto flex flex-col mt-6 px-3 md:px-16">
      <div :if={Enum.count(@explorations_by_container) == 0} class="text-center" role="alert">
        <h6>There are no explorations available</h6>
      </div>

      <%= for {container_name, explorations} <- @explorations_by_container do %>
        <h2 :if={container_name != :default} class="text-sm font-bold my-6 uppercase text-gray-500">
          {container_name}
        </h2>

        <.exploration_card
          :for={{exploration, status} <- explorations}
          ctx={@ctx}
          exploration={exploration}
          status={status}
          section_slug={@section.slug}
          preview_mode={@preview_mode}
        />
      <% end %>
    </div>
    """
  end

  attr :ctx, SessionContext, required: true
  attr :exploration, :map, required: true
  attr :status, :atom, required: true, values: [:not_started, :started]
  attr :section_slug, :string, required: true
  attr :preview_mode, :boolean, default: false

  defp exploration_card(assigns) do
    ~H"""
    <div
      id={"exploration_card_#{@exploration.id}"}
      class="flex flex-col lg:flex-row-reverse items-center rounded-lg bg-black/5 dark:bg-white/5 mb-4"
    >
      <img
        class="object-cover rounded-t-lg lg:rounded-tl-none w-full lg:w-[300px] lg:rounded-r-lg h-64 lg:h-full shrink-0"
        src={poster_image(@exploration)}
      />
      <div class="flex-1 flex flex-col justify-between p-8 leading-normal">
        <h5 class="mb-3 text-2xl font-bold tracking-tight text-gray-900 dark:text-white">
          {@exploration.title}
        </h5>
        <div class="text-sm mb-3">
          {intro_content(@exploration)}
        </div>
        <div class="flex flex-row justify-end items-center space-x-6">
          <.button
            variant={:primary}
            href={exploration_link(@section_slug, @exploration, @preview_mode)}
          >
            {exploration_link_text(@status)}
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
      Utils.lesson_live_path(section_slug, exploration.slug,
        request_path: ~p"/sections/#{section_slug}/explorations"
      )
    end
  end

  defp poster_image(exploration) do
    case exploration.poster_image do
      nil ->
        ~p"/images/explorations/default_poster.jpg"

      image ->
        image
    end
  end

  defp intro_content(exploration) do
    case exploration.intro_content do
      nil ->
        nil

      intro_content ->
        if Enum.empty?(intro_content) do
          nil
        else
          Content.render(
            %Oli.Rendering.Context{
              render_opts: %{render_errors: true, render_point_markers: false}
            },
            intro_content,
            Content.Html
          )
          |> raw()
        end
    end
  end

  defp exploration_link_text(exploration_status) do
    case exploration_status do
      :started ->
        "Continue"

      _ ->
        "Let's Begin"
    end
  end
end
