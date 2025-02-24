defmodule OliWeb.Components.Delivery.Students.Certificates.StateApprovalComponent do
  use OliWeb, :live_component

  alias Oli.Delivery.GrantedCertificates

  alias OliWeb.Components.Delivery.Students.Certificates.{
    BulkCertificateStatusEmail,
    EmailNotificationModals,
    PendingApprovalComponent
  }

  alias OliWeb.Components.Modal
  alias OliWeb.Icons

  def mount(socket) do
    {:ok, assign(socket, %{is_editing: false})}
  end

  def render(%{requires_instructor_approval: true, certificate_status: :pending} = assigns) do
    ~H"""
    <div role="instructor pending approval status">
      <.approve_or_deny_buttons
        target={@myself}
        current_state={@certificate_status}
        show_modal?={true}
      />
    </div>
    """
  end

  def render(%{is_editing: true} = assigns) do
    ~H"""
    <div role="editing status">
      <.approve_or_deny_buttons target={@myself} current_state={@certificate_status} />
    </div>
    """
  end

  def render(%{certificate_status: nil} = assigns) do
    # edge case where the granted certificate is not yet created
    # (the student has not yet met all of the thresholds)
    ~H"""
    <div role="in progress status" class="flex w-full justify-between px-6">
      <span class="text-[#383a44] text-sm font-bold font-['Open Sans']">
        In Progress
      </span>
      <button phx-click="edit_certificate_status" phx-target={@myself}>
        <Icons.edit />
      </button>
    </div>
    """
  end

  def render(%{certificate_status: :earned} = assigns) do
    ~H"""
    <div role="approved status" class="flex w-full justify-between px-6">
      <span class="text-[#0165da] text-sm font-bold">
        Approved
      </span>
      <button phx-click="edit_certificate_status" phx-target={@myself}>
        <Icons.edit />
      </button>
    </div>
    """
  end

  def render(%{certificate_status: :denied} = assigns) do
    ~H"""
    <div role="denied status" class="flex w-full justify-between px-6">
      <span class="text-[#c03a2b] text-sm font-bold">
        Denied
      </span>
      <button phx-click="edit_certificate_status" phx-target={@myself}>
        <Icons.edit />
      </button>
    </div>
    """
  end

  attr :target, Phoenix.LiveComponent.CID, required: true
  attr :current_state, :string, required: true

  attr :show_modal?, :boolean,
    default: false,
    doc:
      "Whether to show the email notification modal after the instructor approves or denies the certificate"

  def approve_or_deny_buttons(assigns) do
    ~H"""
    <div role="approve or deny buttons" class="flex w-full justify-center gap-2 px-1">
      <button
        phx-click={
          if @show_modal?,
            do: JS.push("update_certificate") |> Modal.show_modal("certificate_modal"),
            else: JS.push("update_certificate")
        }
        phx-target={@target}
        phx-value-required_state="earned"
        phx-value-current_state={@current_state || "new_certificate_required"}
        class="px-3 rounded-md text-white text-xs font-normal h-[26px] bg-blue-500"
      >
        Approve
      </button>
      <button
        phx-click={
          if @show_modal?,
            do: JS.push("update_certificate") |> Modal.show_modal("certificate_modal"),
            else: JS.push("update_certificate")
        }
        phx-target={@target}
        phx-value-required_state="denied"
        phx-value-current_state={@current_state || "new_certificate_required"}
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
        %{"required_state" => required_state, "current_state" => "new_certificate_required"},
        socket
      ) do
    required_state = String.to_existing_atom(required_state)

    case GrantedCertificates.create_granted_certificate(%{
           user_id: socket.assigns.student.id,
           certificate_id: socket.assigns.certificate_id,
           state: required_state,
           with_distinction: false,
           guid: UUID.uuid4(),
           issued_by: socket.assigns.issued_by_id,
           issued_by_type: socket.assigns.issued_by_type,
           issued_at: DateTime.utc_now(),
           # the url will be provided later once the .pdf is generated
           # (in case the certificate has an :earned state)
           url: nil
         }) do
      {:ok, granted_certificate} ->
        # show the bulk email notification component
        # (when manually granting a certificate, no email is sent to that student)
        send_update(BulkCertificateStatusEmail,
          id: "bulk_email_certificate_status_component",
          show_component: true
        )

        {:noreply,
         assign(socket,
           is_editing: false,
           certificate_status: required_state,
           granted_certificate_id: granted_certificate.id
         )}

      {:error, _changeset} ->
        send(self(), {:flash_message, {:error, "Could not update certificate status"}})
        {:noreply, assign(socket, is_editing: false)}
    end
  end

  def handle_event(
        "update_certificate",
        %{"required_state" => required_state, "current_state" => current_state},
        socket
      ) do
    required_state = String.to_existing_atom(required_state)

    # we set the url to nil to invalidate any previous .pdf (if any)
    case GrantedCertificates.update_granted_certificate(
           socket.assigns.granted_certificate_id,
           %{state: required_state, url: nil}
         ) do
      {:ok, gc} ->
        if socket.assigns.requires_instructor_approval and current_state == "pending" do
          # decrease the number of pending approvals
          send_update(PendingApprovalComponent,
            id: "certificate_pending_approval_count_badge",
            change_pending_approvals: -1
          )

          # show the corresponding email notification modal
          send_update(EmailNotificationModals,
            id: "certificate_email_notification_modals",
            selected_student: socket.assigns.student,
            selected_modal: if(required_state == :earned, do: :approve, else: :deny),
            granted_certificate_id: gc.id
          )
        end

        {:noreply, assign(socket, certificate_status: required_state, is_editing: false)}

      _ ->
        send(self(), {:flash_message, {:error, "Could not update certificate status"}})
        {:noreply, assign(socket, is_editing: false)}
    end
  end
end
