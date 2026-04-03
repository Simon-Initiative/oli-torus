defmodule OliWeb.Components.Delivery.AdaptiveIFrame do
  alias OliWeb.Router.Helpers, as: Routes
  @default_height 860
  @default_width 1100
  @chrome_height 175
  @chrome_width 150
  @insights_padding 16

  defp get_content_size(content) do
    custom_content = Map.get(content, "custom", %{})
    content_height = Map.get(custom_content, "defaultScreenHeight", @default_height)
    content_width = Map.get(custom_content, "defaultScreenWidth", @default_width)

    {content_width, content_height}
  end

  defp get_size(content) do
    {content_width, content_height} = get_content_size(content)

    {content_width + @chrome_width, content_height + @chrome_height}
  end

  def preview(project_slug, revision) do
    size = get_size(revision.content)
    url = Routes.resource_path(OliWeb.Endpoint, :preview_fullscreen, project_slug, revision.slug)
    iframe(url, size)
  end

  def insights_preview(section_slug, page_revision, revision) do
    {width, height} = get_content_size(page_revision.content)
    iframe_width = width + @insights_padding * 2
    iframe_height = height + @insights_padding * 2

    url =
      Routes.page_delivery_path(
        OliWeb.Endpoint,
        :adaptive_screen_preview,
        section_slug,
        page_revision.slug,
        revision.slug
      )

    """
    <div class="w-full overflow-x-auto p-4" phx-hook="IframeLoadState">
      <div
        class="flex items-center justify-center text-sm text-gray-500 min-h-[24px] mb-3"
        data-iframe-loading
      >
        Loading screen preview...
      </div>
      <iframe
        width="#{iframe_width}"
        height="#{iframe_height}"
        src="#{url}"
        class="bg-white border-0 block mx-auto"
        loading="eager"
      ></iframe>
    </div>
    """
  end

  def delivery(section_slug, revision_slug, content) do
    size = get_size(content)

    url =
      Routes.page_delivery_path(
        OliWeb.Endpoint,
        :page_fullscreen,
        section_slug,
        revision_slug
      )

    iframe(url, size)
  end

  defp iframe(url, size) do
    {width, height} = size

    "<iframe width=\"#{width}\" height=\"#{height}\" src=\"#{url}\" class=\"bg-white mx-auto mb-24\"></iframe>"
  end
end
