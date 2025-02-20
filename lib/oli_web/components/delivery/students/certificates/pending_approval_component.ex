defmodule OliWeb.Components.Delivery.Students.Certificates.PendingApprovalComponent do
  use OliWeb, :live_component

  def update(%{change_pending_approvals: change_pending_approvals} = _assigns, socket) do
    updated_pending_approvals = socket.assigns.pending_approvals + change_pending_approvals
    {:ok, assign(socket, pending_approvals: updated_pending_approvals)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def render(%{pending_approvals: pending_approvals} = assigns) when pending_approvals > 0 do
    ~H"""
    <span
      id="students_pending_certificates_count"
      class="bg-[#0165da] text-white text-xs font-semibold rounded-full px-2"
    >
      <%= @pending_approvals %>
    </span>
    """
  end

  def render(assigns) do
    ~H"""
    <div></div>
    """
  end
end
