defmodule OliWeb.Common.Paging do
  use Surface.LiveComponent
  alias OliWeb.Common.PagingParams

  prop total_count, :integer, required: true
  prop click, :event, required: true
  prop offset, :integer, required: true
  prop limit, :integer, required: true

  def render(assigns) do
    params = PagingParams.calculate(assigns.total_count, assigns.offset, assigns.limit, 5)

    ~F"""
    <div class="d-flex justify-content-between">
      <div>{params.label}</div>
      <nav aria-label="Paging">
        <ul class="pagination">
          <li class={"page-item", disabled: (params.current_page_index == 0)}>
            <a class="page-link" :on-click={@click} phx-value-offset={0} phx-value-limit={@limit}>
              &lt;&lt;
            </a>
          </li>
          <li class={"page-item", disabled: (params.current_page_index == 0)}>
            <a class="page-link" :on-click={@click} phx-value-offset={@offset - @limit} phx-value-limit={@limit}>
              &lt;
            </a>
          </li>
          {#for i <- 0..(params.rendered_pages_count- 1)}
            <li class={"page-item", active: (params.start_page_index + i == params.current_page_index)}>
              <a class="page-link" :on-click={@click} phx-value-offset={(params.start_page_index + i) * @limit} phx-value-limit={@limit}>
                {i + 1 + params.start_page_index}
              </a>
            </li>
          {/for}
          <li class={"page-item", disabled: (params.current_page_index == params.last_page_index)}>
            <a class="page-link" :on-click={@click} phx-value-offset={@offset + @limit} phx-value-limit={@limit}>
              &gt;
            </a>
          </li>
          <li class={"page-item", disabled: (params.current_page_index == params.last_page_index)}>
            <a class="page-link" :on-click={@click} phx-value-offset={params.last_page_index * @limit} phx-value-limit={@limit}>
              &gt;&gt;
            </a>
          </li>
        </ul>
      </nav>
    </div>
    """
  end
end
