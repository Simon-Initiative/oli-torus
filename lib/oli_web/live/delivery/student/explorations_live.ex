defmodule OliWeb.Delivery.Student.ExplorationsLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  alias OliWeb.Common.SessionContext
  alias Oli.Rendering.Content
  alias Oli.Delivery.Sections

  def mount(_params, _session, socket) do
    explorations_by_container =
      Sections.get_explorations_by_containers(socket.assigns.section, socket.assigns.ctx.user)

    {:ok,
     assign(socket,
       explorations_by_container: explorations_by_container
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
        </div>
      </div>
      <div class="container mx-auto flex flex-col mt-6 px-16">
        <div :if={Enum.count(@explorations_by_container) == 0} class="text-center" role="alert">
          <h6>There are no explorations available</h6>
        </div>

        <%= for {container_name, explorations} <- @explorations_by_container do %>
          <h2 :if={container_name != :default} class="text-sm font-bold my-6 uppercase text-gray-700">
            <%= container_name %>
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
    </.header_with_sidebar_nav>
    """
  end

  attr :ctx, SessionContext, required: true
  attr :exploration, :map, required: true
  attr :status, :atom, required: true, values: [:not_started, :started]
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
        src={poster_image(@exploration)}
      />
      <div class="flex-1 flex flex-col justify-between p-8 leading-normal">
        <h5 class="mb-3 text-2xl font-bold tracking-tight text-gray-900 dark:text-white">
          <%= @exploration.title %>
        </h5>
        <div class="text-sm mb-3">
          <%= raw(@description) %>
        </div>
        <div class="flex flex-row justify-end items-center space-x-6">
          <.button
            variant={:primary}
            href={exploration_link(@section_slug, @exploration, @preview_mode)}
          >
            <%= exploration_link_text(@status) %>
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

  defp poster_image(exploration) do
    case exploration.poster_image do
      nil ->
        ~p"/images/ng23/explorations/default_poster.jpg"

      image ->
        image
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
