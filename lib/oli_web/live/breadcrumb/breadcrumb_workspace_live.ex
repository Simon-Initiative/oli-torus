defmodule OliWeb.Breadcrumb.BreadcrumbWorkspaceLive do
  use OliWeb, :live_component

  alias OliWeb.Common.Breadcrumb

  def render(assigns) do
    render_breadcrumb(assigns)
  end

  # Active breadcrumb (last item) — dark text, non-clickable
  defp render_breadcrumb(%{is_last: true} = assigns) do
    ~H"""
    <li
      class="flex items-center text-sm font-normal leading-6 text-Text-text-high whitespace-nowrap"
      aria-current="page"
    >
      {get_title(@breadcrumb, @show_short)}
    </li>
    """
  end

  # Link breadcrumb (has link, not last) — blue text, clickable
  defp render_breadcrumb(%{breadcrumb: %{link: link}, is_last: false} = assigns)
       when not is_nil(link) do
    ~H"""
    <li class="flex items-center text-sm font-normal leading-6 whitespace-nowrap">
      <.link navigate={@breadcrumb.link} class="text-Text-text-button hover:underline">
        {get_title(@breadcrumb, @show_short)}
      </.link>
    </li>
    """
  end

  # Text breadcrumb (no link, not last) — dark text, non-clickable
  defp render_breadcrumb(assigns) do
    ~H"""
    <li class="flex items-center text-sm font-normal leading-6 text-Text-text-high whitespace-nowrap">
      {get_title(@breadcrumb, @show_short)}
    </li>
    """
  end

  defp get_title(%Breadcrumb{short_title: short_title}, true = _show_short), do: short_title
  defp get_title(%Breadcrumb{full_title: full_title}, false = _show_short), do: full_title
end
