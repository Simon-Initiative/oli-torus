defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.DraftEmailModal do
  use OliWeb, :live_component

  alias Oli.Delivery.Sections
  alias Oli.InstructorDashboard.Email
  alias Oli.InstructorDashboard.Email.ContextBuilder
  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.RecipientChipList
  alias OliWeb.Components.DesignTokens.Primitives.Button
  alias OliWeb.Common.React
  alias OliWeb.Components.Modal
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  @tones [:neutral, :encouraging, :firm]
  @tone_values Enum.map(@tones, &Atom.to_string/1)

  def render(assigns) do
    modal_dom_id = Map.get(assigns, :modal_dom_id, "draft_email_modal")

    assigns =
      assigns
      |> assign(:modal_dom_id, modal_dom_id)

    ~H"""
    <div id={"#{@modal_dom_id}_wrapper"} phx-target={@myself}>
      <Modal.modal
        id={@modal_dom_id}
        class="max-w-[1048px] rounded-[12px] overflow-hidden"
        header_class="flex items-start justify-between bg-Background-bg-primary px-[38px] pt-[31px] pb-[27px]"
        body_class="bg-Background-bg-primary px-[38px] pt-4 pb-0"
        show={@show_modal}
        show_close={false}
        disable_click_away={true}
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
                @modal_dom_id
              )
            }
          />
        </:header_actions>

        <div class="space-y-3">
          <RecipientChipList.recipient_chip_list
            id={"#{@modal_dom_id}_recipients"}
            recipients={@recipient_students}
            excluded={@excluded_recipient_students}
            target={@myself}
          />

          <%!-- Controls: Generate + Tone --%>
          <div class="overflow-clip rounded-[12px] border border-Border-border-subtle bg-Surface-surface-secondary p-[6px] shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]">
            <div class="flex items-center gap-[6px]">
              <Button.button
                variant={:primary}
                size={:sm}
                class="!px-4 shrink-0 whitespace-nowrap"
                disabled={@generating or is_nil(@email_context)}
                phx-click="generate_draft"
                phx-target={@myself}
              >
                <:icon_left>
                  <img
                    :if={!@generating}
                    src={~p"/images/assistant/dot_ai_button.png"}
                    alt=""
                    class="h-5 w-5"
                  />
                  <Icons.ai_spinner :if={@generating} class="h-5 w-5 stroke-current ai-spinning" />
                </:icon_left>
                {if @has_draft, do: "Regenerate Draft", else: "Generate New Draft"}
              </Button.button>

              <div class="flex items-center gap-1" role="group" aria-label="Tone selection">
                <%= for tone <- @tones do %>
                  <button
                    type="button"
                    phx-click="set_tone"
                    phx-target={@myself}
                    phx-value-tone={tone}
                    aria-pressed={to_string(@selected_tone == tone)}
                    class={[
                      "shrink-0 rounded-[6px] px-6 py-2 text-sm font-semibold leading-4 text-Specially-Tokens-Text-text-button-secondary transition-colors",
                      if(@selected_tone == tone,
                        do:
                          "border border-Border-border-bold-hover bg-Fill-Buttons-fill-secondary-hover shadow-[0px_2px_6px_0px_rgba(0,52,99,0.15)]",
                        else:
                          "border border-Border-border-bold bg-transparent shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]"
                      )
                    ]}
                  >
                    {tone |> to_string() |> String.capitalize()}
                  </button>
                <% end %>
              </div>
            </div>
          </div>

          <%!-- Subject --%>
          <div class="space-y-1">
            <label
              for={"#{@modal_dom_id}_subject"}
              class="text-sm font-semibold leading-4 text-Text-text-low-alpha"
            >
              Subject:
            </label>
            <input
              id={"#{@modal_dom_id}_subject"}
              type="text"
              value={@subject}
              placeholder={if @generating, do: "Generating…", else: ""}
              disabled={@generating}
              phx-target={@myself}
              phx-keyup="update_subject"
              phx-blur="update_subject"
              phx-debounce="300"
              class={[
                "h-[40px] w-full rounded-[6px] border border-Border-border-default !bg-transparent px-4 text-base leading-6 text-Text-text-high focus:outline-none focus:ring-2 focus:ring-Fill-Buttons-fill-primary",
                @generating && "opacity-60"
              ]}
            />
          </div>

          <%!-- Body --%>
          <div class="space-y-1">
            <label
              id={"#{@modal_dom_id}_body_label"}
              class="text-sm font-semibold leading-4 text-Text-text-low-alpha"
            >
              Body:
            </label>
            <div
              :if={@generating}
              class="flex h-[255px] w-full items-center justify-center rounded-[6px] border border-Border-border-default bg-transparent"
            >
              <div class="flex items-center gap-2 text-Text-text-low-alpha">
                <Icons.ai_spinner class="h-5 w-5 ai-spinning stroke-current" />
                <span class="text-sm">Generating draft…</span>
              </div>
            </div>
            <div
              :if={not @generating}
              id={"#{@modal_dom_id}_body_editor_v#{@draft_version}"}
              phx-update="ignore"
              role="textbox"
              aria-labelledby={"#{@modal_dom_id}_body_label"}
              aria-multiline="true"
              class="email-link-only-rte min-h-[255px] rounded-[6px] border border-Border-border-default bg-transparent [&_.rich-text-editor]:min-h-[255px]"
            >
              {React.component(
                %{is_liveview: true},
                "Components.RichTextEditor",
                %{
                  projectSlug: @project_slug,
                  onEdit: "initial_function_that_will_be_overwritten",
                  onEditEvent: "update_body_slate",
                  onEditTarget: "##{@modal_dom_id}_wrapper",
                  editMode: true,
                  value: @body_slate,
                  fixedToolbar: true,
                  allowBlockElements: false
                },
                id: "#{@modal_dom_id}_body_rte"
              )}
            </div>
          </div>

          <%!-- Error banner --%>
          <div
            :if={@error}
            class="rounded-[6px] border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700 dark:border-red-700 dark:bg-red-900/20 dark:text-red-300"
            role="alert"
          >
            {@error}
          </div>
        </div>

        <:custom_footer>
          <div class="relative z-10 flex items-center justify-between border-t border-Border-border-subtle bg-Background-bg-primary px-[38px] py-5">
            <p class="text-sm leading-4 text-Text-text-low-alpha">
              {"Fields contained in square brackets like {first_name} will be personalized automatically."}
            </p>
            <div class="flex items-center gap-3">
              <Button.button
                variant={:secondary}
                size={:sm}
                phx-click={
                  Modal.hide_modal(
                    JS.push("close_email_modal", target: @myself),
                    @modal_dom_id
                  )
                }
              >
                Cancel
              </Button.button>
              <Button.button
                variant={:primary}
                size={:sm}
                id={"#{@modal_dom_id}_send_button"}
                disabled={@send_disabled}
                phx-click="send_email"
                phx-target={@myself}
              >
                Send
                <:icon_right>
                  <Icons.send class="h-5 w-5 stroke-current" />
                </:icon_right>
              </Button.button>
            </div>
          </div>
        </:custom_footer>
      </Modal.modal>

      <div
        :if={@closing}
        id={"#{@modal_dom_id}_cleanup"}
        phx-hook="OnMountAndUpdate"
        data-event={Modal.hide_modal(@modal_dom_id)}
      />

      <div aria-live="polite" aria-atomic="true" class="sr-only">
        {@live_announcement}
      </div>
    </div>
    """
  end

  @empty_slate [%{"type" => "p", "children" => [%{"text" => ""}]}]

  def mount(socket) do
    {:ok,
     assign(socket,
       show_modal: false,
       subject: "",
       body_slate: @empty_slate,
       recipient_students: [],
       excluded_recipient_students: [],
       valid_recipient_count: 0,
       send_disabled: true,
       selected_tone: :neutral,
       tones: @tones,
       generating: false,
       has_draft: false,
       draft_version: 0,
       error: nil,
       live_announcement: "",
       email_context: nil,
       project_slug: nil,
       closing: false
     )}
  end

  def update(%{__draft_result__: _} = assigns, socket) do
    {:ok, maybe_apply_draft_result(assigns, socket)}
  end

  def update(assigns, socket) do
    show_modal = Map.get(assigns, :show_modal, socket.assigns[:show_modal] || false)
    was_open? = socket.assigns[:show_modal] || false

    socket =
      socket
      |> assign(assigns)
      |> assign(:show_modal, show_modal)

    if show_modal and not was_open? do
      students = Map.get(assigns, :students, [])
      recipient_students = normalize_recipient_students(students)

      socket =
        socket
        |> assign_recipient_students(recipient_students)
        |> assign(:excluded_recipient_students, excluded_recipient_students(students))
        |> assign(:subject, "")
        |> assign(:body_slate, @empty_slate)
        |> assign(:selected_tone, :neutral)
        |> assign(:generating, false)
        |> assign(:has_draft, false)
        |> assign(:draft_version, 0)
        |> assign(:error, nil)
        |> assign(:live_announcement, "")
        |> resolve_slugs(assigns[:section_id])
        |> assign_send_state()
        |> build_email_context()

      {:ok, socket}
    else
      {:ok, assign_send_state(socket)}
    end
  end

  # -- Events --

  def handle_event("remove_recipient", %{"student_id" => student_id}, socket) do
    case Integer.parse(student_id) do
      {parsed_id, ""} ->
        socket =
          socket
          |> update_recipient_students(&Enum.reject(&1, fn s -> s.id == parsed_id end))
          |> refresh_email_context()
          |> assign_send_state()

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("set_tone", %{"tone" => tone}, socket) when tone in @tone_values do
    {:noreply,
     socket
     |> assign(:selected_tone, String.to_existing_atom(tone))
     |> build_email_context()}
  end

  def handle_event("set_tone", _params, socket), do: {:noreply, socket}

  def handle_event("generate_draft", _params, socket) do
    if socket.assigns.generating do
      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:generating, true)
        |> assign(:subject, "")
        |> assign(:body_slate, @empty_slate)
        |> assign(:error, nil)
        |> assign(:live_announcement, "Generating email draft…")

      send(self(), {:generate_draft, socket.assigns.id, socket.assigns.email_context})
      {:noreply, socket}
    end
  end

  def handle_event("update_subject", %{"value" => subject}, socket) do
    {:noreply, socket |> assign(:subject, subject) |> assign_send_state()}
  end

  def handle_event("update_body_slate", %{"values" => values}, socket) when is_list(values) do
    {:noreply, socket |> assign(:body_slate, values) |> assign_send_state()}
  end

  def handle_event("send_email", _params, socket) do
    if send_disabled?(socket.assigns) do
      {:noreply, socket}
    else
      draft = %{
        subject: String.trim(socket.assigns.subject),
        body_slate: socket.assigns.body_slate
      }

      case Email.send_emails(draft, socket.assigns.email_context) do
        {:ok, %{enqueued: count}} ->
          send(self(), {:flash_message, {:info, "Email sent to #{count} student(s)"}})
          send(self(), {:hide_email_modal, socket.assigns[:email_handler_id]})

          # Tear down the modal client-side (release body scroll lock, backdrop, focus
          # trap) before the parent removes this component. phx-remove does not fire on
          # wholesale LiveComponent removal, so the Cancel/X teardown is replayed here.
          {:noreply,
           socket
           |> assign(:closing, true)
           |> assign(:live_announcement, "Email sent successfully")}

        {:error, reasons} ->
          error_msg = format_send_errors(reasons)

          {:noreply,
           socket
           |> assign(:error, error_msg)
           |> assign(:live_announcement, "Email sending failed: #{error_msg}")}
      end
    end
  end

  def handle_event("close_email_modal", _params, socket) do
    send(self(), {:hide_email_modal, socket.assigns[:email_handler_id]})
    {:noreply, socket}
  end

  @doc """
  Sends an async draft result back to this component via `send_update`.
  Call from the parent's `handle_info({:generate_draft, id}, socket)`.

  Example:
      DraftEmailModal.deliver_draft_result(component_id, result)
  """
  def deliver_draft_result(component_id, result) do
    send_update(__MODULE__, id: component_id, __draft_result__: result)
  end

  defp maybe_apply_draft_result(assigns, socket) do
    case Map.get(assigns, :__draft_result__) do
      {:ok, %{subject_template: subject, body_template: body_markdown}} ->
        socket
        |> assign(:subject, subject)
        |> assign(:body_slate, markdown_to_slate(body_markdown))
        |> assign(:generating, false)
        |> assign(:has_draft, true)
        |> assign(:draft_version, socket.assigns.draft_version + 1)
        |> assign(:error, nil)
        |> assign(
          :live_announcement,
          "Draft generated. Review the subject and body before sending."
        )
        |> assign_send_state()

      {:error, reason} ->
        error_msg = format_generate_error(reason)

        socket
        |> assign(:generating, false)
        |> assign(:error, error_msg)
        |> assign(:live_announcement, "Draft generation failed: #{error_msg}")

      nil ->
        socket
    end
  end

  # -- Private helpers --

  # Rebuild the context so removed recipients are excluded at send time; clear it
  # (without surfacing the context-build error) when no recipients remain.
  defp refresh_email_context(socket) do
    if socket.assigns.recipient_students == [],
      do: assign(socket, :email_context, nil),
      else: build_email_context(socket)
  end

  defp build_email_context(socket) do
    assigns = socket.assigns

    recipients =
      Enum.map(assigns.recipient_students, fn s ->
        %{
          student_id: s.id,
          email: s.email,
          given_name: Map.get(s, :given_name),
          family_name: Map.get(s, :family_name)
        }
      end)

    input = %{
      section_id: assigns[:section_id],
      section_slug: assigns[:section_slug],
      course_title: assigns[:section_title] || assigns[:course_title] || "",
      instructor_name: assigns[:instructor_name] || "Instructor",
      instructor_email: assigns[:instructor_email],
      scope_label: assigns[:scope_label] || "",
      situation_key: assigns[:situation_key],
      recipients: recipients,
      tone: assigns.selected_tone
    }

    input =
      input
      |> maybe_put(:assessment, assigns[:assessment])
      |> maybe_put(:objective, assigns[:objective])
      |> maybe_put(:content_item, assigns[:content_item])
      |> maybe_put(:support_bucket, assigns[:support_bucket])

    case ContextBuilder.build(input) do
      {:ok, context} ->
        assign(socket, :email_context, context)

      {:error, _reason} ->
        socket
        |> assign(:email_context, nil)
        |> assign(:error, "Unable to prepare email context. You can still compose manually.")
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp normalize_recipient_students(students) do
    students
    |> Enum.filter(&(is_binary(&1.email) and String.trim(&1.email) != ""))
    |> Enum.uniq_by(& &1.id)
  end

  defp excluded_recipient_students(students) do
    Enum.reject(students, &(is_binary(&1.email) and String.trim(&1.email) != ""))
  end

  defp send_disabled?(assigns) do
    assigns.valid_recipient_count == 0 or
      String.trim(assigns.subject) == "" or
      slate_empty?(assigns.body_slate) or
      assigns.generating or
      assigns.email_context == nil
  end

  defp assign_send_state(socket) do
    assign(socket, :send_disabled, send_disabled?(socket.assigns))
  end

  defp assign_recipient_students(socket, recipient_students) do
    socket
    |> assign(:recipient_students, recipient_students)
    |> assign(:valid_recipient_count, length(recipient_students))
  end

  defp update_recipient_students(socket, updater) do
    recipient_students = updater.(socket.assigns.recipient_students)
    assign_recipient_students(socket, recipient_students)
  end

  defp markdown_to_slate(markdown) when is_binary(markdown) do
    paragraphs =
      markdown
      |> String.split(~r/\n{2,}/)
      |> Enum.map(fn para ->
        %{"type" => "p", "children" => [%{"text" => String.trim(para)}]}
      end)
      |> Enum.reject(fn %{"children" => [%{"text" => t}]} -> t == "" end)

    case paragraphs do
      [] -> @empty_slate
      nodes -> nodes
    end
  end

  defp markdown_to_slate(_), do: @empty_slate

  defp slate_empty?(slate) when is_list(slate) do
    Enum.all?(slate, fn
      %{"children" => children} ->
        Enum.all?(children, fn
          %{"text" => t} -> String.trim(t) == ""
          _ -> false
        end)

      _ ->
        true
    end)
  end

  defp slate_empty?(_), do: true

  defp format_send_errors(reasons) when is_list(reasons) do
    reasons
    |> Enum.map(&format_single_reason/1)
    |> Enum.join(". ")
  end

  defp format_send_errors(_), do: "An unexpected error occurred while sending."

  defp format_single_reason(:empty_subject), do: "Subject cannot be empty"
  defp format_single_reason(:empty_body), do: "Body cannot be empty"
  defp format_single_reason(:no_recipients), do: "No recipients available"
  defp format_single_reason({:invalid_email, _}), do: "One or more recipient emails are invalid"

  defp format_single_reason({:invalid_instructor_email, _}),
    do: "Your reply-to email address is invalid."

  defp format_single_reason({:duplicate_recipients, _}),
    do: "Some recipients appear more than once."

  defp format_single_reason({:unresolvable_placeholder, token, _}),
    do: "Could not personalize #{token} for one or more recipients."

  defp format_single_reason({:realize_failed, _email, token}),
    do: "Could not fill in #{token} for one or more recipients."

  defp format_single_reason({:unsafe_link, url}),
    do: "A link in the message isn't allowed: #{url}"

  defp format_single_reason(_), do: "Validation failed"

  defp format_generate_error(:missing_feature_config),
    do: "AI email generation is not configured for this course."

  defp format_generate_error(:timeout), do: "Draft generation timed out. Please try again."

  defp format_generate_error(:provider_error),
    do: "AI service is temporarily unavailable. Please try again."

  defp format_generate_error(:parse_failure), do: "Failed to parse AI response. Please try again."
  defp format_generate_error(_), do: "Draft generation failed. Please try again."

  defp resolve_slugs(socket, nil), do: assign(socket, project_slug: nil, section_slug: nil)

  defp resolve_slugs(socket, section_id) do
    case Sections.get_section_with_base_project(section_id) do
      nil ->
        assign(socket, project_slug: nil, section_slug: nil)

      section ->
        assign(socket,
          section_slug: section.slug,
          project_slug: section.base_project && section.base_project.slug
        )
    end
  end
end
