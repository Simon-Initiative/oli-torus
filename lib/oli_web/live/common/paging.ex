defmodule OliWeb.Common.Paging do
  use Phoenix.Component
  alias OliWeb.Common.PagingParams

  attr :total_count, :integer, required: true
  attr :click, :string, required: true
  attr :offset, :integer, required: true
  attr :limit, :integer, required: true
  attr :id, :string, required: true

  def render(assigns) do
    params = PagingParams.calculate(assigns.total_count, assigns.offset, assigns.limit, 5)

    assigns = Map.merge(assigns, %{params: params})

    ~H"""
    <div id={@id} class="d-flex justify-content-between items-center px-5 py-2">
      <div><%= @params.label %></div>
      <div class="flex-1"></div>
      <nav aria-label="Paging">
        <ul class="pagination">
          <li class={"page-item #{if @params.current_page_index == 0, do: "disabled"}"}>
            <a class="page-link" phx-click={@click} phx-value-offset={0} phx-value-limit={@limit}>
              <i class="fas fa-angle-double-left"></i>
            </a>
          </li>
          <li class={"page-item #{if @params.current_page_index == 0, do: "disabled"}"}>
            <a
              class="page-link"
              phx-click={@click}
              phx-value-offset={@offset - @limit}
              phx-value-limit={@limit}
            >
              <i class="fas fa-angle-left"></i>
            </a>
          </li>
          <%= for i <- 0..(@params.rendered_pages_count- 1) do %>
            <li class={"page-item #{if @params.start_page_index + i == @params.current_page_index, do: "active"}"}>
              <a
                class="page-link"
                phx-click={@click}
                phx-value-offset={(@params.start_page_index + i) * @limit}
                phx-value-limit={@limit}
              >
                <%= i + 1 + @params.start_page_index %>
              </a>
            </li>
          <% end %>
          <li class={"page-item #{if @params.current_page_index == @params.last_page_index, do: "disabled"}"}>
            <a
              class="page-link"
              phx-click={@click}
              phx-value-offset={@offset + @limit}
              phx-value-limit={@limit}
            >
              <i class="fas fa-angle-right"></i>
            </a>
          </li>
          <li class={"page-item #{if @params.current_page_index == @params.last_page_index, do: "disabled"}"}>
            <a
              class="page-link"
              phx-click={@click}
              phx-value-offset={@params.last_page_index * @limit}
              phx-value-limit={@limit}
            >
              <i class="fas fa-angle-double-right"></i>
            </a>
          </li>
        </ul>
      </nav>
    </div>
    """
  end
end
