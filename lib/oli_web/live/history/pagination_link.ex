defmodule OliWeb.RevisionHistory.PaginationLink do
  use OliWeb, :html

  attr(:page_ordinal, :integer)
  attr(:active, :boolean)
  attr(:page_offset, :integer)

  def render(assigns) do
    assigns = assign(assigns, :str, Integer.to_string(assigns.page_ordinal))

    ~H"""
    <li class={"page-item #{if @active do "active" else "" end}"}>
      <a class="page-link" href="#" phx-click="page" phx-value-ordinal={@str}>{@str}</a>
    </li>
    """
  end
end
