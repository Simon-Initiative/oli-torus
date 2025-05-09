defmodule OliWeb.LiveSessionPlugs.InitPage do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2, update: 3]

  alias Oli.Delivery.{Metrics, PreviousNextIndex, Settings}
  alias Oli.Delivery.Page.{PageContext, PrologueContext}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.FormatDateTime

  def on_mount(:set_prologue_context, %{"revision_slug" => revision_slug}, _session, socket) do
    %{section: section, current_user: current_user} = socket.assigns

    page_context =
      PrologueContext.create_for_visit(
        section,
        revision_slug,
        current_user
      )

    {:cont, prologue_assigns(socket, page_context)}
  end

  def on_mount(:set_prologue_context, :not_mounted_at_router, _session, socket) do
    {:cont, socket}
  end

  def on_mount(:set_page_context, :not_mounted_at_router, _session, socket) do
    {:cont, socket}
  end

  def on_mount(:set_page_context, %{"revision_slug" => revision_slug}, _session, socket) do
    %{section: section, current_user: current_user, datashop_session_id: datashop_session_id} =
      socket.assigns

    if Phoenix.LiveView.connected?(socket) do
      page_context =
        PageContext.create_for_visit(
          section,
          revision_slug,
          current_user,
          datashop_session_id
        )

      {:cont,
       assign(socket,
         page_context: page_context,
         # the page context will be a temporary assign,
         # that is why we need to "duplicate" the page context progress state in another socket assign
         page_progress_state: page_context.progress_state
       )}
    else
      {:cont, socket}
    end
  end

  def on_mount(
        :previous_next_index,
        _params,
        _session,
        %{assigns: assigns} = socket
      ) do
    if Phoenix.LiveView.connected?(socket) do
      resource_id = assigns.page_context.page.resource_id

      # note will all be nil for case of "loose" linked pages not in hierarchy
      {:ok, {previous, next, current}, _} =
        PreviousNextIndex.retrieve(assigns.section, resource_id, skip: [:section])

      socket =
        case assigns.view do
          :adaptive_chromeless ->
            previous_url = url_from_desc(assigns.section.slug, previous)
            next_url = url_from_desc(assigns.section.slug, next)

            update(
              socket,
              :app_params,
              &Map.merge(&1, %{previousPageURL: previous_url, nextPageURL: next_url})
            )

          _ ->
            socket
        end

      pages_progress =
        Metrics.progress_for_pages(
          assigns.section.id,
          assigns.ctx.user.id,
          [previous["id"], next["id"]]
        )

      {:cont,
       assign(socket,
         previous_page: previous,
         next_page: next,
         current_page: current,
         pages_progress: pages_progress
       )}
    else
      {:cont, socket}
    end
  end

  def on_mount(
        :init_context_state,
        params,
        _session,
        socket
      ) do
    if Phoenix.LiveView.connected?(socket) do
      {:cont, init_context_state(socket, params)}
    else
      {:cont, socket}
    end
  end

  # Handles the 2 cases of adaptive delivery
  #  1. A fullscreen chromeless version
  #  2. A version inside the torus navigation with an iframe pointing to #1
  defp init_context_state(
         %{
           assigns: %{
             page_context:
               %PageContext{
                 page: %{
                   content:
                     %{
                       "advancedDelivery" => true
                     } = content
                 }
               } = page_context
           }
         } =
           socket,
         params
       ) do
    view =
      if Map.get(content, "displayApplicationChrome", false) do
        :graded_page
      else
        :adaptive_chromeless
      end

    section = socket.assigns.section
    activity_types = Oli.Activities.activities_for_section()
    resource_attempt = Enum.at(page_context.resource_attempts, 0)

    app_params = %{
      activityTypes: activity_types,
      resourceId: page_context.page.resource_id,
      sectionSlug: section.slug,
      userId: page_context.user.id,
      userName: page_context.user.name,
      pageTitle: page_context.page.title,
      pageSlug: page_context.page.slug,
      graded: page_context.page.graded,
      content: build_page_content(page_context.page.content, params["request_path"]),
      resourceAttemptState: resource_attempt && resource_attempt.state,
      resourceAttemptGuid: resource_attempt && resource_attempt.attempt_guid,
      currentServerTime: DateTime.utc_now() |> to_epoch,
      effectiveEndTime:
        Settings.determine_effective_deadline(
          resource_attempt,
          page_context.effective_settings
        )
        |> to_epoch,
      lateSubmit: page_context.effective_settings.late_submit,
      activityGuidMapping: page_context.activities,
      signoutUrl: ~p"/users/log_out",
      previewMode: false,
      isInstructor: true,
      reviewMode: page_context.review_mode,
      overviewURL: ~p"/sections/#{section.slug}",
      finalizeGradedURL:
        Routes.page_lifecycle_path(
          OliWeb.Endpoint,
          :transition
        ),
      screenIdleTimeOutInSeconds:
        String.to_integer(System.get_env("SCREEN_IDLE_TIMEOUT_IN_SECONDS", "1800"))
    }

    assign(socket, %{
      view: view,
      page_context: page_context,
      app_params: app_params,
      activity_types: activity_types,
      part_scripts: Oli.PartComponents.get_part_component_scripts(:delivery_script),
      scripts: Oli.Activities.get_activity_scripts(:delivery_script),
      title: page_context.page.title,
      additional_stylesheets: Map.get(content, "additionalStylesheets", []),
      bib_app_params: %{
        bibReferences: page_context.bib_revisions
      }
    })
  end

  # Display practice pages
  defp init_context_state(
         %{
           assigns: %{
             page_context:
               %PageContext{
                 page: %{graded: false}
               } = page_context
           }
         } =
           socket,
         _params
       ) do
    assign(socket, %{
      view: :practice_page,
      activity_count: map_size(page_context.activities),
      advanced_delivery: Map.get(page_context.page.content, "advancedDelivery", false),
      bib_app_params: %{
        bibReferences: page_context.bib_revisions
      }
    })
  end

  # Display the prologue view for graded pages
  defp init_context_state(
         %{
           assigns: %{
             page_context: %PageContext{page: %{graded: true}} = page_context
           }
         } =
           socket,
         _params
       ) do
    assign(socket, %{
      view: :graded_page,
      bib_app_params: %{
        bibReferences: page_context.bib_revisions
      }
    })
  end

  defp init_context_state(
         %{
           assigns: %{
             page_context: %PageContext{progress_state: :error}
           }
         } =
           socket,
         _params
       ) do
    assign(socket, %{view: :error})
  end

  defp plural(1), do: ""
  defp plural(_), do: "s"

  defp url_from_desc(_, nil), do: nil

  defp url_from_desc(section_slug, %{"type" => "container", "slug" => slug}),
    do: ~p"/sections/#{section_slug}/preview/container/#{slug}"

  defp url_from_desc(section_slug, %{"type" => "page", "slug" => slug}),
    do: ~p"/sections/#{section_slug}/preview/page/#{slug}"

  defp to_epoch(nil), do: nil

  defp to_epoch(date_time) do
    date_time
    |> DateTime.to_unix(:second)
    |> Kernel.*(1000)
  end

  defp prologue_assigns(socket, page_context) do
    # Only consider graded attempts
    resource_attempts =
      Enum.filter(page_context.resource_attempts, fn a -> a.revision.graded end)

    attempts_taken = length(resource_attempts)

    blocking_gates =
      Oli.Delivery.Gating.blocked_by(
        socket.assigns.section,
        socket.assigns.current_user,
        page_context.page.resource_id
      )

    new_attempt_allowed =
      Settings.new_attempt_allowed(
        page_context.effective_settings,
        attempts_taken,
        blocking_gates
      )

    attempt_message =
      case {new_attempt_allowed, page_context.effective_settings.max_attempts} do
        {{:blocking_gates}, _max_attempts} ->
          Oli.Delivery.Gating.details(blocking_gates,
            format_datetime: format_datetime_fn(socket.assigns.ctx)
          )

        {{:no_attempts_remaining}, max_attempts} ->
          "You have no attempts remaining out of #{max_attempts} total attempt#{plural(max_attempts)}."

        {{:before_start_date}, _max_attempts} ->
          "This assessment is not yet available. It will be available on #{OliWeb.Common.FormatDateTime.date(page_context.effective_settings.start_date, precision: :minutes)}"

        {{:end_date_passed}, _max_attempts} ->
          "The deadline for this assignment has passed."

        {{:allowed}, 0} ->
          "You can take this scored page an unlimited number of times"

        {{:allowed}, max_attempts} ->
          attempts_remaining = max_attempts - attempts_taken

          "You have #{attempts_remaining} attempt#{plural(attempts_remaining)} remaining out of #{max_attempts} total attempt#{plural(max_attempts)}."
      end

    assign(socket,
      page_context: %{page_context | historical_attempts: resource_attempts},
      allow_attempt?: new_attempt_allowed == {:allowed},
      attempt_message: attempt_message,
      view: :prologue,
      show_blocking_gates?: blocking_gates != []
    )
  end

  defp format_datetime_fn(ctx) do
    fn datetime ->
      FormatDateTime.date(datetime, ctx: ctx, precision: :minutes)
    end
  end

  _docp = """
  In case there is a request path we add that path in the page content as 'backUrl'.
  This backUrl aims to return the student to the page they were on
  before they accessed the page we are building (i.e. the "Learn", "Home" or "Schedule" page)
  """

  defp build_page_content(content, nil), do: content
  defp build_page_content(content, request_path), do: Map.put(content, "backUrl", request_path)
end
