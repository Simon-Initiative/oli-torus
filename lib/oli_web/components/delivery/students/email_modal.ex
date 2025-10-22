defmodule OliWeb.Components.Delivery.Students.EmailModal do
  use OliWeb, :live_component

  alias OliWeb.Components.Modal
  alias OliWeb.Common.Utils
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <div id="email_modal_wrapper">
      <div
        id="email_modal_container"
        phx-hook="OnMountAndUpdate"
        data-event={if @show_modal, do: Modal.show_modal("email_modal"), else: ""}
      >
        <Modal.modal
          id="email_modal"
          class="w-[800px]"
          header_class="flex items-start justify-between px-[35px] pt-[27px] pb-4"
          body_class="border-t border-Border-border-subtle px-[35px] pb-[50px] pt-[30px]"
          on_cancel={JS.push("close_email_modal", target: @myself)}
        >
          <:title>Email Students</:title>

          <div class="text-sm font-normal mt-3">
            <p class="text-Text-text-high mb-6">
              {this_email_will_send_message(@selected_students, @students)}
            </p>

            <div class="mb-6">
              <h3 class="text-sm font-bold text-Text-text-high mb-3">
                Type a new email message
              </h3>
              <textarea
                id="email_message"
                name="email_message"
                placeholder="Type here..."
                class="w-full h-32 p-3 border border-Border-border-default rounded-md resize-none focus:ring-2 focus:ring-Fill-Buttons-fill-primary focus:border-transparent bg-Specially-Tokens-Fill-fill-input text-Text-text-high"
                phx-target={@myself}
                phx-blur="update_message"
              ><%= @email_message %></textarea>
            </div>

            <div class="mb-6">
              <h3 class="text-sm font-bold text-Text-text-high mb-3">
                Or, copy and paste from the email templates below
              </h3>
              <div class="grid grid-cols-2 gap-4">
                <div class="border border-Border-border-default rounded-lg p-4 relative">
                  <button
                    class="absolute top-2 right-2 text-Icon-icon-default hover:text-Icon-icon-hover"
                    id="email_modal_below_expected_button"
                    phx-hook="CopyToClipboard"
                    data-copy-text="Hello,

    Your progress on [course material] appears to be below expected levels. Please review the material and continue working through the material. Let me know if you have questions.

    Best,
    [Instructor Name]"
                    phx-click={JS.push("copy_template", value: %{template: "low_progress"})}
                    phx-target={@myself}
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                      >
                      </path>
                    </svg>
                  </button>
                  <h4 class="font-bold text-sm mb-2">LOW STUDENT PROGRESS</h4>
                  <p class="text-xs text-Text-text-low">
                    Hello,<br /><br /> Your progress on <strong>[course material]</strong>
                    appears to be below expected levels. Please review the material and continue working through the material. Let me know if you have questions.<br /><br />
                    Best,<br />
                    <strong>[Instructor Name]</strong>
                  </p>
                </div>

                <div class="border border-Border-border-default rounded-lg p-4 relative">
                  <button
                    class="absolute top-2 right-2 text-Icon-icon-default hover:text-Icon-icon-hover"
                    id="email_modal_due_soon_button"
                    phx-hook="CopyToClipboard"
                    data-copy-text="Hello,

    This is a reminder that [course material] is due soon and has not yet been completed. Please complete it before the deadline. Let me know if clarification is needed.

    Best,
    [Instructor Name]"
                    phx-click={JS.push("copy_template", value: %{template: "approaching_due_date"})}
                    phx-target={@myself}
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                      >
                      </path>
                    </svg>
                  </button>
                  <h4 class="font-bold text-sm mb-2">APPROACHING DUE DATE</h4>
                  <p class="text-xs text-Text-text-low">
                    Hello,<br /><br /> This is a reminder that <strong>[course material]</strong>
                    is due soon and has not yet been completed. Please complete it before the deadline. Let me know if clarification is needed.<br /><br />
                    Best,<br />
                    <strong>[Instructor Name]</strong>
                  </p>
                </div>
              </div>
            </div>
          </div>

          <:custom_footer>
            <div class="flex justify-end space-x-4 w-full h-24 px-[35px]">
              <button
                role="cancel"
                phx-click={
                  Modal.hide_modal(JS.push("close_email_modal", target: @myself), "email_modal")
                }
                class="text-Text-text-button text-sm font-normal leading-[14px] h-[30px] px-4 py-2 rounded-md border border-Fill-Buttons-fill-primary justify-center items-center gap-2 inline-flex overflow-hidden"
              >
                Cancel
              </button>
              <button
                role="send email"
                phx-click={Modal.hide_modal(JS.push("send_email", target: @myself), "email_modal")}
                disabled={String.trim(@email_message) == ""}
                class={[
                  "text-sm font-semibold leading-[14px] h-[30px] px-4 py-2 rounded-md border justify-center items-center gap-2 inline-flex overflow-hidden",
                  if(String.trim(@email_message) == "",
                    do:
                      "text-Text-text-low-alpha bg-Fill-Buttons-fill-muted border-Border-border-default cursor-not-allowed",
                    else:
                      "text-Text-text-white bg-Fill-Buttons-fill-primary border-Fill-Buttons-fill-primary hover:bg-Fill-Buttons-fill-primary-hover"
                  )
                ]}
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

  def mount(socket) do
    {:ok, assign(socket, email_message: "", show_modal: false)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def handle_event("update_message", params, socket) do
    message = Map.get(params, "value", "")
    {:noreply, assign(socket, email_message: message)}
  end

  def handle_event("copy_template", %{"template" => template}, socket) do
    message =
      case template do
        "low_progress" ->
          """
          Hello,

          Your progress on [course material] appears to be below expected levels. Please review the material and continue working through the material. Let me know if you have questions.

          Best,
          [Instructor Name]
          """

        "approaching_due_date" ->
          """
          Hello,

          This is a reminder that [course material] is due soon and has not yet been completed. Please complete it before the deadline. Let me know if clarification is needed.

          Best,
          [Instructor Name]
          """
      end

    {:noreply,
     socket
     |> assign(email_message: String.trim(message))
     |> put_flash(:info, "Template copied to clipboard")}
  end

  def handle_event("send_email", _params, socket) do
    if String.trim(socket.assigns.email_message) != "" do
      student_emails =
        socket.assigns.selected_students
        |> Oli.Accounts.get_user_emails_by_ids()
        |> Enum.reject(&is_nil/1)

      send_student_emails(
        student_emails,
        socket.assigns.email_message,
        socket.assigns.section_title,
        socket.assigns.instructor_email
      )

      # Send flash message to parent LiveView
      send(self(), {:flash_message, {:info, "Emails sent successfully"}})
      send(self(), {:hide_email_modal, socket.assigns[:email_handler_id]})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_email_modal", _params, socket) do
    send(self(), {:hide_email_modal, socket.assigns[:email_handler_id]})
    {:noreply, socket}
  end

  defp send_student_emails(student_emails, message, course_name, instructor_email) do
    student_emails
    |> Enum.map(fn student_email ->
      Oli.Email.create_text_email(
        student_email,
        "Note from your #{course_name} Instructor #{instructor_email}",
        message
      )
    end)
    |> Oli.Mailer.deliver_later()
  end

  defp this_email_will_send_message([selected_student_id], students) do
    student = Enum.find(students, fn s -> s.id == selected_student_id end)

    student_full_name =
      student[:full_name] || Utils.name(student.name, student.given_name, student.family_name)

    assigns = %{student_name: student_full_name, student_email: student.email}

    if student.email do
      ~H"""
      This email will send to <strong>{@student_name}</strong>
      at <strong><%= @student_email %></strong>.
      """
    else
      ~H"""
      <span class="text-Text-text-danger font-semibold">
        Email cannot be sent because the student does not have an email address associated.
      </span>
      """
    end
  end

  defp this_email_will_send_message(selected_students_ids, students) do
    selected_students = Enum.filter(students, fn s -> s.id in selected_students_ids end)
    students_with_email = Enum.filter(selected_students, & &1.email)
    students_without_email = Enum.reject(selected_students, & &1.email)

    assigns = %{
      students_with_email: students_with_email,
      students_without_email: students_without_email
    }

    ~H"""
    This email will send separately to <strong><%= length(@students_with_email) %> students</strong>.
    <%= if length(@students_without_email) > 0 do %>
      <br />
      {length(@students_without_email)} of the selected students do not have an associated email.
    <% end %>
    """
  end
end
