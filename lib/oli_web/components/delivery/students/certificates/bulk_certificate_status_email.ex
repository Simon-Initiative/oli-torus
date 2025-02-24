defmodule OliWeb.Components.Delivery.Students.Certificates.BulkCertificateStatusEmail do
  use OliWeb, :live_component

  alias OliWeb.Components.Delivery.Students.Certificates.EmailNotificationModals
  alias OliWeb.Components.Modal
  alias OliWeb.Icons

  def render(%{show_component: false} = assigns) do
    ~H"""
    <div></div>
    """
  end

  def render(%{show_component: true} = assigns) do
    ~H"""
    <button
      class="ml-auto h-5 flex space-x-4"
      phx-click={
        JS.push("show_bulk_certificate_status_email_modal")
        |> Modal.show_modal("certificate_modal")
      }
      role="bulk certificate status email"
      phx-target={@myself}
    >
      <div class="text-center text-[#3b76d3] text-xs font-semibold leading-[17.40px] whitespace-normal">
        Bulk Certificate Status Email
      </div>
      <div data-svg-wrapper class="">
        <Icons.email />
      </div>
    </button>
    """
  end

  def handle_event("show_bulk_certificate_status_email_modal", _, socket) do
    send_update(EmailNotificationModals,
      id: "certificate_email_notification_modals",
      selected_modal: :bulk_email
    )

    {:noreply, socket}
  end
end
