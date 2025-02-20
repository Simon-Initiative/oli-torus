defmodule OliWeb.Components.Delivery.Students.Certificates.EmailNotificationModals do
  use OliWeb, :live_component

  alias Oli.Delivery.Sections.Certificates.EmailTemplates
  alias OliWeb.Common.Utils
  alias OliWeb.Components.Modal

  def render(%{selected_student: nil} = assigns) do
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
              <.template_by_selected_modal
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
                phx-click={Modal.hide_modal("certificate_modal")}
                class="text-[#3c75d3] text-sm font-normal leading-[14px] h-[30px] px-4 py-2 rounded-md border border-[#3c75d3] justify-center items-center gap-2 inline-flex overflow-hidden"
              >
                Skip
              </button>
              <button
                phx-click="send_email"
                phx-value-selected_modal={@selected_modal}
                phx-target={@myself}
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

  def handle_event("send_email", _, socket) do
    # TODO
    {:noreply, socket}
  end

  def template_by_selected_modal(%{selected_modal: :approve} = assigns) do
    ~H"""
    <EmailTemplates.student_approval
      student_name={@student_name}
      platform_name={@platform_name}
      course_name={@course_name}
    />
    """
  end

  def template_by_selected_modal(%{selected_modal: :deny} = assigns) do
    ~H"""
    <EmailTemplates.student_denial
      student_name={@student_name}
      platform_name={@platform_name}
      course_name={@course_name}
      instructor_email={@instructor_email}
    />
    """
  end

  defp title_by_selected_modal(:approve), do: "Certificate Approval Email"
  defp title_by_selected_modal(:deny), do: "Certificate Denial Email"

  defp action_by_selected_modal(:approve), do: "approval"
  defp action_by_selected_modal(:deny), do: "denial"
end
