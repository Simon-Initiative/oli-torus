defmodule OliWeb.Components.Delivery.Students.Certificates.EmailNotificationModals do
  use OliWeb, :live_component

  alias Oli.Delivery.GrantedCertificates
  alias Oli.Delivery.Sections.Certificates.EmailTemplates
  alias OliWeb.Common.Utils
  alias OliWeb.Components.Delivery.Students.Certificates.BulkCertificateStatusEmail
  alias OliWeb.Components.Modal

  def render(%{selected_student: nil, selected_modal: nil} = assigns) do
    ~H"""
    <div></div>
    """
  end

  def render(%{selected_modal: selected_modal} = assigns)
      when selected_modal in [:approve, :deny] do
    ~H"""
    <div>
      <div
        id="email_modal_container"
        phx-hook="OnMountAndUpdate"
        data-event={Modal.show_modal("certificate_modal")}
      >
        <Modal.modal
          id="certificate_modal"
          class="w-[1000px]"
          header_class="flex items-start justify-between px-[35px] pt-[27px] pb-4"
          body_class="border-t border-[#d4d4d4] dark:border-[#3e3f44] px-[35px] pb-[50px] pt-[30px]"
        >
          <:title><%= title_by_selected_modal(@selected_modal) %></:title>
          <div class="text-sm font-normal mt-3">
            <p class="text-black">
              Please confirm that you want to send <%= Utils.name(@selected_student) %> a
              <span class="font-bold">
                certificate <%= action_by_selected_modal(@selected_modal) %>
              </span>
              email.
            </p>
            <h3 class="text-sm text-black font-bold mt-10 mb-5">
              <%= title_by_selected_modal(@selected_modal) %>:
            </h3>
            <div class="p-6 border rounded-lg border-[#CBD2E0]">
              <.preview_template_by_selected_modal
                student_name={Utils.name(@selected_student)}
                platform_name={@platform_name}
                course_name={@course_name}
                instructor_email={@instructor_email}
                selected_modal={@selected_modal}
              />
            </div>
          </div>
          <:custom_footer>
            <div class="flex justify-end space-x-4 w-full h-24 px-[35px]">
              <button
                phx-click={
                  JS.push("skip_email_notification") |> Modal.hide_modal("certificate_modal")
                }
                class="text-[#3c75d3] text-sm font-normal leading-[14px] h-[30px] px-4 py-2 rounded-md border border-[#3c75d3] justify-center items-center gap-2 inline-flex overflow-hidden"
                phx-target={@myself}
                role="skip email"
              >
                Skip
              </button>
              <button
                phx-click={JS.push("send_email") |> Modal.hide_modal("certificate_modal")}
                phx-value-selected_modal={@selected_modal}
                phx-target={@myself}
                role="send email"
                class="text-white text-sm font-semibold leading-[14px] h-[30px] px-4 py-2 bg-[#0062f2] rounded-md border border-[#0062f2] justify-center items-center gap-2 inline-flex overflow-hidden"
              >
                Send Email
              </button>
            </div>
          </:custom_footer>
        </Modal.modal>
      </div>
    </div>
    """
  end

  def render(%{selected_modal: :bulk_email} = assigns) do
    ~H"""
    <div>
      <div
        id="email_modal_container"
        phx-hook="OnMountAndUpdate"
        data-event={Modal.show_modal("certificate_modal")}
      >
        <Modal.modal
          id="certificate_modal"
          class="w-[1000px]"
          header_class="flex items-start justify-between px-[35px] pt-[27px] pb-4"
          body_class="border-t border-[#d4d4d4] dark:border-[#3e3f44] px-[35px] pb-[50px] pt-[30px]"
        >
          <:title>Certificate Status Email</:title>
          <div class="text-sm font-normal mt-3">
            <p class="text-black">
              Please confirm that you want to send <span class="font-bold">all students</span>
              who
              <span class="font-bold">
                have not yet been emailed their certificate status
              </span>
              an email regarding their status as approved or denied.
            </p>
            <div class="flex space-x-12">
              <div class="w-1/2">
                <h3 class="text-sm text-black font-bold mt-10 mb-5">
                  Certificate Denial Email:
                </h3>
                <div class="p-6 border rounded-lg border-[#CBD2E0] h-[430px] overflow-y-scroll">
                  <.preview_template_by_selected_modal
                    student_name="[Student]"
                    platform_name={@platform_name}
                    course_name={@course_name}
                    instructor_email={@instructor_email}
                    selected_modal={:deny}
                  />
                </div>
              </div>
              <div class="w-1/2">
                <h3 class="text-sm text-black font-bold mt-10 mb-5">
                  Certificate Approval Email:
                </h3>
                <div class="p-6 border rounded-lg border-[#CBD2E0] h-[430px] overflow-y-scroll">
                  <.preview_template_by_selected_modal
                    student_name="[Student]"
                    platform_name={@platform_name}
                    course_name={@course_name}
                    selected_modal={:approve}
                  />
                </div>
              </div>
            </div>
          </div>
          <:custom_footer>
            <div class="flex justify-end space-x-4 w-full h-24 px-[35px]">
              <button
                role="cancel"
                phx-click={Modal.hide_modal("certificate_modal")}
                class="text-[#3c75d3] text-sm font-normal leading-[14px] h-[30px] px-4 py-2 rounded-md border border-[#3c75d3] justify-center items-center gap-2 inline-flex overflow-hidden"
              >
                Cancel
              </button>
              <button
                role="bulk send emails"
                phx-click={JS.push("bulk_send_emails") |> Modal.hide_modal("certificate_modal")}
                phx-target={@myself}
                class="text-white text-sm font-semibold leading-[14px] h-[30px] px-4 py-2 bg-[#0062f2] rounded-md border border-[#0062f2] justify-center items-center gap-2 inline-flex overflow-hidden"
              >
                Send Emails
              </button>
            </div>
          </:custom_footer>
        </Modal.modal>
      </div>
    </div>
    """
  end

  def handle_event("skip_email_notification", _, socket) do
    send_update(BulkCertificateStatusEmail,
      id: "bulk_email_certificate_status_component",
      show_component: true
    )

    {:noreply, socket}
  end

  def handle_event("send_email", %{"selected_modal" => selected_modal}, socket)
      when selected_modal in ["approve", "deny"] do
    %{
      selected_student: student,
      granted_certificate_id: granted_certificate_id
    } =
      socket.assigns

    selected_modal = String.to_existing_atom(selected_modal)

    # TODO: check on  MER-4107:
    # 1. if more assigns need to be provided
    # (for instance, platform_name, course_name, instructor_email, and any info to build the url link to the pdf for approved certificates)
    # 2. if the granted_certificate is updated to mark the student_email_sent field as true
    GrantedCertificates.send_certificate_email(
      granted_certificate_id,
      student.email,
      email_template_by_selected_modal(selected_modal),
      %{some: :assigns_depending_on_the_email_template}
    )

    {:noreply, socket}
  end

  def handle_event("bulk_send_emails", _, socket) do
    GrantedCertificates.bulk_send_certificate_status_email(socket.assigns.section_slug)

    {:noreply, socket}
  end

  def preview_template_by_selected_modal(%{selected_modal: :approve} = assigns) do
    ~H"""
    <EmailTemplates.student_approval
      student_name={@student_name}
      platform_name={@platform_name}
      course_name={@course_name}
    />
    """
  end

  def preview_template_by_selected_modal(%{selected_modal: :deny} = assigns) do
    ~H"""
    <EmailTemplates.student_denial
      student_name={@student_name}
      platform_name={@platform_name}
      course_name={@course_name}
      instructor_email={@instructor_email}
    />
    """
  end

  defp email_template_by_selected_modal(:approve), do: :certificate_approval
  defp email_template_by_selected_modal(:deny), do: :certificate_denial

  defp title_by_selected_modal(:approve), do: "Certificate Approval Email"
  defp title_by_selected_modal(:deny), do: "Certificate Denial Email"

  defp action_by_selected_modal(:approve), do: "approval"
  defp action_by_selected_modal(:deny), do: "denial"
end
