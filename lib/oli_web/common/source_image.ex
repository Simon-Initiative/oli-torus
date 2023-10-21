defmodule OliWeb.Common.SourceImage do
  alias OliWeb.Router.Helpers, as: Routes

  @doc """
    Given a section or source, returns the cover_image for the given element, or a default one.
  """
  def cover_image(%{cover_image: url}) when not is_nil(url) do
    url
  end

  def cover_image(_) do
    Routes.static_path(OliWeb.Endpoint, "/images/course_default.jpg")
  end
end
