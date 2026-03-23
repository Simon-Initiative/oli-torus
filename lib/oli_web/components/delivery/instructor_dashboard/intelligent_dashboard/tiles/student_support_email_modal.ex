defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.StudentSupportEmailModal do
  use OliWeb, :live_component

  alias Oli.Delivery.EmailSender
  alias OliWeb.Components.DesignTokens.Primitives.Button
  alias OliWeb.Components.Modal
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  # TODO MER-5257: Extend this Student Support-specific modal with the future
  # AI draft generation, tone controls, placeholder handling, and manual
  # recipient entry defined for the broader draft-email workflow.
  @temporary_default_subjects %{
    # TODO MER-5257: Replace these temporary bucket-based subjects with
    # context-aware AI-generated draft subjects.
    "struggling" => "Checking in about your course progress",
    "excelling" => "Great progress in your course",
    "on_track" => "Checking in about your course progress",
    "not_enough_information" => "Checking in about your course activity"
  }

  def render(assigns) do
    assigns =
      assigns
      |> assign(:excluded_recipient_students, excluded_recipient_students(assigns))
      |> assign(:excluded_recipient_count, excluded_recipient_count(assigns))
      |> assign(:send_disabled, send_disabled?(assigns))

    ~H"""
    <div id="student_support_email_modal_wrapper">
      <Modal.modal
        id="student_support_email_modal"
        class="max-w-[1048px] rounded-[12px] overflow-hidden"
        header_class="flex items-start justify-between bg-Background-bg-primary px-[38px] pt-[30px] pb-5"
        body_class="bg-Background-bg-primary px-[38px] pt-4 pb-0"
        show={@show_modal}
        show_close={false}
        on_cancel={JS.push("close_email_modal", target: @myself)}
      >
        <:title>
          <span class="text-[24px] font-bold leading-8 text-Text-text-high">Draft Email</span>
        </:title>
        <:header_actions>
          <Button.button
            variant={:close}
            aria-label="Close draft email modal"
            phx-click={
              Modal.hide_modal(
                JS.push("close_email_modal", target: @myself),
                "student_support_email_modal"
              )
            }
          />
        </:header_actions>

        <div class="space-y-3">
          <div class="space-y-1">
            <label class="text-sm font-semibold leading-4 text-Text-text-low-alpha">To:</label>
            <div class="min-h-[40px] w-full rounded-[6px] border border-Border-border-default bg-Surface-surface-primary px-3 py-2">
              <div
                id="student_support_email_recipients"
                phx-hook="OverflowChipList"
                class="flex items-center gap-1 overflow-hidden whitespace-nowrap"
              >
                <%= for student <- @recipient_students do %>
                  <div
                    data-overflow-chip
                    class="inline-flex shrink-0 items-center gap-1 rounded-[12px] bg-Fill-Chip-Gray px-2 py-1"
                  >
                    <button
                      type="button"
                      phx-click="remove_recipient"
                      phx-target={@myself}
                      phx-value-student_id={student.id}
                      class="inline-flex h-4 w-4 items-center justify-center text-Text-text-high"
                      aria-label={"Recipient: #{student.email}, remove"}
                    >
                      <Icons.close_sm class="h-4 w-4 stroke-current" />
                    </button>
                    <span
                      class="max-w-[220px] truncate text-sm font-semibold leading-4 text-Text-text-high"
                      title={student.email}
                    >
                      {student.email}
                    </span>
                  </div>
                <% end %>
                <button
                  type="button"
                  data-overflow-toggle
                  class="hidden shrink-0 items-center rounded-[12px] bg-Fill-Chip-Gray px-3 py-1 text-sm font-semibold leading-4 text-Text-text-high"
                  aria-label="Show all recipients"
                >
                  ...
                </button>
              </div>
            </div>
            <p
              :if={@excluded_recipient_count > 0}
              class="text-sm leading-5 text-Text-text-low-alpha"
            >
              <span
                class="cursor-pointer underline decoration-dotted underline-offset-2"
                title={excluded_recipient_names(@excluded_recipient_students)}
                tabindex="0"
              >
                {excluded_recipient_subject(@excluded_recipient_count)}
              </span>
              <span>
                {excluded_recipient_message_suffix(@excluded_recipient_count, @recipient_students)}
              </span>
            </p>
          </div>

          <div class="space-y-1">
            <label
              for="student_support_email_subject"
              class="text-sm font-semibold leading-4 text-Text-text-low-alpha"
            >
              Subject:
            </label>
            <input
              id="student_support_email_subject"
              type="text"
              value={@subject}
              phx-target={@myself}
              phx-keyup="update_subject"
              phx-blur="update_subject"
              phx-debounce="200"
              class="h-[40px] w-full rounded-[6px] border border-Border-border-default bg-Surface-surface-primary px-4 text-base leading-6 text-Text-text-high focus:outline-none focus:ring-2 focus:ring-Fill-Buttons-fill-primary"
            />
          </div>

          <div class="space-y-1">
            <label
              for="student_support_email_body"
              class="text-sm font-semibold leading-4 text-Text-text-low-alpha"
            >
              Body:
            </label>
            <textarea
              id="student_support_email_body"
              phx-target={@myself}
              phx-keyup="update_body"
              phx-blur="update_body"
              phx-debounce="200"
              class="h-[255px] w-full resize-none rounded-[6px] border border-Border-border-default bg-Surface-surface-primary px-4 py-3 text-base leading-6 text-Text-text-high focus:outline-none focus:ring-2 focus:ring-Fill-Buttons-fill-primary"
            ><%= @body %></textarea>
          </div>
        </div>

        <:custom_footer>
          <div class="relative z-10 flex items-center justify-end gap-3 border-t border-Border-border-subtle bg-Background-bg-primary px-[38px] py-5">
            <Button.button
              variant={:secondary}
              size={:sm}
              phx-click={
                Modal.hide_modal(
                  JS.push("close_email_modal", target: @myself),
                  "student_support_email_modal"
                )
              }
            >
              Cancel
            </Button.button>
            <Button.button
              variant={:primary}
              size={:sm}
              disabled={@send_disabled}
              role="send email"
              class="relative z-10"
              phx-click={
                Modal.hide_modal(
                  JS.push("send_email", target: @myself),
                  "student_support_email_modal"
                )
              }
            >
              Send
              <:icon_right>
                <Icons.send class="h-5 w-5 stroke-current" />
              </:icon_right>
            </Button.button>
          </div>
        </:custom_footer>
      </Modal.modal>
    </div>
    """
  end

  def mount(socket) do
    {:ok,
     assign(socket,
       show_modal: false,
       subject: "",
       body: "",
       recipient_students: []
     )}
  end

  def update(assigns, socket) do
    show_modal = Map.get(assigns, :show_modal, socket.assigns[:show_modal] || false)
    was_open? = socket.assigns[:show_modal] || false

    socket =
      socket
      |> assign(assigns)
      |> assign(:show_modal, show_modal)

    if show_modal and not was_open? do
      {:ok,
       socket
       |> assign(
         :recipient_students,
         normalize_recipient_students(Map.get(assigns, :students, []))
       )
       |> assign(:subject, temporary_default_subject(Map.get(assigns, :selected_bucket_id)))
       |> assign(:body, initial_body())}
    else
      {:ok, socket}
    end
  end

  def handle_event("remove_recipient", %{"student_id" => student_id}, socket) do
    case Integer.parse(student_id) do
      {parsed_student_id, ""} ->
        {:noreply,
         update(socket, :recipient_students, fn recipient_students ->
           Enum.reject(recipient_students, &(&1.id == parsed_student_id))
         end)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("update_subject", %{"value" => subject}, socket) do
    {:noreply, assign(socket, :subject, subject)}
  end

  def handle_event("update_body", %{"value" => body}, socket) do
    {:noreply, assign(socket, :body, body)}
  end

  def handle_event("send_email", _params, socket) do
    if send_disabled?(socket.assigns) do
      {:noreply, socket}
    else
      recipient_emails = Enum.map(socket.assigns.recipient_students, & &1.email)

      {:ok, _count} =
        EmailSender.deliver_text_emails(
          recipient_emails,
          String.trim(socket.assigns.subject),
          String.trim(socket.assigns.body),
          socket.assigns.instructor_email,
          socket.assigns[:instructor_name] || "Instructor"
        )

      send(self(), {:flash_message, {:info, "Email sent"}})
      send(self(), {:hide_email_modal, socket.assigns[:email_handler_id]})

      {:noreply, socket}
    end
  end

  def handle_event("close_email_modal", _params, socket) do
    send(self(), {:hide_email_modal, socket.assigns[:email_handler_id]})
    {:noreply, socket}
  end

  defp normalize_recipient_students(students) do
    students
    |> Enum.filter(&(is_binary(&1.email) and String.trim(&1.email) != ""))
    |> Enum.uniq_by(& &1.id)
  end

  defp valid_recipient_count(recipient_students) do
    recipient_students
    |> Enum.map(& &1.email)
    |> EmailSender.normalize_recipient_emails()
    |> length()
  end

  defp excluded_recipient_students(assigns) do
    assigns
    |> Map.get(:students, [])
    |> Enum.reject(&(is_binary(&1.email) and String.trim(&1.email) != ""))
  end

  defp excluded_recipient_count(assigns) do
    assigns
    |> excluded_recipient_students()
    |> length()
  end

  defp send_disabled?(assigns) do
    valid_recipient_count(assigns.recipient_students) == 0 or
      String.trim(assigns.subject) == "" or
      String.trim(assigns.body) == ""
  end

  defp excluded_recipient_subject(1), do: "1 selected student"

  defp excluded_recipient_subject(excluded_count), do: "#{excluded_count} selected students"

  defp excluded_recipient_message_suffix(1, []),
    do: " does not have an associated email."

  defp excluded_recipient_message_suffix(_excluded_count, []),
    do: " do not have associated email addresses."

  defp excluded_recipient_message_suffix(1, _recipient_students),
    do: " does not have an associated email and will not receive this message."

  defp excluded_recipient_message_suffix(_excluded_count, _recipient_students),
    do: " do not have associated email addresses and will not receive this message."

  defp excluded_recipient_names(excluded_recipient_students) do
    excluded_recipient_students
    |> Enum.map(&Map.get(&1, :display_name, "Unknown student"))
    |> Enum.join(", ")
  end

  defp temporary_default_subject(bucket_id) do
    Map.get(
      @temporary_default_subjects,
      bucket_id,
      @temporary_default_subjects["not_enough_information"]
    )
  end

  defp initial_body do
    # TODO MER-5257: Replace this temporary empty body with the initial
    # AI-generated draft body for the current email context.
    ""
  end
end
