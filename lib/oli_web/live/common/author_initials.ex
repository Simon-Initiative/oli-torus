defmodule OliWeb.Common.AuthorInitials do

  @moduledoc """

  Required properties:

  `author`: The author whose initials will be displayed

  Optional properties:
  `size`: The width/height in pixels

  """

  use Phoenix.LiveComponent

  def render(%{ author: author } = assigns) do
    initials = String.upcase(String.first(author.first_name))
      <> String.upcase(String.first(author.last_name))
    size = assigns.size

    ~L"""
    <span
      style="<%= if size do "width: #{size}px; height: #{size}px; line-height: #{size}px; font-size: calc(18px * calc(#{size} / 36));" else "" end %>"
      data-initials="<%= initials %>"></span>
    """
  end
end
