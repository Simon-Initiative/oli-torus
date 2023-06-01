defmodule OliWeb.Components.Delivery.AdaptiveIFrame do
  alias OliWeb.Router.Helpers, as: Routes
  @default_height 860
  @default_width 1100
  @chrome_height 175
  @chrome_width 150

  defp get_size(content) do
    custom_content = Map.get(content, "custom", %{})
    content_height = Map.get(custom_content, "defaultScreenHeight", @default_height)
    content_width = Map.get(custom_content, "defaultScreenWidth", @default_width)

    {content_width + @chrome_width, content_height + @chrome_height}
  end

  def preview(project_slug, revision) do
    size = get_size(revision.content)
    url = Routes.resource_path(OliWeb.Endpoint, :preview_fullscreen, project_slug, revision.slug)
    iframe(url, size)
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
