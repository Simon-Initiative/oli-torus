defmodule OliWeb.Sections.Instructors do
  use Surface.Component
  import OliWeb.Common.Utils
  alias OliWeb.Router.Helpers, as: Routes

  prop users, :list, required: true

  def render(assigns) do
    ~F"""
    <ul class="list-group">
      {#for u <- @users}
        <li class="list-group-item">
          <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, u.id)}>
            {name(u)}
          </a>
        </li>
      {/for}
    </ul>
    """
  end
end
