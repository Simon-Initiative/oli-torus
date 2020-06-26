defmodule OliWeb.RevisionHistory.PaginationLink do
  use Phoenix.LiveComponent

  def render(assigns) do

    str = Integer.to_string(assigns.page_ordinal)

    ~L"""
    <li class="page-item <%= if @active do "active" else "" end %>">
      <a class="page-link" href="#" phx-click="page" phx-value-ordinal="<%= str %>"><%= str %></a>
    </li>
    """
  end

end
