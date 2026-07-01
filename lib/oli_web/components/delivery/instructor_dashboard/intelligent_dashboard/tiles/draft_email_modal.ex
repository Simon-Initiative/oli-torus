defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.DraftEmailModal do
  use OliWeb, :live_component

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.InstructorDashboard.Email
  alias Oli.InstructorDashboard.Email.ContextBuilder
  alias Oli.InstructorDashboard.Email.MarkdownToSlate
  alias Oli.InstructorDashboard.Email.SlateSanitizer
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

          <%!-- Controls: Generate + Tone (directly on the modal background, no input-like box) --%>
          <div>
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
                          "border border-Border-border-bold-hover bg-Surface-surface-secondary-hover shadow-[0px_2px_6px_0px_rgba(0,52,99,0.15)]",
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
              aria-required="true"
              placeholder={if @generating, do: "Generating…", else: ""}
              disabled={@generating}
              phx-target={@myself}
              phx-keyup="update_subject"
              phx-blur="update_subject"
              phx-debounce="300"
              class={[
                "h-[40px] w-full rounded-[6px] border border-Border-border-default bg-Specially-Tokens-Fill-fill-input px-4 text-base leading-6 text-Text-text-high focus:outline-none focus:ring-2 focus:ring-Fill-Buttons-fill-primary",
                @generating && "opacity-60"
              ]}
            />
          </div>

          <%!-- Body --%>
          <div class="space-y-1">
            <span
              id={"#{@modal_dom_id}_body_label"}
              class="text-sm font-semibold leading-4 text-Text-text-low-alpha"
            >
              Body:
            </span>
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
                  linkContext: %{mode: "email", pages: @link_pages},
                  onEdit: "initial_function_that_will_be_overwritten",
                  onEditEvent: "update_body_slate",
                  onEditTarget: "##{@modal_dom_id}_wrapper",
                  onEditDebounceMs: 400,
                  editMode: true,
                  value: @body_slate,
                  fixedToolbar: true,
                  allowBlockElements: false,
                  placeholder: "Type your message here…"
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
              {"Fields in curly braces like {first_name} will be personalized automatically."}
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
                aria_disabled={@send_disabled}
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
       # Identity of the current draft generation. A delivered result is applied only if its
       # request id matches; closing/reopening/regenerating mint a new id (or nil), so stale
       # results are dropped deterministically.
       draft_request_id: nil,
       error: nil,
       live_announcement: "",
       email_context: nil,
       project_slug: nil,
       link_pages: [],
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
        # Reopen: invalidate any prior generation so a late result can't land in the fresh modal.
        |> assign(:draft_request_id, nil)
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
          |> clear_validation()
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
     |> clear_validation()
     |> build_email_context()}
  end

  def handle_event("set_tone", _params, socket), do: {:noreply, socket}

  def handle_event("generate_draft", _params, socket) do
    if socket.assigns.generating do
      {:noreply, socket}
    else
      previous_request_id = socket.assigns.draft_request_id
      request_id = System.unique_integer([:positive, :monotonic])

      socket =
        socket
        |> assign(:generating, true)
        |> assign(:draft_request_id, request_id)
        |> assign(:subject, "")
        |> assign(:body_slate, @empty_slate)
        |> assign(:error, nil)
        |> assign(:live_announcement, "Generating email draft…")
        |> assign_send_state()

      send(
        self(),
        {:generate_draft, socket.assigns.id, previous_request_id, request_id,
         socket.assigns.email_context}
      )

      {:noreply, socket}
    end
  end

  def handle_event("update_subject", %{"value" => subject}, socket) do
    {:noreply, socket |> assign(:subject, subject) |> clear_validation() |> assign_send_state()}
  end

  def handle_event("update_body_slate", %{"values" => values}, socket) when is_list(values) do
    # Allowlist the client-supplied Slate at this trust boundary — the editor is text/link-only,
    # but a tampered client can push arbitrary nodes the shared renderer would emit.
    sanitized = SlateSanitizer.sanitize(values)

    {:noreply,
     socket |> assign(:body_slate, sanitized) |> clear_validation() |> assign_send_state()}
  end

  def handle_event("send_email", _params, socket) do
    cond do
      # Transient: a draft is being generated; the button shows that state already.
      socket.assigns.generating ->
        {:noreply, socket}

      send_disabled?(socket.assigns) ->
        message = missing_requirements_message(socket.assigns)

        {:noreply,
         socket
         |> assign(:error, message)
         |> assign(:live_announcement, message)}

      true ->
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
    # Invalidate the current generation immediately (so a result queued before removal/reopen
    # can't match), then cancel the running task for that request id.
    request_id = socket.assigns.draft_request_id

    send(self(), {:cancel_draft, socket.assigns.id, request_id})
    send(self(), {:hide_email_modal, socket.assigns[:email_handler_id]})
    {:noreply, assign(socket, :draft_request_id, nil)}
  end

  @doc """
  Sends an async draft result back to this component via `send_update`, tagged with the
  `request_id` of the generation it belongs to. The component applies it only if that id still
  matches its current generation (see `maybe_apply_draft_result/2`).

  Example:
      DraftEmailModal.deliver_draft_result(component_id, request_id, result)
  """
  def deliver_draft_result(component_id, request_id, result) do
    send_update(__MODULE__, id: component_id, __draft_result__: {request_id, result})
  end

  @doc """
  Shapes selected students into the recipient maps this modal consumes.

  Keeps ALL selected students — including those without an email — so the modal
  can split valid recipients from excluded ones and name the excluded students.
  `name_fn` resolves each student's display name (the source field differs per
  caller, e.g. `:full_name` vs a composed name).
  """
  def recipients(students, selected_ids, name_fn) when is_function(name_fn, 1) do
    selected = MapSet.new(selected_ids)

    students
    |> Enum.filter(&MapSet.member?(selected, &1.id))
    |> Enum.map(fn student ->
      %{
        id: student.id,
        email: Map.get(student, :email),
        given_name: Map.get(student, :given_name),
        family_name: Map.get(student, :family_name),
        display_name: name_fn.(student)
      }
    end)
  end

  defp maybe_apply_draft_result(%{__draft_result__: {request_id, result}}, socket) do
    # Apply only the result of the current generation; drop stale results (from a closed,
    # reopened, regenerated, or already-consumed request). Clear the id on apply so the same
    # result can't be applied twice (single-use).
    if not is_nil(request_id) and request_id == socket.assigns.draft_request_id do
      socket
      |> assign(:draft_request_id, nil)
      |> apply_draft_result(result)
    else
      socket
    end
  end

  defp maybe_apply_draft_result(_assigns, socket), do: socket

  defp apply_draft_result(
         socket,
         {:ok, %{subject_template: subject, body_template: body_markdown}}
       ) do
    socket
    |> assign(:subject, subject)
    |> assign(:body_slate, MarkdownToSlate.to_slate(body_markdown))
    |> assign(:generating, false)
    |> assign(:has_draft, true)
    |> assign(:draft_version, socket.assigns.draft_version + 1)
    |> assign(:error, nil)
    |> assign(
      :live_announcement,
      "Draft generated. Review the subject and body before sending."
    )
    |> assign_send_state()
  end

  defp apply_draft_result(socket, {:error, reason}) do
    error_msg = format_generate_error(reason)

    socket
    |> assign(:generating, false)
    |> assign(:error, error_msg)
    |> assign(:live_announcement, "Draft generation failed: #{error_msg}")
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

  # Drops a stale Send-validation message (visible error + SR announcement) on any edit.
  defp clear_validation(socket) do
    socket
    |> assign(:error, nil)
    |> assign(:live_announcement, "")
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

  defp missing_requirements_message(assigns) do
    missing =
      [
        {assigns.valid_recipient_count == 0, "at least one recipient"},
        {String.trim(assigns.subject) == "", "a subject"},
        {slate_empty?(assigns.body_slate), "a body"}
      ]
      |> Enum.filter(&elem(&1, 0))
      |> Enum.map(&elem(&1, 1))

    case missing do
      [] -> "Please complete the draft before sending."
      items -> "Add #{humanize_list(items)} before sending."
    end
  end

  defp humanize_list([item]), do: item
  defp humanize_list([a, b]), do: "#{a} and #{b}"

  defp humanize_list(items) do
    {last, rest} = List.pop_at(items, -1)
    Enum.join(rest, ", ") <> ", and " <> last
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

  # A body is empty unless some descendant text node holds non-whitespace content. Recurse through
  # wrapper nodes (paragraphs, links, other inlines) so an empty link/inline with blank children
  # does not count as content and wrongly enable Send.
  defp slate_empty?(slate) when is_list(slate), do: Enum.all?(slate, &node_empty?/1)
  defp slate_empty?(_), do: true

  defp node_empty?(%{"text" => text}), do: String.trim(text) == ""

  defp node_empty?(%{"children" => children}) when is_list(children),
    do: Enum.all?(children, &node_empty?/1)

  # Safe only while the email RTE is text/link-only (allowBlockElements: false). If block/void
  # content (e.g. images) becomes linkable here, those leaves carry meaning and this must change.
  defp node_empty?(_), do: true

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

  @doc """
  Section lessons projected into the link-picker DTO consumed by the body editor's
  email-mode link modal. Non-hidden lessons only (delivery enforces gating/availability at
  click time); `removed_from_schedule` pages remain linkable. Saves use `slug` (the page's
  `revision_slug`) as the `/course/link/:slug` target.
  """
  def linkable_pages(section_id) do
    section_id
    |> SectionResourceDepot.get_lessons()
    |> Enum.map(fn sr ->
      %{
        id: sr.resource_id,
        slug: sr.revision_slug,
        title: sr.title,
        numbering_index: sr.numbering_index
      }
    end)
    |> Enum.sort_by(fn p -> {p.numbering_index || 0, p.title || "", p.id} end)
  end

  defp resolve_slugs(socket, nil),
    do: assign(socket, project_slug: nil, section_slug: nil, link_pages: [])

  defp resolve_slugs(socket, section_id) do
    case Sections.get_section_with_base_project(section_id) do
      nil ->
        assign(socket, project_slug: nil, section_slug: nil, link_pages: [])

      section ->
        assign(socket,
          section_slug: section.slug,
          project_slug: section.base_project && section.base_project.slug,
          link_pages: linkable_pages(section_id)
        )
    end
  end
end
