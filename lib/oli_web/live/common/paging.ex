defmodule OliWeb.Common.Paging do
  use Phoenix.Component
  alias OliWeb.Common.PagingParams

  @page_sizes [10, 20, 50, 100]

  attr :total_count, :integer, required: true
  attr :click, :string, required: true
  attr :limit_change, :string, default: "paged_table_limit_change"
  attr :offset, :integer, required: true
  attr :limit, :integer, required: true
  attr :id, :string, required: true
  attr :page_sizes, :list, default: @page_sizes
  attr :show_limit_change, :boolean, default: false

  def render(assigns) do
    params = PagingParams.calculate(assigns.total_count, assigns.offset, assigns.limit, 5)

    assigns =
      assigns
      |> assign(:params, params)
      |> assign(:show_pagination, assigns.total_count > assigns.limit)

    ~H"""
    <div id={@id} class="d-flex justify-content-between items-center px-5 py-2">
      <div :if={@show_pagination} ><%= @params.label %></div>
      <div class="flex-1"></div>
      <.form id={"#{@id}_page_size_form"} for={%{}} phx-change={@limit_change}>
        <div :if={@show_limit_change} class="inline-flex flex-col gap-1 mr-2">
          <small class="torus-small uppercase">
            Page size
          </small>
          <select class="torus-select" name="limit">
            <option
              :for={page_size <- @page_sizes}
              selected={@limit == page_size}
              value={page_size}
            >
              <%= page_size %>
            </option>
          </select>
        </div>
      </.form>

      <nav :if={@show_pagination} aria-label="Paging">
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
