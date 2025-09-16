defmodule OliWeb.Sections.Instructors do
  use OliWeb, :html
  import OliWeb.Common.Utils

  attr :users, :list, required: true

  def render(assigns) do
    ~H"""
    <ul class="list-group">
      <li :for={u <- @users} class="list-group-item">
        {name(u)}
      </li>
    </ul>
    """
  end
end
