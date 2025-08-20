defmodule OliWeb.Components.Delivery.DeliberatePractice do
  use OliWeb, :html

  alias Oli.Rendering.Content
  alias OliWeb.Delivery.Student.Utils

  attr :dark, :boolean, default: false
  attr :practice, :map
  attr :section_slug, :string
  attr :preview_mode, :boolean, default: false

  def practice_card(assigns) do
    ~H"""
    <div class="flex flex-col lg:flex-row-reverse items-center rounded-lg bg-black/5 dark:bg-white/5 mb-4">
      <img
        class="object-cover rounded-t-lg lg:rounded-tl-none w-full lg:w-[300px] lg:rounded-r-lg h-64 lg:h-full shrink-0"
        src={poster_image(@practice)}
      />
      <div class="flex-1 flex flex-col justify-between p-8 leading-normal">
        <h5 class="mb-3 text-2xl font-bold tracking-tight text-gray-900 dark:text-white">
          {@practice.title}
        </h5>
        <div class="text-sm mb-3">
          {intro_content(@practice)}
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
      Utils.lesson_live_path(section_slug, practice.slug,
        request_path: ~p"/sections/#{section_slug}/practice"
      )
    end
  end

  defp intro_content(practice) do
    case practice.intro_content do
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

  defp poster_image(practice) do
    case practice.poster_image do
      nil ->
        ~p"/images/practice/default_poster.jpg"

      image ->
        image
    end
  end
end
