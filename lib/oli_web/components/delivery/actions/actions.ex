defmodule OliWeb.Components.Delivery.Actions do
  use Surface.LiveComponent

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Accounts

  prop enrollment_info, :map, required: true
  prop section_slug, :string, required: true
  prop user, :map, required: true

  data enrollment, :map, default: %{}
  data is_instructor, :boolean, default: false

  def update(
        %{user: user, section_slug: section_slug, enrollment_info: enrollment_info} = _assigns,
        socket
      ) do
    {:ok,
     assign(socket,
       enrollment: enrollment_info.enrollment,
       is_instructor: enrollment_info.is_instructor,
       section_slug: section_slug,
       user: user
     )}
  end

  def render(assigns) do
    ~F"""
      <div class="mx-10 mb-10 bg-white shadow-sm">

        <div class="flex flex-col sm:flex-row sm:items-end px-6 py-4 border instructor_dashboard_table">
          <h4 class="pl-9 !py-2 torus-h4 mr-auto dark:!text-black">Actions</h4>
        </div>

        <div class="flex justify-between items-center px-14 py-8">
          <div class="flex flex-col">
            <span class="dark:text-black">Change role to Instructor</span>
            <span class="text-xs text-gray-400 dark:text-gray-950">If this option is enabled, the user will have the role of Instructor in this course section.</span>
          </div>
          <label class="relative inline-flex items-center cursor-pointer">
            <input
              type="checkbox"
              class="sr-only peer"
              phx-click="change_user_role"
              phx-target={@myself}
              checked={@is_instructor}>
            <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 dark:peer-focus:ring-blue-800 rounded-full peer dark:bg-gray-700 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-blue-600"></div>
          </label>
        </div>
      </div>
    """
  end

  def handle_event("change_user_role", _params, socket) do
    if socket.assigns.is_instructor,
      do:
        Accounts.toggle_context_role(
          socket.assigns.enrollment,
          ContextRoles.get_role(:context_learner)
        ),
      else:
        Accounts.toggle_context_role(
          socket.assigns.enrollment,
          ContextRoles.get_role(:context_instructor)
        )

    {:noreply, assign(socket, is_instructor: !socket.assigns.is_instructor)}
  end
end
