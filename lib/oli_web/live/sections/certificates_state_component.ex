defmodule OliWeb.Delivery.Sections.CertificateStateComponent do
  use OliWeb, :live_component

  alias Oli.Delivery.GrantedCertificates
  alias OliWeb.Icons

  def mount(socket) do
    {:ok, assign(socket, %{is_editing: false})}
  end

  def render(
        %{
          certificate_status: certificate_status,
          is_editing: false
        } = assigns
      )
      when certificate_status in [nil, :pending] do
    ~H"""
    <div class="flex w-full items-center justify-around">
      <span class="text-[#383a44] text-sm font-bold font-['Open Sans']">
        In Progress
      </span>
      <button
        :if={@certificate_status == :pending and @requires_instructor_approval}
        phx-click="edit_certificate_status"
        phx-target={@myself}
      >
        <Icons.edit />
      </button>
    </div>
    """
  end

  def render(
        %{
          requires_instructor_approval: true,
          is_editing: true
        } = assigns
      ) do
    ~H"""
    <div class="flex w-full items-center justify-center gap-2">
      <button
        phx-click="update_certificate"
        phx-target={@myself}
        phx-value-state="earned"
        class="px-3 rounded-md text-white text-xs font-normal h-[26px] bg-blue-500"
      >
        Approve
      </button>
      <button
        phx-click="update_certificate"
        phx-target={@myself}
        phx-value-state="denied"
        class="px-3 rounded-md h-[26px] w-[71px] border border-[#c03a2b] text-[#c03a2b] text-xs font-normal"
      >
        Deny
      </button>
    </div>
    """
  end

  def render(
        %{
          certificate_status: :earned
        } = assigns
      ) do
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

  def render(
        %{
          certificate_status: :denied
        } = assigns
      ) do
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

  def handle_event(
        "edit_certificate_status",
        _,
        socket
      ) do
    {:noreply, assign(socket, :is_editing, true)}
  end

  def handle_event(
        "update_certificate",
        %{"state" => state},
        socket
      ) do
    state = String.to_existing_atom(state)

    case GrantedCertificates.update_granted_certificate(
           socket.assigns.granted_certificate_id,
           %{state: state}
         ) do
      {:ok, _} ->
        {:noreply, assign(socket, certificate_status: state, is_editing: false)}

      _ ->
        {:noreply, socket}
    end
  end
end
