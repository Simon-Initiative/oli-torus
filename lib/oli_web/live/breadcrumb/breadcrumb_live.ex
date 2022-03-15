defmodule OliWeb.Breadcrumb.BreadcrumbLive do
  use OliWeb, :live_component
  import Phoenix.HTML.Link

  alias OliWeb.Common.Breadcrumb

  def render(assigns) do
    render_breadcrumb(assigns)
  end

  defp render_breadcrumb(%{is_last: true} = assigns) do
    ~L"""
    <li class="breadcrumb-item active" aria-current="page">
      <%= get_title(@breadcrumb, @show_short) %>
    </li>
    """
  end

  defp render_breadcrumb(%{breadcrumb: %{link: nil}} = assigns) do
    ~L"""
    <li class="breadcrumb-item">
      <%= get_title(@breadcrumb, @show_short) %>
    </li>
    """
  end

  defp render_breadcrumb(%{is_last: false} = assigns) do
    ~L"""
    <li class="breadcrumb-item">
      <%= link get_title(@breadcrumb, @show_short),
          to: @breadcrumb.link %>
    </li>
    """
  end

  defp get_title(%Breadcrumb{short_title: short_title}, true = _show_short), do: short_title
  defp get_title(%Breadcrumb{full_title: full_title}, false = _show_short), do: full_title
end
