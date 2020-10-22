defmodule OliWeb.Breadcrumb.BreadcrumbLive do
  use OliWeb, :live_component
  import Phoenix.HTML.Link

  def render(assigns) do
    render_breadcrumb(assigns)
  end

  defp render_breadcrumb(%{is_last: true} = assigns) do
    ~L"""
    <li class="breadcrumb-item active" aria-current="page">
      <%= get_title(@breadcrumb, @show_short) %>
      <%= if !Enum.empty?(@breadcrumb.action_descriptions) do %>
        <button
          phx-click="rename"
          phx-target="<%= @myself %>"
          class="list-unstyled"
          style="border:none; background: none; color: #212529"
        >
          <i class="material-icons">arrow_drop_down</i>
        </button>
      <% end %>
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

  def handle_event("rename", _params, socket) do
    {:noreply,
     redirect(socket,
       to:
         Routes.container_path(
           socket,
           :edit,
           socket.assigns.project.slug,
           socket.assigns.container_slug,
           socket.assigns.breadcrumb.slug
         )
     )}
  end

  defp get_title(breadcrumb, true = _show_short), do: breadcrumb.short_title
  defp get_title(breadcrumb, false = _show_short), do: breadcrumb.full_title
end
