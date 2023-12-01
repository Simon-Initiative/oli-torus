defmodule OliWeb.Components.Delivery.DeliberatePracticeCard do
  use OliWeb, :html

  alias OliWeb.Router.Helpers, as: Routes

  attr :dark, :boolean, default: false
  attr :practice, :map
  attr :section_slug, :string
  attr :preview_mode, :boolean, default: false

  def render(assigns) do
    assigns =
      assign(
        assigns,
        :description,
        case assigns.practice.intro_content do
          nil ->
            nil

          %{} ->
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
        src={poster_image(@practice)}
      />
      <div class="flex-1 flex flex-col justify-between p-8 leading-normal">
        <h5 class="mb-3 text-2xl font-bold tracking-tight text-gray-900 dark:text-white">
          <%= @practice.title %>
        </h5>
        <div class="text-sm mb-3">
          <%= raw(@description) %>
        </div>
        <div class="flex flex-row justify-end items-center space-x-6">
          <.button variant={:primary} href={practice_link(@section_slug, @practice, @preview_mode)}>
            Open
          </.button>
        </div>
      </div>
    </div>
    """
  end

  defp practice_link(section_slug, practice, preview_mode) do
    if preview_mode do
      ~p"/sections/#{section_slug}/preview/page/#{practice.slug}"
    else
      ~p"/sections/#{section_slug}/page/#{practice.slug}"
    end
  end

  defp poster_image(practice) do
    case practice.poster_image do
      nil ->
        ~p"/images/practice/default_poster.jpg"

      image ->
        image
    end
  end
end
