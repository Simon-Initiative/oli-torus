defmodule OliWeb.Sections.Instructors do
  use Surface.Component
  import OliWeb.Common.Utils

  prop users, :list, required: true

  def render(assigns) do
    ~F"""
    <ul class="list-group">
      {#for u <- @users}
        <li class="list-group-item">
          {name(u)}
        </li>
      {/for}
    </ul>
    """
  end
end
