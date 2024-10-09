defmodule OliWeb.Breadcrumb.BreadcrumbWorkspaceLive do
  use OliWeb, :live_component

  alias OliWeb.Common.Breadcrumb

  def render(assigns) do
    render_breadcrumb(assigns)
  end

  defp render_breadcrumb(%{id: "breadcrumb-0"} = assigns) do
    ~H"""
    <span></span>
    """
  end

  defp render_breadcrumb(%{is_last: true} = assigns) do
    ~H"""
    <li
      class="breadcrumb-item-workspace flex justify-center items-center text-sm active truncate text-[#A3A3A3]"
      aria-current="page"
    >
      <%= get_title(@breadcrumb, @show_short) %>
    </li>
    """
  end

  defp render_breadcrumb(%{breadcrumb: %{link: nil}} = assigns) do
    ~H"""
    <li class="breadcrumb-item-workspace flex justify-center items-center text-sm">
      <%= get_title(@breadcrumb, @show_short) %>
      <span><i class="fas fa-angle-right ml-1"></i></span>
    </li>
    """
  end

  defp render_breadcrumb(%{is_last: false} = assigns) do
    ~H"""
    <li class="breadcrumb-item-workspace flex justify-center items-center text-sm">
      <.link navigate={@breadcrumb.link}><%= get_title(@breadcrumb, @show_short) %></.link>
      <span class="px-5"></span>
    </li>
    """
  end

  defp get_title(%Breadcrumb{short_title: short_title}, true = _show_short), do: short_title
  defp get_title(%Breadcrumb{full_title: full_title}, false = _show_short), do: full_title
end
