defmodule OliWeb.Delivery.Student.PrologueLive do
  use OliWeb, :live_view

  import OliWeb.Delivery.Student.Utils,
    only: [page_header: 1, is_adaptive_page: 1]

  alias Oli.Accounts.User
  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Components.DesignTokens.Primitives.Button
  alias OliWeb.Components.Modal
  alias OliWeb.Delivery.Student.Utils, as: StudentUtils
  alias OliWeb.Icons

  require Logger

  on_mount {OliWeb.LiveSessionPlugs.InitPage, :previous_next_index}

  # this is an optimization to reduce the memory footprint of the liveview process
  @required_keys_per_assign %{
    section:
      {[
         :id,
         :slug,
         :title,
         :brand,
         :lti_1p3_deployment,
         :resource_gating_index,
         :customizations,
         :open_and_free,
         :display_curriculum_item_numbering,
         :unnumbered_unit_ids,
         :root_section_resource_id
       ], %Sections.Section{}},
    current_user: {[:id, :name, :email, :sub], %User{}}
  }

  def mount(params, _session, socket) do
    %{page_context: page_context} = socket.assigns

    if connected?(socket) do
      send(self(), :gc)
    end

    {:ok,
     socket
     |> assign_objectives()
     |> assign(
       request_path: params["request_path"],
       selected_view: params["selected_view"],
       password: page_context.effective_settings.password,
       page_revision: page_context.page,
       effective_settings: page_context.effective_settings,
       view: :prologue,
       scripts_loaded: true
     )
     |> slim_assigns(), temporary_assigns: [page_context: %{}]}
  end

  def handle_info(:gc, socket) do
    :erlang.garbage_collect(socket.transport_pid)
    :erlang.garbage_collect(self())
    {:noreply, socket}
  end

  def handle_event("begin_attempt", params, socket) do
    %{
      current_user: user,
      section: section,
      page_revision: page_revision,
      effective_settings: effective_settings,
      ctx: ctx
    } = socket.assigns

    case Oli.Delivery.Attempts.StartAttemptPolicy.validate(effective_settings,
           password: Map.get(params, "password")
         ) do
      :ok ->
        do_start_attempt(socket, section, user, page_revision, effective_settings)

      {:error, :password_required} ->
        {:noreply, put_flash(socket, :error, "Empty password")}

      {:error, :incorrect_password} ->
        {:noreply, put_flash(socket, :error, "Incorrect password")}

      {:error, :before_start_date} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This assessment is not yet available. It will be available on #{date(effective_settings.start_date, ctx: ctx, precision: :minutes)}."
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <.password_attempt_modal />

    <div class="flex flex-col w-full items-center gap-15 flex-1 overflow-auto">
      <div class="flex-1 w-full max-w-[1040px] p-4 sm:px-[80px] sm:pt-20 pb-10 flex-col justify-start items-center inline-flex">
        <.page_header
          page_context={@page_context}
          ctx={@ctx}
          objectives={@objectives}
          index={@current_page["index"]}
          container_label={
            StudentUtils.get_container_label(
              @current_page["id"],
              @section,
              @section.display_curriculum_item_numbering
            )
          }
          display_curriculum_item_numbering={@section.display_curriculum_item_numbering}
          show_assignment_marker={false}
          show_schedule_dates={false}
        />

        <StudentUtils.blocking_gates_warning
          :if={@show_blocking_gates?}
          attempt_message={@attempt_message}
        />
        <.assignment_terms
          :if={!@show_blocking_gates?}
          assignment_terms={@assignment_terms}
          page_context={@page_context}
          ctx={@ctx}
          is_adaptive={is_adaptive_page(@page_context.page)}
          allow_attempt?={@allow_attempt?}
          section_slug={@section.slug}
          request_path={@request_path}
        />
      </div>
    </div>
    """
  end

  defp password_attempt_modal(assigns) do
    ~H"""
    <Modal.modal id="password_attempt_modal" class="w-1/2">
      <:title>Provide Assessment Password</:title>
      <.form
        phx-submit={JS.push("begin_attempt") |> Modal.hide_modal("password_attempt_modal")}
        for={%{}}
        class="flex flex-col gap-6"
        id="password_attempt_form"
      >
        <input id="password_attempt_input" type="password" name="password" field={:password} value="" />
        <.button type="submit" class="mx-auto btn btn-primary">Begin</.button>
      </.form>
    </Modal.modal>
    """
  end

  attr :assignment_terms, :map, required: true
  attr :page_context, Oli.Delivery.Page.PageContext
  attr :ctx, OliWeb.Common.SessionContext
  attr :is_adaptive, :boolean, required: true
  attr :allow_attempt?, :boolean
  attr :section_slug, :string
  attr :request_path, :string

  defp assignment_terms(assigns) do
    ~H"""
    <section
      id="assignment_terms"
      aria-labelledby="assignment_terms_heading"
      class="w-full rounded-2xl bg-Surface-surface-primary p-4 sm:p-6 flex flex-col gap-[13px]"
    >
      <h2 id="assignment_terms_heading" class="text-Text-text-high text-2xl font-bold leading-8">
        Assignment Terms
      </h2>

      <div class="w-full flex flex-col lg:flex-row lg:justify-center gap-[17px] items-stretch">
        <div class="w-full min-w-0 lg:basis-[460px] lg:shrink-0 flex flex-col gap-1.5">
          <.schedule_terms_card
            :if={@assignment_terms.schedule}
            schedule={@assignment_terms.schedule}
            ctx={@ctx}
          />
          <.time_limit_terms_card
            :if={@assignment_terms.time_limit}
            time_limit={@assignment_terms.time_limit}
          />
          <.scoring_terms_card :if={@assignment_terms.scoring} scoring={@assignment_terms.scoring} />
        </div>

        <.attempts_terms_card
          attempts={@assignment_terms.attempts}
          page_context={@page_context}
          ctx={@ctx}
          is_adaptive={@is_adaptive}
          allow_attempt?={@allow_attempt?}
          section_slug={@section_slug}
          request_path={@request_path}
        />
      </div>
    </section>
    """
  end

  attr :schedule, :map, required: true
  attr :ctx, OliWeb.Common.SessionContext

  defp schedule_terms_card(assigns) do
    ~H"""
    <.terms_card id="page_due_terms" title="Schedule">
      <:icon>
        <Icons.schedule />
      </:icon>
      <div class="flex min-w-0 flex-col gap-1 text-sm leading-5 text-Text-text-low">
        <p :if={@schedule.available} class="min-w-0 break-words">
          <strong class="font-bold text-Text-text-high">Available:</strong> {format_schedule_datetime(
            @schedule.available,
            @ctx
          )}
        </p>
        <p :if={@schedule.due} class="min-w-0 break-words">
          <strong class="font-bold text-Text-text-high">Due:</strong> {format_schedule_datetime(
            @schedule.due,
            @ctx
          )}
        </p>
      </div>

      <.late_submission_card
        :if={@schedule.late_submission}
        late_submission={@schedule.late_submission}
      />
    </.terms_card>
    """
  end

  attr :time_limit, :map, required: true

  defp time_limit_terms_card(assigns) do
    ~H"""
    <.terms_card id="page_time_limit_term" title="Time Limit">
      <:icon>
        <Icons.clock />
      </:icon>
      <p class="min-w-0 text-sm leading-5 text-Text-text-low">
        <.segments segments={@time_limit.segments} />
      </p>
    </.terms_card>
    """
  end

  attr :scoring, :map, required: true

  defp scoring_terms_card(assigns) do
    ~H"""
    <.terms_card id="page_scoring_terms" title="Scoring">
      <:icon>
        <Icons.star color="text-Icon-icon-default" />
      </:icon>
      <p class="min-w-0 text-sm leading-5 text-Text-text-low">
        <.segments segments={@scoring.segments} />
      </p>
    </.terms_card>
    """
  end

  attr :late_submission, :map, required: true

  defp late_submission_card(assigns) do
    warning? = assigns.late_submission.state == :warning
    assigns = assign(assigns, warning?: warning?)

    ~H"""
    <div
      id="page_submit_term"
      role="group"
      aria-labelledby="page_submit_term_heading"
      class={[
        "mt-2 rounded-xl border bg-Surface-surface-secondary p-3 flex flex-col gap-2",
        if(@warning?,
          do: "border-Fill-Accent-fill-accent-orange-bold",
          else: "border-Border-border-subtle"
        )
      ]}
    >
      <div class="flex items-center gap-2">
        <span aria-hidden="true" class="shrink-0">
          <Icons.warning_triangle
            :if={@warning?}
            class="w-4 h-4 stroke-Icon-icon-accent-orange"
          />
          <Icons.info :if={!@warning?} class="w-4 h-4 text-Icon-icon-default" />
        </span>
        <h4 id="page_submit_term_heading" class="text-sm font-bold leading-5 text-Text-text-high">
          {@late_submission.title}
        </h4>
      </div>
      <p class="text-sm leading-5 text-Text-text-low">
        <.segments segments={@late_submission.segments} />
      </p>
    </div>
    """
  end

  attr :attempts, :map, required: true
  attr :page_context, Oli.Delivery.Page.PageContext
  attr :ctx, OliWeb.Common.SessionContext
  attr :is_adaptive, :boolean, required: true
  attr :allow_attempt?, :boolean
  attr :section_slug, :string
  attr :request_path, :string

  defp attempts_terms_card(assigns) do
    begin_attempt_click =
      if assigns.allow_attempt? do
        if assigns.page_context.effective_settings.password not in [nil, ""] do
          Modal.show_modal("password_attempt_modal") |> JS.focus(to: "#password_attempt_input")
        else
          "begin_attempt"
        end
      end

    assigns = assign(assigns, begin_attempt_click: begin_attempt_click)

    ~H"""
    <aside
      id="attempts_summary"
      aria-labelledby="attempts_summary_heading"
      class="w-full min-w-0 lg:basis-[355px] lg:shrink-0 rounded-xl border border-Border-border-subtle bg-Surface-surface-secondary p-4 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)] flex flex-col gap-4"
    >
      <div class="flex min-w-0 flex-col gap-2">
        <div class="flex items-center gap-2">
          <div
            aria-hidden="true"
            class="h-8 w-8 shrink-0 rounded-full bg-Surface-surface-secondary-muted flex items-center justify-center text-Icon-icon-default"
          >
            <Icons.flag />
          </div>
          <h3
            id="attempts_summary_heading"
            class="min-w-0 text-Text-text-high text-lg font-semibold leading-6"
          >
            {@attempts.title}
          </h3>
        </div>
        <div class="text-Text-text-high text-[40px] leading-[44px] font-bold">
          {@attempts.value}
        </div>
        <p :if={@attempts.description} class="min-w-0 text-Text-text-low text-sm leading-5">
          {@attempts.description}
        </p>
      </div>

      <Button.button
        id="begin_attempt_button"
        variant={:primary}
        size={:md}
        disabled={!@allow_attempt?}
        class="w-full justify-center"
        phx-click={@begin_attempt_click}
      >
        {@attempts.cta_label}
      </Button.button>

      <div
        :if={@attempts.past_attempts != []}
        class="border-t border-Border-border-subtle pt-3 flex flex-col gap-1"
      >
        <.attempt_summary
          :for={attempt <- @attempts.past_attempts}
          index={attempt.number}
          section_slug={@section_slug}
          page_revision_slug={@page_context.page.slug}
          attempt={attempt}
          is_adaptive={@is_adaptive}
          ctx={@ctx}
          allow_review_submission?={@page_context.effective_settings.review_submission == :allow}
          request_path={@request_path}
        />
      </div>
    </aside>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  slot :icon, required: true
  slot :inner_block, required: true

  defp terms_card(assigns) do
    assigns = assign(assigns, heading_id: "#{assigns.id}_heading")

    ~H"""
    <section
      id={@id}
      aria-labelledby={@heading_id}
      class="w-full rounded-xl border border-Border-border-subtle bg-Surface-surface-secondary p-3 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)] flex flex-col gap-2"
    >
      <div class="flex min-w-0 items-center gap-2">
        <div
          aria-hidden="true"
          class="h-8 w-8 shrink-0 rounded-full bg-Surface-surface-secondary-muted flex items-center justify-center text-Icon-icon-default"
        >
          {render_slot(@icon)}
        </div>
        <h3 id={@heading_id} class="min-w-0 text-Text-text-high text-lg font-semibold leading-6">
          {@title}
        </h3>
      </div>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :segments, :list, required: true

  defp segments(assigns) do
    ~H"""
    <%= for {kind, value} <- @segments do %>
      <%= case kind do %>
        <% :strong -> %>
          <strong class="font-bold text-Text-text-high">{value}</strong>
        <% _ -> %>
          {value}
      <% end %>
    <% end %>
    """
  end

  defp format_schedule_datetime(:now, _ctx), do: "Now"

  defp format_schedule_datetime(datetime, ctx) do
    FormatDateTime.to_formatted_datetime(
      datetime,
      ctx,
      "{WDfull}, {Mfull} {D}, {YYYY} at {h12}:{m}{am} {Z}"
    )
  end

  defp format_submitted_at(nil, _ctx), do: nil

  defp format_submitted_at(datetime, ctx) do
    FormatDateTime.to_formatted_datetime(datetime, ctx, "{WDshort} {Mshort} {D}, {YYYY}")
  end

  attr :index, :integer
  attr :attempt, :map
  attr :ctx, OliWeb.Common.SessionContext
  attr :is_adaptive, :boolean, required: true
  attr :allow_review_submission?, :boolean
  attr :section_slug, :string
  attr :page_revision_slug, :string
  attr :request_path, :string

  defp attempt_summary(assigns) do
    feedback_texts = Map.get(assigns.attempt, :feedback_texts, []) || []
    assigns = assign(assigns, feedback_texts: feedback_texts)

    ~H"""
    <div
      id={"attempt_#{@index}_summary"}
      class="w-full py-2 flex flex-col gap-1"
    >
      <div class="w-full flex flex-col sm:flex-row sm:items-start sm:justify-between gap-2">
        <div class="flex flex-col gap-1">
          <div class="text-Text-text-low text-xs font-bold uppercase leading-normal tracking-wide">
            Attempt {@index}:
          </div>

          <div
            :if={@attempt.lifecycle_state == :submitted}
            class="text-Fill-Accent-fill-accent-green-bold text-xs font-semibold tracking-tight"
          >
            <span class="sr-only">Attempt status: </span> Submitted
          </div>

          <div
            :if={scored_attempt?(@attempt)}
            class="flex items-center gap-1.5 text-Fill-Accent-fill-accent-green-bold"
          >
            <span aria-hidden="true">
              <Icons.star />
            </span>
            <div class="flex items-center gap-1 text-xs font-semibold tracking-tight">
              <span>
                <span class="sr-only">Attempt score: </span>
                {format_attempt_score(@attempt.score)}
              </span>
              <span>
                /
              </span>
              <span>
                <span class="sr-only">Attempt out of: </span>
                {format_attempt_score(@attempt.out_of)}
              </span>
            </div>
          </div>
        </div>

        <div class="flex flex-col sm:items-end gap-1">
          <div class="flex items-start gap-1">
            <div class="text-Text-text-low text-xs font-normal opacity-75">
              Submitted:
            </div>
            <div class="text-Text-text-high text-xs font-normal">
              <span class="sr-only">Attempt submission: </span>
              {format_submitted_at(@attempt.submitted_at, @ctx)}
            </div>
          </div>
          <div
            :if={@allow_review_submission?}
            class="flex justify-end items-center"
          >
            <.link
              href={
                StudentUtils.review_live_path(
                  @section_slug,
                  @page_revision_slug,
                  @attempt.attempt_guid,
                  request_path:
                    StudentUtils.prologue_live_path(@section_slug, @page_revision_slug,
                      request_path: @request_path
                    )
                )
              }
              aria-label={"Review attempt #{@index}"}
              class="inline-flex min-h-10 items-center px-3 py-2 rounded hover:opacity-70 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
            >
              <span class="text-Text-text-link text-xs font-semibold uppercase tracking-wide">
                Review
              </span>
            </.link>
          </div>
        </div>
      </div>
    </div>
    <div :if={@is_adaptive && @feedback_texts != []} class="mt-2">
      <div class="text-neutral-500 text-sm font-bold mb-2">Instructor Feedback:</div>
      <div class="flex flex-col gap-y-2">
        <%= for feedback <- @feedback_texts do %>
          <p class="w-full text-black font-normal dark:text-neutral-500" readonly>
            {feedback}
          </p>
        <% end %>
      </div>
    </div>
    """
  end

  defp scored_attempt?(%{lifecycle_state: :evaluated, score: score, out_of: out_of})
       when is_number(score) and is_number(out_of),
       do: true

  defp scored_attempt?(_), do: false

  defp format_attempt_score(score) when is_number(score), do: Float.round(score / 1, 2)

  def do_start_attempt(socket, section, user, revision, effective_settings) do
    datashop_session_id = socket.assigns.datashop_session_id
    activity_provider = &Oli.Delivery.ActivityProvider.provide/6

    # We must check gating conditions here to account for gates that activated after
    # the prologue page was rendered, and for malicious/deliberate attempts to start an attempt via
    # hitting this endpoint.
    with :ok <- check_gating_conditions(section, user, revision.resource_id),
         {:ok, _attempt_state} <-
           PageLifecycle.start(
             revision.slug,
             section.slug,
             datashop_session_id,
             user,
             effective_settings,
             activity_provider
           ) do
      {:noreply,
       redirect(socket,
         to:
           StudentUtils.lesson_live_path(section.slug, revision.slug,
             request_path: socket.assigns.request_path,
             selected_view: socket.assigns.selected_view
           )
       )}
    else
      {:redirect, to} ->
        {:noreply, redirect(socket, to: to)}

      {:error, {:gates, _}} ->
        # In the case where a gate exists we want to redirect to this page display, which will
        # then pick up the gate and show that feedback to the user
        {:noreply,
         redirect(socket,
           to: Routes.page_delivery_path(socket, :page, section.slug, revision.slug)
         )}

      {:error, {:end_date_passed}} ->
        {:noreply, put_flash(socket, :error, "This assessment's end date passed.")}

      {:error, {:active_attempt_present}} ->
        {:noreply, put_flash(socket, :error, "You already have an active attempt.")}

      {:error, {:no_more_attempts}} ->
        {:noreply, put_flash(socket, :error, "You have no attempts remaining.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to start new attempt")}
    end
  end

  defp assign_objectives(socket) do
    %{page_context: %{page: page}, current_user: current_user, section: section} =
      socket.assigns

    page_attached_objectives =
      Resolver.objectives_by_resource_ids(page.objectives["attached"], section.slug)

    student_proficiency_per_page_level_learning_objective =
      Metrics.proficiency_for_student_per_learning_objective(
        page_attached_objectives,
        current_user.id,
        section
      )

    objectives =
      page_attached_objectives
      |> Enum.map(fn rev ->
        %{
          resource_id: rev.resource_id,
          title: rev.title,
          proficiency:
            Map.get(
              student_proficiency_per_page_level_learning_objective,
              rev.resource_id,
              "Not enough data"
            )
        }
      end)

    assign(socket,
      objectives: objectives
    )
  end

  defp check_gating_conditions(section, user, resource_id) do
    case Oli.Delivery.Gating.blocked_by(section, user, resource_id) do
      [] -> :ok
      gates -> {:error, {:gates, gates}}
    end
  end

  defp slim_assigns(socket) do
    Enum.reduce(@required_keys_per_assign, socket, fn {assign_name, {required_keys, struct}},
                                                      socket ->
      assign(
        socket,
        assign_name,
        Map.merge(
          struct,
          Map.filter(socket.assigns[assign_name], fn {k, _v} -> k in required_keys end)
        )
      )
    end)
  end
end
