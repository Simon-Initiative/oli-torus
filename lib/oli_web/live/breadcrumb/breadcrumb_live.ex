defmodule OliWeb.Breadcrumb.BreadcrumbLive do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Link

  def render(assigns) do
    ~L"""
    <%= if @last do %>
      <li class="breadcrumb-item active" aria-current="page">
        <%= get_title(@breadcrumb) %>
      </li>
    <% else %>
      <li class="breadcrumb-item">
        <%= link get_title(@breadcrumb), to: @breadcrumb.link %>
      </li>
    <% end %>
    """
  end

  defp get_title(breadcrumb) do
    breadcrumb.full_title
    # full title or short title?
  end

  # Add drop down options to last entry
end
