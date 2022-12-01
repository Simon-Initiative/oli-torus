defmodule OliWeb.CollaborationLive.ActiveUsers do
  use Surface.Component

  prop users, :list, required: true

  def render(assigns) do
    ~F"""
      <div class="members list-group">
        <div class="list-group-item active">
          <h4>Active users <strong>({length(@users)})</strong></h4>
        </div>
        <div class="list-group-item">
          {#for user <- @users}
            <p>{user.first_name}<strong>{if user.typing do " is typing..." end}</strong></p>
          {/for}
        </div>
      </div>
    """
  end
end
