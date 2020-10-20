defmodule OliWeb.Breadcrumb.BreadcrumbLive do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Link

  def render(assigns) do
    render_breadcrumb(assigns)
  end

  defp render_breadcrumb(%{is_last: true} = assigns) do
    ~L"""
    <li class="breadcrumb-item active" aria-current="page">
      <%= get_title(assigns.breadcrumb, assigns.show_short) %>
    </li>
    """
  end

  defp render_breadcrumb(%{is_last: false} = assigns) do
    ~L"""
    <li class="breadcrumb-item">
      <%= link get_title(assigns.breadcrumb, assigns.show_short),
          to: assigns.breadcrumb.link %>
    </li>
    """
  end

  defp get_title(breadcrumb, true = _show_short), do: breadcrumb.short_title
  defp get_title(breadcrumb, false = _show_short), do: breadcrumb.full_title

  # Add drop down options to last entry
end
