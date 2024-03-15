defmodule OliWeb.Delivery.Student.LessonLive do
  use OliWeb, :live_view

  import OliWeb.Delivery.Student.Utils,
    only: [page_header: 1, star_icon: 1, scripts: 1]

  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.PageLifecycle.FinalizationSummary
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.{Sections, Settings}
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Components.Delivery.Layouts
  alias OliWeb.Components.Modal
  alias OliWeb.Delivery.Student.Utils
  alias OliWeb.Delivery.Student.Lesson.Annotations

  require Logger

  on_mount {OliWeb.LiveSessionPlugs.InitPage, :page_context}
  on_mount {OliWeb.LiveSessionPlugs.InitPage, :previous_next_index}

  def mount(_params, _session, %{assigns: %{view: :practice_page}} = socket) do
    {:ok,
     socket
     |> assign_html_and_scripts()
     |> assign(annotations_enabled: true, show_sidebar: false, point_markers: nil)}
  end

  def mount(
        _params,
        _session,
        %{assigns: %{view: :graded_page, page_context: %{progress_state: :in_progress}}} = socket
      ) do
    {:ok,
     socket
     |> assign_html_and_scripts()
     |> assign(begin_attempt?: false)}
  end

  def mount(
        _params,
        _session,
        %{assigns: %{view: :adaptive_chromeless, page_context: %{progress_state: :in_progress}}} =
          socket
      ) do
    {:ok,
     socket
     |> assign_scripts()
     |> assign(begin_attempt?: false), layout: false}
  end

  def mount(
        _params,
        _session,
        %{assigns: %{view: view}} = socket
      )
      when view in [:graded_page, :adaptive_chromeless] do
    # for graded pages with no attempt in course, we first show the prologue view (we use begin_attempt? flag to distinguish this).
    # When the student clicks "Begin" we load the needed page scripts via the "LoadSurveyScripts" hook and assign the html to the socket.
    # When the scripts end loading, we receive a "survey_scripts_loaded" confirmation event from the client
    # so we then hide the spinner and show the page content.

    {:ok,
     socket
     |> assign_scripts()
     |> assign(begin_attempt?: false)
     |> assign_new(:request_path, fn -> nil end)}
  end

  def handle_event("begin_attempt", %{"password" => password}, socket)
      when password != socket.assigns.page_context.effective_settings.password do
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

  def handle_event("survey_scripts_loaded", %{"error" => _}, socket) do
    {:noreply, put_flash(socket, :error, "We couldn't load the page. Please try again.")}
  end

  def handle_event("survey_scripts_loaded", _params, socket) do
    {:noreply, assign(socket, show_loader?: false)}
  end

  def handle_event(
        "finalize_attempt",
        _params,
        %{
          assigns: %{
            section: section,
            page_context: page_context,
            datashop_session_id: datashop_session_id,
            request_path: request_path
          }
        } = socket
      ) do
    revision_slug = page_context.page.slug
    attempt_guid = hd(page_context.resource_attempts).attempt_guid

    case PageLifecycle.finalize(section.slug, attempt_guid, datashop_session_id) do
      {:ok,
       %FinalizationSummary{
         graded: true,
         resource_access: %Oli.Delivery.Attempts.Core.ResourceAccess{id: id},
         effective_settings: effective_settings
       }} ->
        # graded resource finalization success
        section = Sections.get_section_by(slug: section.slug)

        if section.grade_passback_enabled,
          do: PageLifecycle.GradeUpdateWorker.create(section.id, id, :inline)

        redirect_to =
          case effective_settings.review_submission do
            :allow ->
              Utils.review_live_path(section.slug, revision_slug, attempt_guid,
                request_path: request_path
              )

            _ ->
              Utils.lesson_live_path(section.slug, revision_slug, request_path: request_path)
          end

        {:noreply, redirect(socket, to: redirect_to)}

      {:ok, %FinalizationSummary{graded: false}} ->
        {:noreply,
         redirect(socket,
           to: Utils.lesson_live_path(section.slug, revision_slug, request_path: request_path)
         )}

      {:error, {reason}}
      when reason in [:already_submitted, :active_attempt_present, :no_more_attempts] ->
        {:noreply, put_flash(socket, :error, "Unable to finalize page")}

      e ->
        error_msg = Kernel.inspect(e)
        Logger.error("Page finalization error encountered: #{error_msg}")
        Oli.Utils.Appsignal.capture_error(error_msg)

        {:noreply, put_flash(socket, :error, "Unable to finalize page")}
    end
  end

  def handle_event("update_point_markers", %{"point_markers" => point_markers}, socket) do
    markers = Enum.map(point_markers, fn pm -> %{id: pm["id"], top: pm["top"]} end)

    {:noreply, assign(socket, point_markers: markers)}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    %{show_sidebar: show_sidebar} = socket.assigns

    {:noreply,
     socket
     |> assign(show_sidebar: !show_sidebar)
     |> push_event("request_point_markers", %{})}
  end

  def render(%{view: :practice_page, annotations_enabled: true} = assigns) do
    # For practice page the activity scripts and activity_bridge script are needed as soon as the page loads.
    ~H"""
    <.page_content_with_sidebar_layout show_sidebar={@show_sidebar}>
      <:header>
        <.page_header
          page_context={@page_context}
          ctx={@ctx}
          index={@current_page["index"]}
          container_label={Utils.get_container_label(@current_page["id"], @section)}
        />
      </:header>

      <div
        id="eventIntercept"
        class="content"
        phx-update="ignore"
        role="page content"
        phx-hook="PointMarkers"
      >
        <%= raw(@html) %>
      </div>

      <:point_markers :if={@show_sidebar && @point_markers}>
        <Annotations.annotation_bubble point_marker={%{id: "page-marker", top: 0}} />
        <Annotations.annotation_bubble
          :for={point_marker <- @point_markers}
          point_marker={point_marker}
        />
      </:point_markers>

      <:sidebar_toggle>
        <Annotations.toggle_notes_button>
          <Annotations.annotations_icon />
        </Annotations.toggle_notes_button>
      </:sidebar_toggle>

      <:sidebar>
        <Annotations.panel show_sidebar={@show_sidebar} />
      </:sidebar>
    </.page_content_with_sidebar_layout>

    <.scripts scripts={@scripts} user_token={@user_token} />
    """
  end

  def render(%{view: :practice_page} = assigns) do
    # For practice page the activity scripts and activity_bridge script are needed as soon as the page loads.
    ~H"""
    <div class="flex-1 flex flex-col w-full overflow-auto">
      <div class="flex-1 mt-20 px-[80px] relative">
        <div class="container mx-auto max-w-[880px] pb-20">
          <.page_header
            page_context={@page_context}
            ctx={@ctx}
            index={@current_page["index"]}
            container_label={Utils.get_container_label(@current_page["id"], @section)}
          />

          <div id="eventIntercept" class="content" phx-update="ignore" role="page content">
            <%= raw(@html) %>
          </div>
        </div>
      </div>
    </div>

    <.scripts scripts={@scripts} user_token={@user_token} />
    """
  end

  def render(
        %{
          view: :graded_page,
          page_context: %{progress_state: :in_progress},
          begin_attempt?: false
        } = assigns
      ) do
    # For graded page with attempt in progress the activity scripts and activity_bridge script are needed as soon as the page loads.
    ~H"""
    <div class="flex pb-20 flex-col w-full items-center gap-15 flex-1 overflow-auto">
      <div class="flex flex-col items-center w-full">
        <.scored_page_banner />
        <div class="flex-1 max-w-[720px] pt-20 pb-10 mx-6 flex-col justify-start items-center gap-10 inline-flex">
          <.page_header
            page_context={@page_context}
            ctx={@ctx}
            index={@current_page["index"]}
            container_label={Utils.get_container_label(@current_page["id"], @section)}
          />
          <div id="eventIntercept" class="content" phx-update="ignore" role="page content">
            <%= raw(@html) %>
            <div class="flex w-full justify-center">
              <button
                id="submit_answers"
                phx-click="finalize_attempt"
                class="cursor-pointer px-5 py-2.5 hover:bg-opacity-40 bg-blue-600 rounded-[3px] shadow justify-center items-center gap-2.5 inline-flex text-white text-sm font-normal font-['Open Sans'] leading-tight"
              >
                Submit Answers
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <.scripts scripts={@scripts} user_token={@user_token} />
    """
  end

  def render(
        %{view: :adaptive_chromeless, page_context: %{progress_state: :in_progress}} = assigns
      ) do
    ~H"""
    <!-- ACTIVITIES -->
    <%= for %{slug: slug, authoring_script: script} <- @activity_types do %>
      <script
        :if={slug == "oli_adaptive"}
        type="text/javascript"
        src={Routes.static_path(OliWeb.Endpoint, "/js/" <> script)}
      >
      </script>
    <% end %>
    <!-- PARTS -->
    <script
      :for={script <- @part_scripts}
      type="text/javascript"
      src={Routes.static_path(OliWeb.Endpoint, "/js/" <> script)}
    >
    </script>

    <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/delivery.js")}>
    </script>

    <div id="delivery_container" phx-update="ignore">
      <%= react_component("Components.Delivery", @app_params) %>
    </div>

    <script>
      window.userToken = "<%= @user_token %>";
    </script>
    """
  end

  def render(%{view: :graded_page, begin_attempt?: true} = assigns) do
    # For graded page with no started attempts, the js scripts are needed after the user clicks "Begin",
    # so we load them with the hook "load_survey_scripts" in the click handle_event functions.
    ~H"""
    <div class="flex pb-20 flex-col w-full items-center gap-15 flex-1 overflow-auto">
      <div class="flex flex-col items-center w-full">
        <.scored_page_banner />
        <div class="flex-1 max-w-[720px] pt-20 pb-10 mx-6 flex-col justify-start items-center gap-10 inline-flex">
          <.page_header
            page_context={@page_context}
            ctx={@ctx}
            index={@current_page["index"]}
            container_label={Utils.get_container_label(@current_page["id"], @section)}
          />
          <div id="page_content" phx-hook="LoadSurveyScripts">
            <div
              :if={@show_loader?}
              phx-remove={
                JS.remove_class("opacity-0",
                  to: "#raw_html",
                  transition: {"ease-out duration-1000", "opacity-0", "opacity-100"}
                )
              }
              class="w-full flex justify-center items-center"
            >
              <Layouts.spinner />
            </div>
            <div
              :if={!@show_loader?}
              id="raw_html"
              class="content opacity-0"
              phx-update="ignore"
              role="page content"
            >
              <%= raw(@html) %>
              <div class="flex w-full justify-center">
                <button
                  id="submit_answers"
                  phx-click="finalize_attempt"
                  class="cursor-pointer px-5 py-2.5 hover:bg-opacity-40 bg-blue-600 rounded-[3px] shadow justify-center items-center gap-2.5 inline-flex text-white text-sm font-normal font-['Open Sans'] leading-tight"
                >
                  Submit Answers
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <script>
      window.userToken = "<%= @user_token %>";
    </script>
    """
  end

  # this render corresponds to the prologue view for graded pages (when there is no attempt in course)
  # TODO: extend the prologue page to support adaptive pages
  def render(%{view: view, begin_attempt?: false} = assigns)
      when view in [:graded_page, :adaptive_chromeless] do
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
    <div class="flex pb-20 flex-col w-full items-center gap-15 flex-1 overflow-auto">
      <div class="flex-1 max-w-[720px] pt-20 pb-10 mx-6 flex-col justify-start items-center gap-10 inline-flex">
        <.page_header
          page_context={@page_context}
          ctx={@ctx}
          index={@current_page["index"]}
          container_label={Utils.get_container_label(@current_page["id"], @section)}
        />
        <div class="self-stretch h-[0px] opacity-80 dark:opacity-20 bg-white border border-gray-200">
        </div>
        <.attempts_summary
          page_context={@page_context}
          attempt_message={@attempt_message}
          ctx={@ctx}
          allow_attempt?={@allow_attempt?}
          section_slug={@section.slug}
          request_path={@request_path}
          adaptive_chromeless?={@view == :adaptive_chromeless}
        />
      </div>
    </div>
    """
  end

  attr :show_sidebar, :boolean, default: false
  slot :header, required: true
  slot :inner_block, required: true
  slot :sidebar, default: nil
  slot :sidebar_toggle, default: nil
  slot :point_markers, default: nil

  defp page_content_with_sidebar_layout(assigns) do
    ~H"""
    <div class="flex-1 flex flex-col w-full overflow-hidden">
      <div class={[
        "flex-1 flex flex-col overflow-auto",
        if(@show_sidebar, do: "xl:mr-[520px]")
      ]}>
        <div class={[
          "flex-1 mt-20 px-[80px] relative",
          if(@show_sidebar, do: "border-r border-gray-300 xl:mr-[80px]")
        ]}>
          <div class="container mx-auto max-w-[880px] pb-20">
            <%= render_slot(@header) %>

            <%= render_slot(@inner_block) %>
          </div>

          <%= render_slot(@point_markers) %>
        </div>
      </div>
    </div>
    <div
      :if={@sidebar && @show_sidebar}
      class="flex flex-col w-[520px] absolute top-20 right-0 bottom-0"
    >
      <%= render_slot(@sidebar) %>
    </div>
    <div :if={@sidebar && !@show_sidebar} class="absolute top-20 right-0">
      <%= render_slot(@sidebar_toggle) %>
    </div>
    """
  end

  attr :attempt_message, :string
  attr :page_context, Oli.Delivery.Page.PageContext
  attr :ctx, OliWeb.Common.SessionContext
  attr :allow_attempt?, :boolean
  attr :adaptive_chromeless?, :boolean
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
          ctx={@ctx}
          allow_review_submission?={@page_context.effective_settings.review_submission == :allow}
          request_path={@request_path}
          adaptive_chromeless?={@adaptive_chromeless?}
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
    """
  end

  attr :index, :integer
  attr :attempt, ResourceAttempt
  attr :ctx, OliWeb.Common.SessionContext
  attr :allow_review_submission?, :boolean
  attr :section_slug, :string
  attr :page_revision_slug, :string
  attr :adaptive_chromeless?, :boolean
  attr :request_path, :string

  defp attempt_summary(assigns) do
    ~H"""
    <div
      id={"attempt_#{@index}_summary"}
      class="self-stretch py-1 justify-between items-start inline-flex"
    >
      <div class="justify-start items-center flex">
        <div class="w-[92px] opacity-40 dark:text-white text-xs font-bold font-['Open Sans'] uppercase leading-normal tracking-wide">
          Attempt <%= @index %>:
        </div>
        <div class="py-1 justify-end items-center gap-1.5 flex">
          <div class="w-4 h-4 relative"><.star_icon /></div>
          <div class="justify-end items-center gap-1 flex">
            <div
              role="attempt score"
              class="text-emerald-600 text-xs font-semibold font-['Open Sans'] tracking-tight"
            >
              <%= Float.round(@attempt.score, 2) %>
            </div>
            <div class="text-emerald-600 text-xs font-semibold font-['Open Sans'] tracking-[4px]">
              /
            </div>
            <div
              role="attempt out of"
              lass="text-emerald-600 text-xs font-semibold font-['Open Sans'] tracking-tight"
            >
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
          :if={@allow_review_submission? and not @adaptive_chromeless?}
          class="w-[124px] py-1 justify-end items-center gap-2.5 inline-flex"
        >
          <.link
            href={
              Utils.review_live_path(
                @section_slug,
                @page_revision_slug,
                @attempt.attempt_guid,
                request_path: @request_path
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
           ),
         :ok <- maybe_redirect_adaptive(socket.assigns.view, section.slug, revision.slug) do
      page_context =
        PageContext.create_for_visit(
          section,
          socket.assigns.page_context.page.slug,
          socket.assigns.current_user,
          socket.assigns.datashop_session_id
        )

      {:noreply,
       socket
       |> assign(page_context: page_context)
       |> assign(begin_attempt?: true, show_loader?: true)
       |> clear_flash()
       |> assign_html()
       |> load_scripts_on_client_side()}
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

  defp assign_html_and_scripts(socket) do
    socket
    |> assign_scripts()
    |> assign_html()
  end

  defp assign_scripts(socket) do
    assign(socket,
      scripts: Utils.get_required_activity_scripts(socket.assigns.page_context)
    )
  end

  defp assign_html(socket) do
    assign(socket,
      html: Utils.build_html(socket.assigns, :delivery)
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

  defp load_scripts_on_client_side(socket) do
    push_event(socket, "load_survey_scripts", %{
      script_sources: Enum.map(socket.assigns.scripts, fn script -> "/js/#{script}" end)
    })
  end

  defp check_gating_conditions(section, user, resource_id) do
    case Oli.Delivery.Gating.blocked_by(section, user, resource_id) do
      [] -> :ok
      gates -> {:error, {:gates, gates}}
    end
  end

  defp maybe_redirect_adaptive(:adaptive_chromeless, section_slug, revision_slug),
    do: {:redirect, ~p"/sections/#{section_slug}/adaptive_lesson/#{revision_slug}"}

  defp maybe_redirect_adaptive(_, _, _), do: :ok
end
