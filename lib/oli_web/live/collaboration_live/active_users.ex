defmodule OliWeb.CollaborationLive.ActiveUsers do
  use Surface.Component

  prop(users, :list, required: true)

  def render(assigns) do
    ~F"""
    <div>
      <h3 class="text-xl font-bold mb-5">Active users ({length(@users)})</h3>

      <ul class="collab-space__active-users rounded-sm">
        {#for user <- @users}
          <li>
            {name(user)}<strong>{if user.typing do
                " is typing..."
              end}</strong>
          </li>
        {/for}
      </ul>
    </div>
    """
  end

  def name(%{is_guest: true}), do: "Guest"
  def name(user), do: "#{user.first_name}"
end
