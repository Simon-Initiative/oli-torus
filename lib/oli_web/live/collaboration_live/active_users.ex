defmodule OliWeb.CollaborationLive.ActiveUsers do
  use Surface.Component

  prop users, :list, required: true

  def render(assigns) do
    ~F"""
      <div class="members list-group">
        <h5 class="list-group-item active mb-0"><strong>Active users ({length(@users)})</strong></h5>

        <ul class="list-group pb-0 list-group-flush border border-top-0 border-light">
          {#for user <- @users}
            <li class="list-group-item">
              {user.first_name}<strong>{if user.typing do " is typing..." end}</strong>
            </li>
          {/for}
        </ul>
      </div>
    """
  end
end
