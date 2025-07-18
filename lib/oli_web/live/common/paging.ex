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
  attr :has_shorter_label, :boolean, default: false
  attr :should_add_empty_flex, :boolean, default: true
  attr :is_page_size_right, :boolean, default: false

  def render(assigns) do
    params =
      PagingParams.calculate(
        assigns.total_count,
        assigns.offset,
        assigns.limit,
        5,
        assigns.has_shorter_label
      )

    assigns =
      assigns
      |> assign(:params, params)
      |> assign(:show_pagination, assigns.total_count > assigns.limit)

    ~H"""
    <div
      id={@id}
      class={"flex justify-between items-center py-2 " <> if Map.get(@params, :rendered_pages_count) == 1, do: "justify-end", else: ""}
    >
      <div :if={@show_pagination} class="ml-4"><%= @params.label %></div>
      <div :if={@should_add_empty_flex} class="flex-1"></div>
      <.form
        :if={!@is_page_size_right}
        id={"#{@id}_page_size_form"}
        for={%{}}
        phx-change={@limit_change}
      >
        <div :if={@show_limit_change} class="inline-flex flex-col gap-1 mr-2">
          <small class="torus-small uppercase">
            Page size
          </small>
          <select class="torus-select" name="limit">
            <option :for={page_size <- @page_sizes} selected={@limit == page_size} value={page_size}>
              <%= page_size %>
            </option>
          </select>
        </div>
      </.form>

      <nav :if={@show_pagination} aria-label="Paging">
        <ul class="pagination">
          <li class={"page-item #{if @params.current_page_index == 0, do: "disabled"}"}>
            <button
              class="page-link"
              phx-click={@click}
              phx-value-offset={0}
              phx-value-limit={@limit}
              disabled={@params.current_page_index == 0}
            >
              <i class="fas fa-angle-double-left"></i>
            </button>
          </li>
          <li class={"page-item #{if @params.current_page_index == 0, do: "disabled"}"}>
            <button
              class="page-link"
              phx-click={@click}
              phx-value-offset={@offset - @limit}
              phx-value-limit={@limit}
              disabled={@params.current_page_index == 0}
            >
              <i class="fas fa-angle-left"></i>
            </button>
          </li>
          <%= for i <- 0..(@params.rendered_pages_count- 1) do %>
            <li class={"page-item #{if @params.start_page_index + i == @params.current_page_index, do: "active"}"}>
              <button
                class="page-link"
                phx-click={@click}
                phx-value-offset={(@params.start_page_index + i) * @limit}
                phx-value-limit={@limit}
              >
                <%= i + 1 + @params.start_page_index %>
              </button>
            </li>
          <% end %>
          <li class={"page-item #{if @params.current_page_index == @params.last_page_index, do: "disabled"}"}>
            <button
              class="page-link"
              phx-click={@click}
              phx-value-offset={@offset + @limit}
              phx-value-limit={@limit}
              disabled={@params.current_page_index == @params.last_page_index}
            >
              <i class="fas fa-angle-right"></i>
            </button>
          </li>
          <li class={"page-item #{if @params.current_page_index == @params.last_page_index, do: "disabled"}"}>
            <button
              class="page-link"
              phx-click={@click}
              phx-value-offset={@params.last_page_index * @limit}
              phx-value-limit={@limit}
              disabled={@params.current_page_index == @params.last_page_index}
            >
              <i class="fas fa-angle-double-right"></i>
            </button>
          </li>
        </ul>
      </nav>
      <.form
        :if={@is_page_size_right}
        id={"#{@id}_page_size_form"}
        for={%{}}
        phx-change={@limit_change}
      >
        <div
          :if={@show_limit_change}
          class={"inline-flex flex-col gap-1 mr-4 #{if @is_page_size_right, do: "ml-4"}"}
        >
          <small class="torus-small uppercase">
            Page size
          </small>
          <select class="torus-select" name="limit">
            <option :for={page_size <- @page_sizes} selected={@limit == page_size} value={page_size}>
              <%= page_size %>
            </option>
          </select>
        </div>
      </.form>
    </div>
    """
  end
end
