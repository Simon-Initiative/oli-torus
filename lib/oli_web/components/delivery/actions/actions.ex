defmodule OliWeb.Components.Delivery.Actions do
  use Surface.LiveComponent
  use OliWeb.Common.Modal

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.{Accounts, Repo}
  alias OliWeb.Common.Confirm
  alias Phoenix.LiveView.JS
  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Paywall.Payment

  prop(enrollment_info, :map, required: true)
  prop(section, :map, required: true)
  prop(user, :map, required: true)

  data(enrollment, :map, default: %{})
  data(user_role_data, :list, default: [])
  data(user_role_id, :integer, default: nil)
  data(has_payment, :boolean, default: false)
  data(current_user, :map, default: %{})
  data(is_admin, :boolean, default: false)

  @user_role_data [
    %{id: 3, name: :instructor, title: "Instructor"},
    %{id: 4, name: :student, title: "Student"}
  ]

  def update(
        %{
          user: user,
          section: section,
          enrollment_info: enrollment_info
        } = _assigns,
        socket
      ) do
    %{enrollment: enrollment, user_role_id: user_role_id, current_user: current_user} =
      enrollment_info

    has_payment =
      case Repo.get_by(Payment, enrollment_id: enrollment.id) do
        nil -> false
        _ -> true
      end

    {:ok,
     assign(socket,
       enrollment: enrollment,
       section: section,
       user: user,
       user_role_id: user_role_id,
       user_role_data: @user_role_data,
       has_payment: has_payment,
       current_user: current_user,
       is_admin: Accounts.is_admin?(current_user)
     )}
  end

  def render(assigns) do
    ~F"""
      <div class="mx-10 mb-10 bg-white dark:bg-gray-800 shadow-sm">
        <div class="flex flex-col sm:flex-row sm:items-end px-6 py-4 instructor_dashboard_table">
          <h4 class="pl-9 !py-2 torus-h4 mr-auto dark:text-white">Actions</h4>
        </div>

        <div class="flex justify-between items-center px-14 py-8">
          <div class="flex flex-col">
            <span class="dark:text-white">Change enrolled user role</span>
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

        {#if @section.requires_payment and @is_admin}
          <div class="flex justify-between items-center px-14 py-8">
            <div class="flex flex-col">
              <span class="dark:text-black">Bypass payment</span>
              <span class="text-xs text-gray-400 dark:text-gray-950">Apply bypass payment</span>
            </div>
              <button
                class="torus-button flex justify-center primary h-9 w-48"
                disabled={@has_payment}
                phx-click="display_bypass_modal"
                phx-target={@myself}
              >
                Apply Bypass Payment
              </button>
          </div>
        {/if}
      </div>
    """
  end

  # Change user role

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
      cancel:
        JS.push("cancel_confirm_modal",
          target: socket.assigns.myself,
          value: %{"previous_role_id" => socket.assigns.user_role_id}
        )
    }

    %{given_name: given_name, family_name: family_name} = socket.assigns.user

    modal = fn assigns ->
      ~F"""
        <Confirm {...@modal_assigns}>
          Are you sure you want to change user role to {given_name} {family_name}?
        </Confirm>
      """
    end

    send(self(), {:show_modal, modal, modal_assigns})

    {:noreply, assign(socket, user_role_id: filter_by_role_id)}
  end

  def handle_event("cancel_confirm_modal", %{"previous_role_id" => previous_role_id}, socket) do
    send(self(), {:hide_modal})

    {:noreply, assign(socket, user_role_id: previous_role_id)}
  end

  # Bypass payment

  def handle_event(
        "bypass_payment",
        %{"current_user_id" => current_user_id, "enrollment_id" => enrollment_id},
        socket
      ) do
    case Paywall.create_payment(%{
           type: :bypass,
           generation_date: DateTime.utc_now(),
           application_date: DateTime.utc_now(),
           amount: Money.new(0, "USD"),
           section_id: socket.assigns.section.id,
           enrollment_id: enrollment_id,
           bypassed_by_user_id: current_user_id
         }) do
      {:ok, _payment} ->
        {:noreply, assign(socket, has_payment: !socket.assigns.has_payment)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("display_bypass_modal", _params, socket) do
    modal_assigns = %{
      title: "Bypass payment",
      id: "bypass_payment_modal",
      ok:
        JS.push("bypass_payment",
          target: socket.assigns.myself,
          value: %{
            "current_user_id" => socket.assigns.current_user.id,
            "enrollment_id" => socket.assigns.enrollment.id
          }
        ),
      cancel:
        JS.push("cancel_confirm_modal",
          target: socket.assigns.myself
        )
    }

    %{given_name: given_name, family_name: family_name} = socket.assigns.user

    modal = fn assigns ->
      ~F"""
        <Confirm {...@modal_assigns}>
          Are you sure you want to bypass payment for {given_name} {family_name}?
        </Confirm>
      """
    end

    send(self(), {:show_modal, modal, modal_assigns})
    {:noreply, socket}
  end

  def handle_event("cancel_confirm_modal", _params, socket) do
    send(self(), {:hide_modal})

    {:noreply, socket}
  end
end
