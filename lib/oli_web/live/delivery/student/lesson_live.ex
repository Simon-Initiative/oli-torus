defmodule OliWeb.Delivery.Student.LessonLive do
  use OliWeb, :live_view

  on_mount {OliWeb.LiveSessionPlugs.InitPage, :page_context}
  on_mount {OliWeb.LiveSessionPlugs.InitPage, :previous_next_index}

  alias Oli.Activities
  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.{Sections, Settings}
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias Oli.Rendering.{Context, Page}
  alias Oli.Resources
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Components.Modal

  def mount(_params, _session, %{assigns: %{view: :practice_page}} = socket) do
    {:ok, assign_html_and_scripts(socket)}
  end

  def mount(_params, _session, %{assigns: %{view: :graded_page}} = socket) do
    # for graded pages, we first show the prologue and when the student click "Begin/Continue Attempt"
    # we load the html. Scripts need to be loaded in advance.
    {:ok, assign_scripts(socket)}
  end

  def handle_event(event, %{"password" => password}, socket)
      when event in ["begin_attempt", "continue_attempt"] and
             password != socket.assigns.page_context.effective_settings.password do
    {:noreply, put_flash(socket, :error, "Incorrect password")}
  end

  def handle_event("begin_attempt", _params, socket) do
    %{
      current_user: user,
      section: section,
      page_context: %{effective_settings: effective_settings, page: revision},
      ctx: ctx
    } = socket.assigns

    case Settings.check_start_date(effective_settings) do
      {:allowed} ->
        do_start_attempt(socket, section, user, revision, effective_settings)

      {:before_start_date} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This assessment is not yet available. It will be available on #{date(effective_settings.start_date, ctx: ctx, precision: :minutes)}."
         )}
    end
  end

  def handle_event("continue_attempt", _params, socket) do
    {:noreply,
     socket
     |> assign(continue_checked: true)
     |> clear_flash()
     |> assign_html()}
  end

  def render(%{view: view, continue_checked: continue_checked} = assigns)
      when view == :practice_page or (view == :graded_page and continue_checked) do
    # TODO after submitting answers, user should be redirected to the new NG23 review page.
    # (now it is being redirected to old version of review page)
    # We should replace the onClick with its equivalent function in Elixir: Oli.Delivery.Attempts.PageLifecycle.finalize
    # and then redirect to the new review page.
    ~H"""
    <div class="flex pb-20 flex-col items-center gap-15 flex-1">
      <div class="flex flex-col items-center w-full">
        <.scored_page_banner :if={@view == :graded_page} />
        <div class="w-[720px] pt-20 pb-10 flex-col justify-start items-center gap-10 inline-flex">
          <.page_header
            page_context={@page_context}
            ctx={@ctx}
            index={@current_page["index"]}
            container_label={get_container_label(@current_page["id"], @section)}
          />
          <div phx-update="ignore" id="eventIntercept" class="content" role="page_content">
            <%= raw(@html) %>
          </div>
          <button
            :if={@view == :graded_page}
            id="submit_answers"
            onClick={"window.OLI.finalize('#{@section.slug}', '#{@page_context.page.slug}', '#{hd(@page_context.resource_attempts).attempt_guid || nil}', #{@page_context.page.graded}, 'submit_answers')"}
            class="cursor-pointer px-5 py-2.5 hover:bg-opacity-40 bg-blue-600 rounded-[3px] shadow justify-center items-center gap-2.5 inline-flex text-white text-sm font-normal font-['Open Sans'] leading-tight"
          >
            Submit Answers
          </button>
        </div>
      </div>
    </div>

    <script>
      window.userToken = "<%= @user_token %>";
    </script>
    <script>
      OLI.initActivityBridge('eventIntercept');
    </script>
    <script :for={script <- @scripts} type="text/javascript" src={"/js/#{script}"}>
    </script>
    """
  end

  # this render corresponds to the prologue view
  def render(%{view: :graded_page, continue_checked: false} = assigns) do
    ~H"""
    <Modal.modal id="password_attempt_modal" class="w-1/2">
      <:title>Provide Assessment Password</:title>
      <.form
        phx-submit={
          JS.push(
            if(@page_context.progress_state == :in_progress,
              do: "continue_attempt",
              else: "begin_attempt"
            )
          )
          |> Modal.hide_modal("password_attempt_modal")
        }
        for={%{}}
        class="flex flex-col gap-6"
      >
        <input id="password_attempt_input" type="password" name="password" field={:password} value="" />
        <.button type="submit" class="mx-auto btn btn-primary">
          <%= if(@page_context.progress_state == :in_progress, do: "Continue", else: "Begin") %>
        </.button>
      </.form>
    </Modal.modal>
    <div class="flex pb-20 flex-col items-center gap-15 flex-1">
      <div class="w-[720px] pt-20 pb-10 flex-col justify-start items-center gap-10 inline-flex">
        <.page_header
          page_context={@page_context}
          ctx={@ctx}
          index={@current_page["index"]}
          container_label={get_container_label(@current_page["id"], @section)}
        />
        <div class="self-stretch h-[0px] opacity-80 dark:opacity-20 bg-white border border-gray-200">
        </div>
        <.attempts_summary
          page_context={@page_context}
          attempt_message={@attempt_message}
          ctx={@ctx}
          allow_attempt?={@allow_attempt?}
        />
      </div>
    </div>

    <script>
      window.userToken = "<%= @user_token %>";
    </script>
    <script>
      OLI.initActivityBridge('eventIntercept');
    </script>
    <script :for={script <- @scripts} type="text/javascript" src={"/js/#{script}"}>
    </script>
    """
  end

  attr :attempt_message, :string
  attr :page_context, Oli.Delivery.Page.PageContext
  attr :ctx, OliWeb.Common.SessionContext
  attr :allow_attempt?, :boolean

  defp attempts_summary(assigns) do
    ~H"""
    <div class="w-full flex-col justify-start items-start gap-3 flex">
      <div class="self-stretch justify-start items-start gap-6 inline-flex relative">
        <div
          id="attempts_summary_with_tooltip"
          phx-hook="TooltipWithTarget"
          data-tooltip-target-id="attempt_tooltip"
          class="opacity-80 cursor-help dark:text-white text-sm font-bold font-['Open Sans'] uppercase tracking-wider"
        >
          AttemptS <%= get_attempts_count(@page_context) %>/<%= get_max_attempts(@page_context) %>
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
              Enum.filter(@page_context.historical_attempts, fn a ->
                a.revision.graded == true and a.score != nil
              end)
              |> Enum.with_index(1)
          }
          index={index}
          attempt={attempt}
          ctx={@ctx}
        />
      </div>
    </div>
    <button
      :if={@page_context.progress_state == :not_started}
      id="begin_attempt_button"
      disabled={!@allow_attempt?}
      phx-click={
        if(@page_context.effective_settings.password not in [nil, ""],
          do: Modal.show_modal("password_attempt_modal") |> JS.focus(to: "#password_attempt_input"),
          else: "begin_attempt"
        )
      }
      class={[
        "cursor-pointer px-5 py-2.5 hover:bg-opacity-40 bg-blue-600 rounded-[3px] shadow justify-center items-center gap-2.5 inline-flex text-white text-sm font-normal font-['Open Sans'] leading-tight",
        if(!@allow_attempt?, do: "opacity-50 dark:opacity-20 disabled !cursor-not-allowed")
      ]}
    >
      Begin <%= get_ordinal_attempt(@page_context) %> Attempt
    </button>

    <button
      :if={@page_context.progress_state == :in_progress}
      id="continue_attempt_button"
      disabled={!@allow_attempt?}
      phx-click={
        if(@page_context.effective_settings.password not in [nil, ""],
          do: Modal.show_modal("password_attempt_modal") |> JS.focus(to: "#password_attempt_input"),
          else: "continue_attempt"
        )
      }
      class={[
        "cursor-pointer px-5 py-2.5 hover:bg-opacity-40 bg-blue-600 rounded-[3px] shadow justify-center items-center gap-2.5 inline-flex text-white text-sm font-normal font-['Open Sans'] leading-tight",
        if(!@allow_attempt?, do: "opacity-50 dark:opacity-20 disabled !cursor-not-allowed")
      ]}
    >
      Continue <%= get_ordinal_attempt(@page_context) %> Attempt
    </button>
    """
  end

  attr :index, :integer
  attr :attempt, Oli.Delivery.Attempts.Core.ResourceAttempt
  attr :ctx, OliWeb.Common.SessionContext

  defp attempt_summary(assigns) do
    # TODO: add link to review page
    ~H"""
    <div class="self-stretch py-1 justify-between items-start inline-flex">
      <div class="justify-start items-center flex">
        <div class="w-[92px] opacity-40 dark:text-white text-xs font-bold font-['Open Sans'] uppercase leading-normal tracking-wide">
          Attempt <%= @index %>:
        </div>
        <div class="py-1 justify-end items-center gap-1.5 flex">
          <div class="w-4 h-4 relative"><.star_icon /></div>
          <div class="justify-end items-center gap-1 flex">
            <div class="text-emerald-600 text-xs font-semibold font-['Open Sans'] tracking-tight">
              <%= Float.round(@attempt.score, 2) %>
            </div>
            <div class="text-emerald-600 text-xs font-semibold font-['Open Sans'] tracking-[4px]">
              /
            </div>
            <div class="text-emerald-600 text-xs font-semibold font-['Open Sans'] tracking-tight">
              <%= Float.round(@attempt.out_of, 2) %>
            </div>
          </div>
        </div>
      </div>
      <div class="flex-col justify-start items-end inline-flex">
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
        <div class="w-[124px] py-1 justify-end items-center gap-2.5 inline-flex">
          <div class="cursor-pointer hover:opacity-40 text-blue-500 text-xs font-semibold font-['Open Sans'] uppercase tracking-wide">
            Review
          </div>
        </div>
      </div>
    </div>
    """
  end

  # As we implement more scenarios we can add more clauses to this function depending on the :view key.
  def render(assigns) do
    ~H"""
    <div>hi, this is still in dev</div>
    """
  end

  def scored_page_banner(assigns) do
    ~H"""
    <div class="w-full lg:px-20 px-40 py-9 bg-orange-500 bg-opacity-10 flex flex-col justify-center items-center gap-2.5">
      <div class="px-3 py-1.5 rounded justify-start items-start gap-2.5 flex">
        <div class="dark:text-white text-sm font-bold uppercase tracking-wider">
          Scored Activity
        </div>
      </div>
      <div class="max-w-[720px] w-full mx-auto opacity-90 dark:text-white text-sm font-normal leading-6">
        You can start or stop at any time, and your progress will be saved. When you submit your answers using the Submit button, it will count as an attempt. So make sure you have answered all the questions before submitting.
      </div>
    </div>
    """
  end

  attr :page_context, Oli.Delivery.Page.PageContext
  attr :ctx, OliWeb.Common.SessionContext
  attr :index, :string
  attr :container_label, :string
  attr :has_assignments?, :boolean

  def page_header(assigns) do
    ~H"""
    <div id="page_header" class="flex-col justify-start items-start gap-9 flex w-full">
      <div class="flex-col justify-start items-start gap-3 flex w-full">
        <div class="self-stretch flex-col justify-start items-start flex">
          <div class="self-stretch justify-between items-center inline-flex">
            <div class="grow shrink basis-0 self-stretch justify-start items-center gap-3 flex">
              <div
                role="container label"
                class="opacity-50 dark:text-white text-sm font-bold font-['Open Sans'] uppercase tracking-wider"
              >
                <%= @container_label %>
              </div>

              <div
                :if={@page_context.page.graded}
                class="w-px self-stretch opacity-40 bg-black dark:bg-white"
              >
              </div>
              <div
                :if={@page_context.page.graded}
                class="justify-start items-center gap-1.5 flex"
                role="graded page marker"
              >
                <div class="w-[18px] h-[18px] relative">
                  <.flag_icon />
                </div>
                <div class="opacity-50 dark:text-white text-sm font-bold font-['Open Sans'] uppercase tracking-wider">
                  Graded Page
                </div>
              </div>
            </div>
            <div
              :if={@page_context.page.graded}
              class="px-2 py-1 bg-black bg-opacity-10 dark:bg-white dark:bg-opacity-10 rounded-xl shadow justify-start items-center gap-1 flex"
              role="assignment marker"
            >
              <div class="dark:text-white text-[10px] font-normal font-['Open Sans']">
                Assignment requirement
              </div>
            </div>
          </div>
          <div role="page label" class="self-stretch justify-start items-start gap-2.5 inline-flex">
            <div
              role="page numbering index"
              class="opacity-50 dark:text-white text-[38px] font-bold font-['Open Sans']"
            >
              <%= @index %>.
            </div>
            <div
              role="page title"
              class="grow shrink basis-0 dark:text-white text-[38px] font-bold font-['Open Sans']"
            >
              <%= @page_context.page.title %>
            </div>
          </div>
        </div>
        <div class="justify-start items-center gap-3 inline-flex">
          <div class="opacity-50 justify-start items-center gap-1.5 flex">
            <div role="page read time" class="justify-end items-center gap-1 flex">
              <div class="w-[18px] h-[18px] relative opacity-80">
                <.time_icon />
              </div>
              <div class="justify-end items-end gap-0.5 flex">
                <div class="text-right dark:text-white text-xs font-bold font-['Open Sans'] uppercase tracking-wide">
                  <%= @page_context.page.duration_minutes %>
                </div>
                <div class="dark:text-white text-[9px] font-bold font-['Open Sans'] uppercase tracking-wide">
                  min
                </div>
              </div>
            </div>
          </div>
          <div role="page schedule" class="justify-start items-start gap-1 flex">
            <div class="opacity-50 dark:text-white text-xs font-normal font-['Open Sans']">Due:</div>
            <div class="dark:text-white text-xs font-normal font-['Open Sans']">
              <%= FormatDateTime.to_formatted_datetime(
                @page_context.effective_settings.end_date,
                @ctx,
                "{WDshort} {Mshort} {D}, {YYYY}"
              ) %>
            </div>
          </div>
        </div>
      </div>
      <div
        :if={@page_context.objectives not in [nil, []]}
        class="flex-col justify-start items-start gap-3 flex w-full"
        role="page objectives"
      >
        <div class="self-stretch justify-start items-start gap-6 inline-flex">
          <div class="opacity-80 dark:text-white text-sm font-bold font-['Open Sans'] uppercase tracking-wider">
            Learning objectives
          </div>
          <div class="hidden text-blue-500 text-sm font-semibold font-['Open Sans']">View More</div>
        </div>
        <div
          :for={{objective, index} <- Enum.with_index(@page_context.objectives, 1)}
          class="self-stretch flex-col justify-start items-start flex"
          role={"objective #{index}"}
        >
          <div class="self-stretch py-1 justify-start items-start inline-flex">
            <div class="grow shrink basis-0 h-6 justify-start items-start flex">
              <div class="w-[30px] opacity-40 dark:text-white text-xs font-bold font-['Open Sans'] leading-normal">
                L<%= index %>
              </div>
              <div class="grow shrink basis-0 opacity-80 dark:text-white text-sm font-normal font-['Open Sans'] leading-normal">
                <%= objective %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def star_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      role="star icon"
    >
      <path
        d="M3.88301 14.0007L4.96634 9.31732L1.33301 6.16732L6.13301 5.75065L7.99967 1.33398L9.86634 5.75065L14.6663 6.16732L11.033 9.31732L12.1163 14.0007L7.99967 11.5173L3.88301 14.0007Z"
        fill="#0CAF61"
      />
    </svg>
    """
  end

  def flag_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="18"
      height="18"
      viewBox="0 0 18 18"
      fill="none"
      role="flag icon"
    >
      <path d="M3.75 15.75V3H10.5L10.8 4.5H15V12H9.75L9.45 10.5H5.25V15.75H3.75Z" fill="#F68E2E" />
    </svg>
    """
  end

  def time_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="18"
      height="18"
      viewBox="0 0 18 18"
      fill="none"
      role="time icon"
    >
      <g opacity="0.8">
        <path
          class="fill-black dark:fill-white"
          d="M11.475 12.525L12.525 11.475L9.75 8.7V5.25H8.25V9.3L11.475 12.525ZM9 16.5C7.9625 16.5 6.9875 16.3031 6.075 15.9094C5.1625 15.5156 4.36875 14.9813 3.69375 14.3063C3.01875 13.6313 2.48438 12.8375 2.09063 11.925C1.69688 11.0125 1.5 10.0375 1.5 9C1.5 7.9625 1.69688 6.9875 2.09063 6.075C2.48438 5.1625 3.01875 4.36875 3.69375 3.69375C4.36875 3.01875 5.1625 2.48438 6.075 2.09063C6.9875 1.69688 7.9625 1.5 9 1.5C10.0375 1.5 11.0125 1.69688 11.925 2.09063C12.8375 2.48438 13.6313 3.01875 14.3063 3.69375C14.9813 4.36875 15.5156 5.1625 15.9094 6.075C16.3031 6.9875 16.5 7.9625 16.5 9C16.5 10.0375 16.3031 11.0125 15.9094 11.925C15.5156 12.8375 14.9813 13.6313 14.3063 14.3063C13.6313 14.9813 12.8375 15.5156 11.925 15.9094C11.0125 16.3031 10.0375 16.5 9 16.5ZM9 15C10.6625 15 12.0781 14.4156 13.2469 13.2469C14.4156 12.0781 15 10.6625 15 9C15 7.3375 14.4156 5.92188 13.2469 4.75313C12.0781 3.58438 10.6625 3 9 3C7.3375 3 5.92188 3.58438 4.75313 4.75313C3.58438 5.92188 3 7.3375 3 9C3 10.6625 3.58438 12.0781 4.75313 13.2469C5.92188 14.4156 7.3375 15 9 15Z"
        />
      </g>
    </svg>
    """
  end

  def do_start_attempt(socket, section, user, revision, effective_settings) do
    datashop_session_id = socket.assigns.datashop_session_id
    activity_provider = &Oli.Delivery.ActivityProvider.provide/6

    # We must check gating conditions here to account for gates that activated after
    # the prologue page was rendered, and for malicious/deliberate attempts to start an attempt via
    # hitting this endpoint.
    case Oli.Delivery.Gating.blocked_by(section, user, revision.resource_id) do
      [] ->
        case PageLifecycle.start(
               revision.slug,
               section.slug,
               datashop_session_id,
               user,
               effective_settings,
               activity_provider
             ) do
          {:ok, _attempt_state} ->
            page_context =
              PageContext.create_for_visit(
                socket.assigns.section,
                socket.assigns.page_context.page.slug,
                socket.assigns.current_user,
                socket.assigns.datashop_session_id
              )

            # we mark the continue_checked=true to avoid showing the prologue with the "Continue" button again
            # since the user has just clicked the "Begin" button in that same prologue.
            {:noreply,
             socket
             |> assign(page_context: page_context)
             |> assign(continue_checked: true)
             |> clear_flash()
             |> assign_html()}

          {:error, {:end_date_passed}} ->
            {:noreply, put_flash(socket, :error, "This assessment's end date passed.")}

          {:error, {:active_attempt_present}} ->
            {:noreply, put_flash(socket, :error, "You already have an active attempt.")}

          {:error, {:no_more_attempts}} ->
            {:noreply, put_flash(socket, :error, "You have no attempts remaining.")}

          _ ->
            {:noreply, put_flash(socket, :error, "Failed to start new attempt")}
        end

      _ ->
        # In the case where a gate exists we want to redirect to this page display, which will
        # then pick up the gate and show that feedback to the user
        redirect(socket,
          to: Routes.page_delivery_path(socket, :page, section.slug, revision.slug)
        )
    end
  end

  defp get_container_label(page_id, section) do
    container =
      Oli.Delivery.Hierarchy.find_parent_in_hierarchy(
        section.full_hierarchy,
        fn node -> node["resource_id"] == String.to_integer(page_id) end
      )["numbering"]

    Sections.get_container_label_and_numbering(
      %{numbering_level: container["level"], numbering_index: container["index"]},
      section.customizations
    )
  end

  defp get_max_attempts(%{effective_settings: %{max_attempts: 0}} = _page_context),
    do: "unlimited"

  defp get_max_attempts(%{effective_settings: %{max_attempts: max_attempts}} = _page_context),
    do: max_attempts

  defp get_attempts_count(
         %{historical_attempts: resource_attempts, progress_state: progress_state} = _page_context
       ) do
    case progress_state do
      :not_started ->
        Enum.count(resource_attempts, fn a -> a.revision.graded == true end)

      :in_progress ->
        # do not count current attempt (not yet submitted)
        Enum.count(resource_attempts, fn a -> a.revision.graded == true end) - 1
    end
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

  defp assign_html_and_scripts(socket) do
    socket
    |> assign_scripts()
    |> assign_html()
  end

  defp assign_scripts(socket) do
    assign(socket,
      scripts: get_required_activity_scripts(socket.assigns.page_context)
    )
  end

  defp assign_html(socket) do
    %{section: section, current_user: current_user, page_context: page_context} = socket.assigns

    render_context = %Context{
      enrollment:
        Oli.Delivery.Sections.get_enrollment(
          section.slug,
          current_user.id
        ),
      user: current_user,
      section_slug: section.slug,
      mode: :delivery,
      activity_map: page_context.activities,
      resource_summary_fn: &Resources.resource_summary(&1, section.slug, Resolver),
      alternatives_groups_fn: fn ->
        Resources.alternatives_groups(section.slug, Resolver)
      end,
      alternatives_selector_fn: &Resources.Alternatives.select/2,
      extrinsic_read_section_fn: &Oli.Delivery.ExtrinsicState.read_section/3,
      bib_app_params: page_context.bib_revisions,
      historical_attempts: page_context.historical_attempts,
      learning_language: Sections.get_section_attributes(section).learning_language,
      effective_settings: page_context.effective_settings
      # when migrating from page_delivery_controller this key-values were found
      # to apparently not be used by the page template:
      #   project_slug: base_project_slug,
      #   submitted_surveys: submitted_surveys,
      #   resource_attempt: hd(context.resource_attempts)
    }

    attempt_content = get_attempt_content(page_context)

    # Cache the page as text to allow the AI agent LV to access it.
    cache_page_as_text(render_context, attempt_content, page_context.page.id)

    assign(socket,
      html: Page.render(render_context, attempt_content, Page.Html)
    )
  end

  defp cache_page_as_text(render_context, content, page_id) do
    Oli.Converstation.PageContentCache.put(
      page_id,
      Page.render(render_context, content, Page.Markdown) |> :erlang.iolist_to_binary()
    )
  end

  defp get_required_activity_scripts(%{activities: activities} = _page_context)
       when activities != nil do
    # this is an optimization to exclude not needed activity scripts (~1.5mb each)
    Enum.map(activities, fn {_activity_id, activity} ->
      activity.script
    end)
    |> Enum.uniq()
  end

  defp get_required_activity_scripts(_page_context) do
    # TODO Optimization: get only activity scripts of activities contained in the page.
    # We could infer the contained activities from the page revision content model.
    all_activities = Activities.list_activity_registrations()
    Enum.map(all_activities, fn a -> a.delivery_script end)
  end

  defp get_attempt_content(page_context) do
    this_attempt = page_context.resource_attempts |> hd

    if Enum.any?(this_attempt.errors, fn e ->
         e == "Selection failed to fulfill: no values provided for expression"
       end) and page_context.is_student do
      %{"model" => []}
    else
      this_attempt.content
    end
  end
end
