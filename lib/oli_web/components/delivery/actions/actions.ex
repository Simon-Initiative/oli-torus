defmodule OliWeb.Components.Delivery.Actions do
  use Surface.LiveComponent
  use OliWeb.Common.Modal

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Accounts
  alias OliWeb.Common.Confirm
  alias Phoenix.LiveView.JS

  prop(enrollment_info, :map, required: true)
  prop(section_slug, :string, required: true)
  prop(user, :map, required: true)

  data(enrollment, :map, default: %{})
  data(user_role_data, :list, default: [])
  data(user_role_id, :integer, default: nil)

  @user_role_data [
    %{id: 3, name: :instructor, title: "Instructor"},
    %{id: 4, name: :student, title: "Student"}
  ]

  def update(
        %{user: user, section_slug: section_slug, enrollment_info: enrollment_info} = _assigns,
        socket
      ) do
    {:ok,
     assign(socket,
       enrollment: enrollment_info.enrollment,
       section_slug: section_slug,
       user: user,
       user_role_id: enrollment_info.user_role_id,
       user_role_data: @user_role_data
     )}
  end

  def render(assigns) do
    ~F"""
      {render_modal(assigns)}
      <div class="mx-10 mb-10 bg-white shadow-sm">
        <div class="flex flex-col sm:flex-row sm:items-end px-6 py-4 border instructor_dashboard_table">
          <h4 class="pl-9 !py-2 torus-h4 mr-auto dark:!text-black">Actions</h4>
        </div>

        <div class="flex justify-between items-center px-14 py-8">
          <div class="flex flex-col">
            <span class="dark:text-black">Change enrolled user role</span>
            <span class="text-xs text-gray-400 dark:text-gray-950">Select the role to change for the user in this section.</span>
          </div>
          <form phx-change="display_confirm_modal" phx-target={@myself}>
            <select class="torus-select pr-32" name="filter_by_role_id">
              {#for elem <- @user_role_data}
                <option selected={elem.id == @user_role_id} value={elem.id}>{elem.title}</option>
              {/for}
            </select>
          </form>
        </div>
      </div>
    """
  end

  def handle_event(
        "change_user_role",
        %{"filter_by_role_id" => filter_by_role_id},
        socket
      ) do
    context_role =
      case String.to_integer(filter_by_role_id) do
        3 -> ContextRoles.get_role(:context_instructor)
        4 -> ContextRoles.get_role(:context_learner)
      end

    Accounts.update_user_context_role(
      socket.assigns.enrollment,
      context_role
    )

    {:noreply,
     socket
     |> assign(user_role_id: String.to_integer(filter_by_role_id))
     |> hide_modal(modal_assigns: nil)}
  end

  def handle_event("display_confirm_modal", %{"filter_by_role_id" => filter_by_role_id}, socket) do
    modal_assigns = %{
      title: "Change role",
      id: "change_role_modal",
      ok:
        JS.push("change_user_role",
          target: socket.assigns.myself,
          value: %{"filter_by_role_id" => filter_by_role_id}
        ),
      cancel: JS.push("cancel_confirm_modal", target: socket.assigns.myself)
    }

    %{given_name: given_name, family_name: family_name} = socket.assigns.user

    modal = fn assigns ->
      ~F"""
        <Confirm {...@modal_assigns}>
          Are you sure you want to change user role to {given_name} {family_name}?
        </Confirm>
      """
    end

    {:noreply,
     show_modal(
       socket,
       modal,
       modal_assigns: modal_assigns
     )}
  end

  def handle_event("cancel_confirm_modal", _, socket) do
    {:noreply, socket |> hide_modal(modal_assigns: nil)}
  end
end
