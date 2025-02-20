defmodule OliWeb.Delivery.Student.PrologueLive do
  use OliWeb, :live_view

  import OliWeb.Delivery.Student.Utils,
    only: [page_header: 1, page_terms: 1, is_adaptive_page: 1]

  alias Oli.Accounts.User
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Attempts.{Core, PageLifecycle}
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Settings
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias OliWeb.Common.{FormatDateTime, Utils}
  alias OliWeb.Components.Modal
  alias OliWeb.Delivery.Student.Utils, as: StudentUtils
  alias OliWeb.Icons

  require Logger

  on_mount {OliWeb.LiveSessionPlugs.InitPage, :previous_next_index}

  # this is an optimization to reduce the memory footprint of the liveview process
  @required_keys_per_assign %{
    section:
      {[:id, :slug, :title, :brand, :lti_1p3_deployment, :resource_gating_index, :customizations],
       %Sections.Section{}},
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

  def handle_event("begin_attempt", %{"password" => password}, socket)
      when password != socket.assigns.password do
    {:noreply, put_flash(socket, :error, "Incorrect password")}
  end

  def handle_event("begin_attempt", _params, socket) do
    %{
      current_user: user,
      section: section,
      page_revision: page_revision,
      effective_settings: effective_settings,
      ctx: ctx
    } = socket.assigns

    case Settings.check_start_date(effective_settings) do
      {:allowed} ->
        do_start_attempt(socket, section, user, page_revision, effective_settings)

      {:before_start_date} ->
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

    <div class="flex pb-20 flex-col w-full items-center gap-15 flex-1 overflow-auto">
      <div class="flex-1 w-full max-w-[1040px] px-[80px] pt-20 pb-10 flex-col justify-start items-center inline-flex">
        <.page_header
          page_context={@page_context}
          ctx={@ctx}
          objectives={@objectives}
          index={@current_page["index"]}
          container_label={StudentUtils.get_container_label(@current_page["id"], @section)}
        />
        <div class="self-stretch h-[0px] opacity-80 dark:opacity-20 bg-white border border-gray-200 mt-3 mb-10">
        </div>
        <.page_terms
          effective_settings={@page_context.effective_settings}
          ctx={@ctx}
          is_adaptive={is_adaptive_page(@page_context.page)}
        />
        <.attempts_summary
          page_context={@page_context}
          attempt_message={@attempt_message}
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

  attr :attempt_message, :string
  attr :page_context, Oli.Delivery.Page.PageContext
  attr :ctx, OliWeb.Common.SessionContext
  attr :is_adaptive, :boolean, required: true
  attr :allow_attempt?, :boolean
  attr :section_slug, :string
  attr :request_path, :string

  defp attempts_summary(assigns) do
    ~H"""
    <div class="w-full flex-col justify-start items-start gap-3 flex" id="attempts_summary">
      <div class="self-stretch justify-start items-start gap-6 inline-flex relative">
        <div
          id="attempts_summary_with_tooltip"
          phx-hook="TooltipWithTarget"
          data-tooltip-target-id="attempt_tooltip"
          class="opacity-80 cursor-help dark:text-white text-sm font-bold font-['Open Sans'] uppercase tracking-wider"
        >
          Attempts <%= get_attempts_count(@page_context) %>/<%= get_max_attempts(@page_context) %>
        </div>
        <div
          id="attempt_tooltip"
          class="absolute hidden left-32 -top-2 text-xs bg-white py-2 px-4 text-black rounded-lg shadow-lg"
        >
          <%= @attempt_message %>
        </div>
      </div>
      <div class="self-stretch flex-col justify-start items-start flex">
        <.attempt_summary
          :for={
            {attempt, index} <-
              Enum.filter(@page_context.historical_attempts, fn a -> a.revision.graded == true end)
              |> Enum.with_index(1)
          }
          index={index}
          section_slug={@section_slug}
          page_revision_slug={@page_context.page.slug}
          attempt={attempt}
          is_adaptive={@is_adaptive}
          ctx={@ctx}
          allow_review_submission?={@page_context.effective_settings.review_submission == :allow}
          request_path={@request_path}
        />
      </div>
    </div>
    <button
      id="begin_attempt_button"
      disabled={!@allow_attempt?}
      phx-click={
        if(@page_context.effective_settings.password not in [nil, ""],
          do: Modal.show_modal("password_attempt_modal") |> JS.focus(to: "#password_attempt_input"),
          else: "begin_attempt"
        )
      }
      class={[
        "mb-24 cursor-pointer px-5 py-2.5 hover:bg-opacity-40 bg-blue-600 rounded-[3px] shadow justify-center items-center gap-2.5 inline-flex text-white text-sm font-normal font-['Open Sans'] leading-tight",
        if(!@allow_attempt?, do: "opacity-50 dark:opacity-20 disabled !cursor-not-allowed")
      ]}
    >
      Begin <%= get_ordinal_attempt(@page_context) %> Attempt
    </button>
    """
  end

  attr :index, :integer
  attr :attempt, ResourceAttempt
  attr :ctx, OliWeb.Common.SessionContext
  attr :is_adaptive, :boolean, required: true
  attr :allow_review_submission?, :boolean
  attr :section_slug, :string
  attr :page_revision_slug, :string
  attr :request_path, :string

  defp attempt_summary(assigns) do
    attempt = Core.preload_activity_part_attempts(assigns.attempt)

    feedback_texts =
      if assigns.is_adaptive,
        do: Utils.extract_feedback_text(attempt.activity_attempts),
        else: []

    assigns = assign(assigns, feedback_texts: feedback_texts)

    ~H"""
    <div
      id={"attempt_#{@index}_summary"}
      class="self-stretch py-1 justify-between items-start inline-flex"
    >
      <div class="justify-start items-center flex">
        <div class="w-[92px] opacity-40 dark:text-white text-xs font-bold font-['Open Sans'] uppercase leading-normal tracking-wide">
          Attempt <%= @index %>:
        </div>
        <div class="py-1 justify-end items-center gap-1.5 flex text-green-700 dark:text-green-500">
          <div
            :if={@attempt.lifecycle_state == :submitted}
            class="justify-end items-center gap-1 flex text-xs font-semibold tracking-tight"
            role="attempt status"
          >
            Submitted
          </div>
        </div>

        <div
          :if={@attempt.lifecycle_state == :evaluated}
          class="py-1 justify-end items-center gap-1.5 flex text-green-700 dark:text-green-500"
        >
          <div class="w-4 h-4 relative"><Icons.star /></div>
          <div class="justify-end items-center gap-1 flex text-xs font-semibold tracking-tight">
            <div role="attempt score">
              <%= Float.round(@attempt.score, 2) %>
            </div>
            <div class="tracking-[4px]">
              /
            </div>
            <div role="attempt out of">
              <%= Float.round(@attempt.out_of, 2) %>
            </div>
          </div>
        </div>
      </div>
      <div class="flex-col justify-start items-end inline-flex" role="attempt submission">
        <div class="py-1 justify-start items-start gap-1 inline-flex">
          <div class="opacity-50 dark:text-white text-xs font-normal font-['Open Sans']">
            Submitted:
          </div>
          <div class="dark:text-white text-xs font-normal font-['Open Sans']">
            <%= FormatDateTime.to_formatted_datetime(
              @attempt.date_submitted,
              @ctx,
              "{WDshort} {Mshort} {D}, {YYYY}"
            ) %>
          </div>
        </div>
        <div
          :if={@allow_review_submission?}
          class="w-[124px] py-1 justify-end items-center gap-2.5 inline-flex"
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
            role="review_attempt_link"
          >
            <div class="cursor-pointer hover:opacity-40 text-blue-500 text-xs font-semibold font-['Open Sans'] uppercase tracking-wide">
              Review
            </div>
          </.link>
        </div>
      </div>
    </div>
    <div :if={@is_adaptive && @feedback_texts != []} class="mt-2 mb-8">
      <div class="text-neutral-500 text-sm font-bold mb-2">Instructor Feedback:</div>
      <div class="flex flex-col gap-y-2">
        <%= for feedback <- @feedback_texts do %>
          <p class="w-full text-black font-normal dark:text-neutral-500" readonly>
            <%= feedback %>
          </p>
        <% end %>
      </div>
    </div>
    """
  end

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

  defp get_max_attempts(%{effective_settings: %{max_attempts: 0}} = _page_context),
    do: "unlimited"

  defp get_max_attempts(%{effective_settings: %{max_attempts: max_attempts}} = _page_context),
    do: max_attempts

  defp get_attempts_count(%{historical_attempts: resource_attempts} = _page_context) do
    Enum.count(resource_attempts, fn a -> a.revision.graded == true end)
  end

  defp get_ordinal_attempt(page_context) do
    next_attempt_number = get_attempts_count(page_context) + 1

    case {rem(next_attempt_number, 10), rem(next_attempt_number, 100)} do
      {1, _} -> Integer.to_string(next_attempt_number) <> "st"
      {2, _} -> Integer.to_string(next_attempt_number) <> "nd"
      {3, _} -> Integer.to_string(next_attempt_number) <> "rd"
      {_, 11} -> Integer.to_string(next_attempt_number) <> "th"
      {_, 12} -> Integer.to_string(next_attempt_number) <> "th"
      {_, 13} -> Integer.to_string(next_attempt_number) <> "th"
      _ -> Integer.to_string(next_attempt_number) <> "th"
    end
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
