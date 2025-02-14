defmodule OliWeb.Components.Delivery.Students.Certificates.StateApprovalComponent do
  use OliWeb, :live_component

  alias Oli.Delivery.GrantedCertificates
  alias OliWeb.Components.Delivery.Students.Certificates.PendingApprovalComponent
  alias OliWeb.Icons

  def mount(socket) do
    {:ok, assign(socket, %{is_editing: false})}
  end

  def render(%{requires_instructor_approval: true, certificate_status: :pending} = assigns) do
    ~H"""
    <div><.approve_or_deny_buttons target={@myself} current_state={@certificate_status} /></div>
    """
  end

  def render(%{is_editing: true} = assigns) do
    ~H"""
    <div><.approve_or_deny_buttons target={@myself} current_state={@certificate_status} /></div>
    """
  end

  def render(%{certificate_status: nil} = assigns) do
    # edge case where the granted certificate is not yet created
    # (the student has not yet met all of the thresholds)
    # TODO: allow to edit (a certificate must be created after the edit action - approve or deny -)
    ~H"""
    <div class="flex w-full items-center justify-around">
      <span class="text-[#383a44] text-sm font-bold font-['Open Sans']">
        In Progress
      </span>
    </div>
    """
  end

  def render(%{certificate_status: :earned} = assigns) do
    ~H"""
    <div class="flex w-full items-center justify-around">
      <span class="text-[#0165da] text-sm font-bold">
        Approved
      </span>
      <button
        :if={@requires_instructor_approval}
        phx-click="edit_certificate_status"
        phx-target={@myself}
      >
        <Icons.edit />
      </button>
    </div>
    """
  end

  def render(%{certificate_status: :denied} = assigns) do
    ~H"""
    <div class="flex w-full items-center justify-around">
      <span class="text-[#c03a2b] text-sm font-bold">
        Denied
      </span>
      <button
        :if={@requires_instructor_approval}
        phx-click="edit_certificate_status"
        phx-target={@myself}
      >
        <Icons.edit />
      </button>
    </div>
    """
  end

  attr :target, Phoenix.LiveComponent.CID, required: true
  attr :current_state, :string, required: true

  def approve_or_deny_buttons(assigns) do
    ~H"""
    <div class="flex w-full items-center justify-center gap-2">
      <button
        phx-click="update_certificate"
        phx-target={@target}
        phx-value-required_state="earned"
        phx-value-current_state={@current_state}
        class="px-3 rounded-md text-white text-xs font-normal h-[26px] bg-blue-500"
      >
        Approve
      </button>
      <button
        phx-click="update_certificate"
        phx-target={@target}
        phx-value-required_state="denied"
        phx-value-current_state={@current_state}
        class="px-3 rounded-md h-[26px] w-[71px] border border-[#c03a2b] text-[#c03a2b] text-xs font-normal"
      >
        Deny
      </button>
    </div>
    """
  end

  def handle_event(
        "edit_certificate_status",
        _,
        socket
      ) do
    {:noreply, assign(socket, :is_editing, true)}
  end

  def handle_event(
        "update_certificate",
        %{"required_state" => required_state, "current_state" => current_state},
        socket
      )
      when required_state == current_state do
    {:noreply, assign(socket, is_editing: false)}
  end

  def handle_event(
        "update_certificate",
        %{"required_state" => _required_state, "current_state" => nil},
        socket
      ) do
    # TODO: If we want to allow editing a certificate status of a certificate that has not yet been granted,
    # then this handle event should trigger the creation of the granted certificate for that user.
    {:noreply, assign(socket, is_editing: false)}
  end

  def handle_event(
        "update_certificate",
        %{"required_state" => required_state, "current_state" => current_state},
        socket
      ) do
    required_state = String.to_existing_atom(required_state)

    case GrantedCertificates.update_granted_certificate(
           socket.assigns.granted_certificate_id,
           %{state: required_state}
         ) do
      {:ok, _} ->
        if socket.assigns.requires_instructor_approval and current_state == "pending",
          # decrease the number of pending approvals
          do:
            send_update(PendingApprovalComponent,
              id: "certificate_pending_approval_count_badge",
              change_pending_approvals: -1
            )

        {:noreply, assign(socket, certificate_status: required_state, is_editing: false)}

      _ ->
        send(self(), {:flash_message, {:error, "Could not update certificate status"}})
        {:noreply, assign(socket, is_editing: false)}
    end
  end
end
