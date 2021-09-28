defmodule OliWeb.Common.Paging do
  use Surface.LiveComponent

  prop total_count, :integer, required: true
  prop click, :event, required: true
  prop offset, :integer, required: true
  prop limit, :integer, required: true

  @spec render(
          atom
          | %{:limit => number, :offset => number, :total_count => number, optional(any) => any}
        ) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    last_page_index = ceil(assigns.total_count / assigns.limit) - 1
    rendered_pages = min(last_page_index + 1, 9) - 1
    current_page = assigns.offset / assigns.limit

    start =
      cond do
        last_page_index <= 9 -> 0
        last_page_index - current_page < 4 -> 8 - (last_page_index - current_page)
        true -> current_page - 4
      end

    upper = min(assigns.offset + assigns.limit, assigns.total_count)
    label = "Showing result #{assigns.offset + 1} - #{upper} of #{assigns.total_count} total"

    ~F"""
    <div class="d-flex justify-content-between">
      <div>{label}</div>
      <nav aria-label="Paging">
        <ul class="pagination">
          <li class={"page-item", disabled: (current_page == 0)}>
            <a class="page-link" :on-click={@click} phx-value-offset={@offset - @limit} phx-value-limit={@limit}>
              Previous
            </a>
          </li>
          {#for i <- 0..rendered_pages}
            <li class={"page-item", active: (start + i == current_page)}>
              <a class="page-link" :on-click={@click} phx-value-offset={(start + i) * @limit} phx-value-limit={@limit}>
                {i + 1}
              </a>
            </li>
          {/for}
          <li class={"page-item", disabled: (current_page == last_page_index)}>
            <a class="page-link" :on-click={@click} phx-value-offset={@offset + @limit} phx-value-limit={@limit}>
              Next
            </a>
          </li>
        </ul>
      </nav>
    </div>
    """
  end
end
