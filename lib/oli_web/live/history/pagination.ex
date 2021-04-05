defmodule OliWeb.RevisionHistory.Pagination do
  use Phoenix.LiveComponent

  alias OliWeb.RevisionHistory.PaginationLink

  defp render_none(assigns) do
    ~L"""
    <div></div>
    """
  end

  def render(assigns) do
    count = length(assigns.revisions)
    page_size = assigns.page_size

    if count > page_size do
      total_pages =
        div(count, page_size) +
          if rem(count, page_size) == 0 do
            0
          else
            1
          end

      current_page = div(assigns.page_offset, page_size) + 1

      ~L"""
      <nav aria-label="table results paging">
        <ul class="pagination justify-content-center">
          <%= for page <- 1..total_pages do %>
            <%= live_component @socket, PaginationLink, page_ordinal: page, active: current_page == page, page_offset: @page_offset %>
          <% end %>
        </ul>
      </nav>
      """
    else
      render_none(assigns)
    end
  end
end
