defmodule OliWeb.Components.Delivery.Students.Certificates.EmailNotificationModals do
  use OliWeb, :live_component

  alias Oli.Delivery.GrantedCertificates
  alias Oli.Delivery.Sections.Certificates.EmailTemplates
  alias Oli.Email
  alias Oli.Mailer
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
                phx-click={Modal.hide_modal("certificate_modal")}
                class="text-[#3c75d3] text-sm font-normal leading-[14px] h-[30px] px-4 py-2 rounded-md border border-[#3c75d3] justify-center items-center gap-2 inline-flex overflow-hidden"
              >
                Skip
              </button>
              <button
                phx-click={JS.push("send_email") |> Modal.hide_modal("certificate_modal")}
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

  def handle_event("send_email", %{"selected_modal" => selected_modal}, socket)
      when selected_modal in ["approve", "deny"] do
    %{
      selected_student: student,
      platform_name: platform_name,
      course_name: course_name,
      instructor_email: instructor_email,
      granted_certificate_id: granted_certificate_id
    } =
      socket.assigns

    selected_modal = String.to_existing_atom(selected_modal)

    email_assigns =
      Map.merge(
        %{
          student_name: Utils.name(student),
          platform_name: platform_name,
          course_name: course_name,
          instructor_email: instructor_email
        },
        if(selected_modal == :approve,
          do: %{certificate_link: url(OliWeb.Endpoint, ~p"/")},
          else: %{}
        )
      )

    # TODO:
    # 1. Add real link to certificate (only in approved case)
    # 2. mark the granted certificate as sent (a migration is required)
    # 3. Replace this email implementation -> wire with Oli.Delivery.Sections.Certificates.Workers.Mailer through
    #    Oli.Delivery.GrantedCertificates.send_email

    Email.create_email(
      student.email,
      "#{course_name}: Certificate #{action_by_selected_modal(selected_modal)}",
      email_template_by_selected_modal(selected_modal),
      email_assigns
    )
    |> Mailer.deliver()
    |> case do
      {:ok, _} ->
        GrantedCertificates.update_granted_certificate(granted_certificate_id, %{
          student_email_sent: true
        })
        |> IO.inspect(label: "a ver")

      {:error, _} ->
        send(self(), {:flash_message, {:error, "Could not send email to student"}})
    end

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
