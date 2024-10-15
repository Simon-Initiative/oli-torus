defmodule OliWeb.PageDeliveryController do
  use OliWeb, :controller

  import OliWeb.Common.FormatDateTime

  require Logger

  alias Oli.Accounts
  alias Oli.Activities
  alias Oli.Delivery.Attempts.{Core, PageLifecycle}
  alias Oli.Delivery.Page.{PageContext, ObjectivesRollup}
  alias Oli.Delivery.{Paywall, PreviousNextIndex, Sections, Settings}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Paywall.Discount
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias Oli.Grading
  alias Oli.PartComponents
  alias Oli.Rendering.{Context, Page}
  alias Oli.Rendering.Activity.ActivitySummary
  alias Oli.Utils.{BibUtils, Slug, Time}
  alias Oli.Resources
  alias Oli.Resources.{PageContent, Revision}
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Metrics
  alias OliWeb.Components.Delivery.AdaptiveIFrame
  alias OliWeb.PageDeliveryView

  plug(Oli.Plugs.AuthorizeSection when action in [:export_enrollments, :export_gradebook])

  def index(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user
    section = conn.assigns.section

    context = conn.assigns[:ctx]

    if Sections.is_enrolled?(user.id, section_slug) do
      case section
           |> Oli.Repo.preload([:base_project, :root_section_resource]) do
        nil ->
          render(conn, "error.html")

        section ->
          user_roles = Sections.get_user_roles(user, section_slug)

          if user_roles.is_instructor? do
            conn
            |> redirect(
              to:
                Routes.live_path(
                  OliWeb.Endpoint,
                  OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
                  section_slug,
                  :manage
                )
            )
          else
            revision = DeliveryResolver.root_container(section_slug)

            effective_settings = Settings.get_combined_settings(revision, section.id, user.id)

            next_activities =
              Sections.get_next_activities_for_student(section_slug, user.id, context)
              |> Enum.map(fn sr ->
                case sr.scheduling_type do
                  :read_by -> Map.put(sr, :scheduling_type, "Read by")
                  :due_by -> Map.put(sr, :scheduling_type, "Due by")
                  :inclass_activity -> Map.put(sr, :scheduling_type, "Class activity")
                end
              end)

            render(conn, "index.html",
              title: section.title,
              description: section.description,
              section_slug: section_slug,
              hierarchy: Sections.build_hierarchy(section),
              display_curriculum_item_numbering: section.display_curriculum_item_numbering,
              preview_mode: false,
              page_link_url: &Routes.page_delivery_path(conn, :page, section_slug, &1),
              container_link_url: &Routes.page_delivery_path(conn, :container, section_slug, &1),
              collab_space_config: effective_settings.collab_space_config,
              revision_slug: revision.slug,
              is_instructor: user_roles.is_instructor?,
              is_student: user_roles.is_student?,
              progress: learner_progress(section.id, user.id),
              next_activities: next_activities,
              independent_learner: user.independent_learner,
              current_user_id: user.id,
              latest_visited_page: Sections.get_latest_visited_page(section_slug, user.id),
              scheduled_dates:
                Sections.get_resources_scheduled_dates_for_student(section_slug, user.id),
              context: context
            )
          end
      end
    else
      case section do
        %Section{open_and_free: true, requires_enrollment: false} ->
          conn
          |> redirect(to: Routes.delivery_path(conn, :show_enroll, section_slug))

        _ ->
          render(conn, "not_authorized.html")
      end
    end
  end

  defp learner_progress(section_id, user_id) do
    (Metrics.progress_for(section_id, user_id) * 100)
    |> round()
    # if there is any progress at all, we want to represent that by at least showing 1% min
    |> max(1)
    # ensure we never show progress above 100%
    |> min(100)
  end

  def exploration(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user
    section = conn.assigns.section

    if Sections.is_enrolled?(user.id, section_slug) do
      case section
           |> Oli.Repo.preload([:base_project, :root_section_resource]) do
        nil ->
          render(conn, "error.html")

        section ->
          render(conn, "exploration.html",
            title: section.title,
            description: section.description,
            section_slug: section_slug,
            hierarchy: Sections.build_hierarchy(section),
            display_curriculum_item_numbering: section.display_curriculum_item_numbering,
            preview_mode: false,
            page_link_url: &Routes.page_delivery_path(conn, :page, section_slug, &1),
            container_link_url: &Routes.page_delivery_path(conn, :container, section_slug, &1)
          )
      end
    else
      case section do
        %Section{open_and_free: true, requires_enrollment: false} ->
          conn
          |> redirect(to: Routes.delivery_path(conn, :show_enroll, section_slug))

        _ ->
          render(conn, "not_authorized.html")
      end
    end
  end

  def deliberate_practice(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user
    section = conn.assigns.section

    if Sections.is_enrolled?(user.id, section_slug) do
      case section
           |> Oli.Repo.preload([:base_project, :root_section_resource]) do
        nil ->
          render(conn, "error.html")

        section ->
          render(conn, "deliberate_practice.html",
            title: section.title,
            description: section.description,
            section_slug: section_slug,
            hierarchy: Sections.build_hierarchy(section),
            display_curriculum_item_numbering: section.display_curriculum_item_numbering,
            preview_mode: false,
            page_link_url: &Routes.page_delivery_path(conn, :page, section_slug, &1),
            container_link_url: &Routes.page_delivery_path(conn, :container, section_slug, &1)
          )
      end
    else
      case section do
        %Section{open_and_free: true, requires_enrollment: false} ->
          conn
          |> redirect(to: Routes.delivery_path(conn, :show_enroll, section_slug))

        _ ->
          render(conn, "not_authorized.html")
      end
    end
  end

  def assignments(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user
    section = conn.assigns.section

    if Sections.is_enrolled?(user.id, section_slug) do
      assignments = Sections.get_graded_pages(section_slug, user.id)

      render(
        conn,
        "assignments.html",
        title: section.title,
        assignments: assignments,
        section_slug: section_slug,
        preview_mode: false,
        format_datetime_fn: format_datetime_fn(conn)
      )
    else
      case section do
        %Section{open_and_free: true, requires_enrollment: false} ->
          conn
          |> redirect(to: Routes.delivery_path(conn, :show_enroll, section_slug))

        _ ->
          render(conn, "not_authorized.html")
      end
    end
  end

  def discussion(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user
    section = conn.assigns.section

    if Sections.is_enrolled?(user.id, section_slug) do
      case section
           |> Oli.Repo.preload([:base_project, :root_section_resource]) do
        nil ->
          render(conn, "error.html")

        section ->
          render(conn, "discussion.html",
            title: section.title,
            description: section.description,
            section_id: section.id,
            section_slug: section_slug,
            hierarchy: Sections.build_hierarchy(section),
            display_curriculum_item_numbering: section.display_curriculum_item_numbering,
            preview_mode: false,
            page_link_url: &Routes.page_delivery_path(conn, :page, section_slug, &1),
            container_link_url: &Routes.page_delivery_path(conn, :container, section_slug, &1),
            user: user
          )
      end
    else
      case section do
        %Section{open_and_free: true, requires_enrollment: false} ->
          conn
          |> redirect(to: Routes.delivery_path(conn, :show_enroll, section_slug))

        _ ->
          render(conn, "not_authorized.html")
      end
    end
  end

  def container(conn, %{"section_slug" => section_slug, "revision_slug" => revision_slug}) do
    user = conn.assigns.current_user
    author = conn.assigns.current_author
    section = conn.assigns.section

    if Accounts.at_least_content_admin?(author) or Sections.is_enrolled?(user.id, section_slug) do
      container_type_id = Oli.Resources.ResourceType.id_for_container()
      page_type_id = Oli.Resources.ResourceType.id_for_page()

      preview_mode = Map.get(conn.assigns, :preview_mode, false)

      conn =
        conn
        |> put_root_layout(html: {OliWeb.LayoutView, :delivery})
        |> put_layout(html: {OliWeb.Layouts, :page})

      {page_link_url, container_link_url} =
        if preview_mode do
          {&Routes.page_delivery_path(conn, :page_preview, section_slug, &1),
           &Routes.page_delivery_path(conn, :container_preview, section_slug, &1)}
        else
          {&Routes.page_delivery_path(conn, :page, section_slug, &1),
           &Routes.page_delivery_path(conn, :container, section_slug, &1)}
        end

      case Resolver.from_revision_slug(section_slug, revision_slug) do
        nil ->
          render(conn, "error.html")

        # Specifically handle the case that a page was visited with a "container" structured
        # link.  In this case, we redirect to the actual page route so that we can render it
        %Revision{resource_type_id: ^page_type_id} ->
          conn
          |> redirect(to: Routes.delivery_path(conn, :page, section_slug, revision_slug))

        # Render a container in the most efficient manner: A single resolver call for child
        # revisions based on retrieval of child data from the PreviousNextIndex cache
        %Revision{resource_type_id: ^container_type_id, title: title} = revision ->
          {:ok, {previous, next, current}, previous_next_index} =
            PreviousNextIndex.retrieve(section, revision.resource_id)

          section_resource = Sections.get_section_resource(section.id, revision.resource_id)

          numbered_revisions = Sections.get_revision_indexes(section.slug)

          render(conn, "container.html",
            user: user,
            scripts: [],
            section: section,
            title: title,
            children:
              simulate_children_nodes(current, previous_next_index, section.customizations),
            container: simulate_node(current, section.customizations),
            section_slug: section_slug,
            previous_page: previous,
            next_page: next,
            numbered_revisions: numbered_revisions,
            current_page: current,
            page_number: section_resource.numbering_index,
            preview_mode: preview_mode,
            page_link_url: page_link_url,
            container_link_url: container_link_url,
            active_page: nil,
            revision: revision,
            resource_slug: revision.slug,
            display_curriculum_item_numbering: section.display_curriculum_item_numbering,
            bib_app_params: %{
              bibReferences: []
            }
          )

        # Any attempt to render a valid revision that is not container or page gets an error
        _ ->
          render(conn, "error.html")
      end
    else
      case section do
        %Section{open_and_free: true, requires_enrollment: false} ->
          conn
          |> redirect(to: Routes.delivery_path(conn, :page, section_slug, revision_slug))

        _ ->
          render(conn, "not_authorized.html")
      end
    end
  end

  # Route to render adaptive pages in a full screen mode with no torus navigation.
  # Used within an iframe when the adaptive page is embedded in a torus page.
  def page_fullscreen(conn, %{"section_slug" => section_slug, "revision_slug" => revision_slug}) do
    user = conn.assigns.current_user
    section = conn.assigns.section
    datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)

    if Sections.is_enrolled?(user.id, section_slug) do
      PageContext.create_for_visit(section, revision_slug, user, datashop_session_id)
      |> render_adaptive_chromeless_page(conn, section_slug, false)
    else
      render(conn, "not_authorized.html")
    end
  end

  def page(conn, %{"section_slug" => section_slug, "revision_slug" => revision_slug}) do
    # redirect request to old page view to the new lesson live view
    conn
    |> redirect(to: ~p"/sections/#{section_slug}/lesson/#{revision_slug}")
  end

  def render_content_html(
        %{section_slug: section_slug},
        %{"displayApplicationChrome" => true, "advancedDelivery" => true} = content,
        page_slug
      ) do
    # Render the internal page iframe for adaptive delivery within the torus navigation
    AdaptiveIFrame.delivery(section_slug, page_slug, content)
  end

  def render_content_html(render_context, content, _page_slug) do
    # Render a basic page content.  This is the default for all pages that do not have
    # displayApplicationChrome set to true
    Page.render(render_context, content, Page.Html)
  end

  def render_content_text(render_context, content, _page_slug) do
    # Render a basic page content.

    Page.render(render_context, content, Page.Markdown) |> :erlang.iolist_to_binary()
  end

  # Matches a not-started page that displays the "start attempt" button
  defp render_page(
         %PageContext{
           progress_state: :not_started,
           page: page,
           user: user,
           resource_attempts: resource_attempts,
           effective_settings: effective_settings
         } = context,
         conn,
         section_slug,
         _preview_mode
       ) do
    section = conn.assigns.section

    # Only consider graded attempts
    resource_attempts = Enum.filter(resource_attempts, fn a -> a.revision.graded == true end)
    attempts_taken = length(resource_attempts)

    preview_mode = Map.get(conn.assigns, :preview_mode, false)

    # The Oli.Plugs.MaybeGatedResource plug sets the blocking_gates assign if there is a blocking
    # gate that prevents this learning from starting another attempt of this resource
    blocking_gates = Map.get(conn.assigns, :blocking_gates, [])

    new_attempt_allowed =
      Settings.new_attempt_allowed(
        effective_settings,
        attempts_taken,
        blocking_gates
      )

    allow_attempt? = new_attempt_allowed == {:allowed}

    message =
      case new_attempt_allowed do
        {:blocking_gates} ->
          Oli.Delivery.Gating.details(blocking_gates, format_datetime: format_datetime_fn(conn))

        {:no_attempts_remaining} ->
          "You have no attempts remaining out of #{effective_settings.max_attempts} total attempt#{plural(effective_settings.max_attempts)}."

        {:before_start_date} ->
          before_start_date_message(conn, effective_settings)

        {:end_date_passed} ->
          "The deadline for this assignment has passed."

        {:allowed} ->
          if effective_settings.max_attempts == 0 do
            "You can take this scored page an unlimited number of times"
          else
            attempts_remaining = effective_settings.max_attempts - attempts_taken

            "You have #{attempts_remaining} attempt#{plural(attempts_remaining)} remaining out of #{effective_settings.max_attempts} total attempt#{plural(effective_settings.max_attempts)}."
          end
      end

    conn =
      conn
      |> put_root_layout(html: {OliWeb.LayoutView, :delivery})
      |> put_layout(html: {OliWeb.Layouts, :page})

    resource_attempts =
      Enum.filter(resource_attempts, fn r -> r.date_submitted != nil end)
      |> Enum.sort(fn r1, r2 ->
        DateTime.before?(r1.date_submitted, r2.date_submitted)
      end)

    {:ok, {previous, next, current}, _} = PreviousNextIndex.retrieve(section, page.resource_id)

    resource_access = Core.get_resource_access(page.resource_id, section.slug, user.id)

    section_resource = Sections.get_section_resource(section.id, page.resource_id)

    numbered_revisions = Sections.get_revision_indexes(section.slug)

    render(conn, "prologue.html", %{
      license: context.license,
      user: user,
      resource_access: resource_access,
      section_slug: section_slug,
      scripts: Activities.get_activity_scripts(),
      preview_mode: preview_mode,
      resource_attempts: resource_attempts,
      previous_page: previous,
      next_page: next,
      numbered_revisions: numbered_revisions,
      current_page: current,
      page_number: section_resource.numbering_index,
      title: context.page.title,
      allow_attempt?: allow_attempt?,
      message: message,
      resource_id: page.resource_id,
      slug: context.page.slug,
      max_attempts: effective_settings.max_attempts,
      effective_settings: effective_settings,
      requires_password?:
        effective_settings.password != nil and effective_settings.password != "",
      section: section,
      page_link_url: &Routes.page_delivery_path(conn, :page, section_slug, &1),
      container_link_url: &Routes.page_delivery_path(conn, :container, section_slug, &1),
      revision: context.page,
      resource_slug: context.page.slug,
      bib_app_params: %{
        bibReferences: context.bib_revisions
      }
    })
  end

  # Handles the 2 cases of adaptive delivery
  #  1. A fullscreen chromeless version
  #  2. A version inside the torus navigation with an iframe pointing to #1
  defp render_page(
         %PageContext{
           page: %{
             content:
               %{
                 "advancedDelivery" => true
               } = content
           }
         } = context,
         conn,
         section_slug,
         preview_mode
       ) do
    case Map.get(content, "displayApplicationChrome", false) do
      false ->
        render_adaptive_chromeless_page(context, conn, section_slug, preview_mode)

      _ ->
        render_page_body(context, conn, section_slug)
    end
  end

  defp render_page(
         %PageContext{progress_state: :error},
         conn,
         _section_slug,
         _preview_mode
       ) do
    render(conn, "error.html")
  end

  # This case handles :in_progress and :revised progress states, in addition to
  # handling ungraded pages and review mode
  defp render_page(
         context,
         conn,
         section_slug,
         _preview_mode
       ) do
    render_page_body(context, conn, section_slug)
  end

  # This renders the page with navigation and the content inside it. The content might be either
  # core torus content or an iframe pointing to adaptive content which is determined in render_content_html
  def render_page_body(
        %PageContext{
          user: user,
          effective_settings: effective_settings,
          page: %{content: content}
        } = context,
        conn,
        section_slug
      ) do
    section = conn.assigns.section

    section_resource = Sections.get_section_resource(section.id, context.page.resource_id)

    preview_mode = Map.get(conn.assigns, :preview_mode, false)

    base_project_attributes = Sections.get_section_attributes(section)

    submitted_surveys =
      PageContent.survey_activities(hd(context.resource_attempts).content)
      |> Enum.reduce(%{}, fn {survey_id, activity_ids}, acc ->
        survey_state =
          Enum.all?(activity_ids, fn id ->
            context.activities[id].lifecycle_state === :submitted ||
              context.activities[id].lifecycle_state === :evaluated
          end)

        Map.put(acc, survey_id, survey_state)
      end)

    base_project_slug =
      case section.has_experiments do
        true ->
          Oli.Repo.get(Oli.Authoring.Course.Project, section.base_project_id).slug

        _ ->
          nil
      end

    enrollment =
      case section.has_experiments do
        true -> Oli.Delivery.Sections.get_enrollment(section_slug, user.id)
        _ -> nil
      end

    render_context = %Context{
      # Allow admin authors to review student work
      enrollment: enrollment,
      user:
        if is_nil(user) do
          conn.assigns.current_author
        else
          user
        end,
      section_slug: section_slug,
      project_slug: base_project_slug,
      resource_attempt: hd(context.resource_attempts),
      mode:
        if context.review_mode do
          :review
        else
          :delivery
        end,
      activity_map: context.activities,
      resource_summary_fn: &Resources.resource_summary(&1, section_slug, Resolver),
      alternatives_groups_fn: fn -> Resources.alternatives_groups(section_slug, Resolver) end,
      alternatives_selector_fn: &Resources.Alternatives.select/2,
      extrinsic_read_section_fn: &Oli.Delivery.ExtrinsicState.read_section/3,
      bib_app_params: context.bib_revisions,
      submitted_surveys: submitted_surveys,
      historical_attempts: context.historical_attempts,
      learning_language: base_project_attributes.learning_language,
      effective_settings: effective_settings
    }

    this_attempt = context.resource_attempts |> hd

    attempt_content =
      if Enum.any?(this_attempt.errors, fn e ->
           e == "Selection failed to fulfill: no values provided for expression"
         end) and context.is_student do
        %{"model" => []}
      else
        this_attempt.content
      end

    html = render_content_html(render_context, attempt_content, context.page.slug)

    # Cache the page as text to allow the AI agent LV to access it.
    page_as_text = render_content_text(render_context, attempt_content, context.page.slug)
    Oli.Converstation.PageContentCache.put(context.page.id, page_as_text)

    conn =
      conn
      |> put_root_layout(html: {OliWeb.LayoutView, :delivery})
      |> put_layout(html: {OliWeb.Layouts, :page})

    all_activities = Activities.list_activity_registrations()

    {:ok, {previous, next, current}, _} =
      PreviousNextIndex.retrieve(section, context.page.resource_id)

    resource_attempt = hd(context.resource_attempts)

    adaptive = Map.get(content, "advancedDelivery", false)

    numbered_revisions = Sections.get_revision_indexes(section.slug)

    # For testing, you can uncomment to introduce a time out
    # effective_settings = %{effective_settings | time_limit: 2, late_submit: :disallow}

    render(
      conn,
      "page.html",
      %{
        license: context.license,
        user: user,
        adaptive: adaptive,
        context: context,
        page: context.page,
        review_mode: context.review_mode,
        progress_state: context.progress_state,
        section_slug: section_slug,
        scripts: Enum.map(all_activities, fn a -> a.delivery_script end),
        preview_mode: preview_mode,
        activity_type_slug_mapping:
          Enum.reduce(all_activities, %{}, fn a, m -> Map.put(m, a.id, a.slug) end),
        previous_page: previous,
        next_page: next,
        numbered_revisions: numbered_revisions,
        current_page: current,
        page_number: section_resource.numbering_index,
        title: context.page.title,
        graded: context.page.graded,
        activity_count: map_size(context.activities),
        html: html,
        objectives: context.objectives,
        slug: context.page.slug,
        resource_attempt: resource_attempt,
        attempt_guid: resource_attempt.attempt_guid,
        latest_attempts: context.latest_attempts,
        section: section,
        children: context.page.children,
        show_feedback: Settings.show_feedback?(effective_settings),
        page_link_url: &Routes.page_delivery_path(conn, :page, section_slug, &1),
        container_link_url: &Routes.page_delivery_path(conn, :container, section_slug, &1),
        revision: context.page,
        resource_slug: context.page.slug,
        bib_app_params: %{
          bibReferences: context.bib_revisions
        },
        collab_space_config: effective_settings.collab_space_config,
        is_instructor: context.is_instructor,
        is_student: context.is_student,
        scheduling_type: section_resource.scheduling_type,
        time_limit: effective_settings.time_limit,
        attempt_start_time: resource_attempt.inserted_at |> to_epoch,
        effective_end_time:
          Settings.determine_effective_deadline(resource_attempt, effective_settings)
          |> to_epoch,
        end_date: effective_settings.end_date,
        auto_submit: effective_settings.late_submit == :disallow,
        # TODO: implement reading time estimation
        est_reading_time: nil
      }
    )
  end

  # Renders an adaptive page fullscreen with no torus nav around it.
  #   Used in adaptive delivery full screen mode and when displayApplicationChrome is true
  #   inside an iframe.
  defp render_adaptive_chromeless_page(
         context,
         conn,
         section_slug,
         preview_mode
       ) do
    section = conn.assigns.section

    layout = "chromeless.html"

    conn = put_root_layout(conn, {OliWeb.LayoutView, layout})

    resource_attempt = Enum.at(context.resource_attempts, 0)

    {:ok, {previous, next, current}, _} =
      PreviousNextIndex.retrieve(section, context.page.resource_id)

    previous_url = url_from_desc(conn, section_slug, previous)
    next_url = url_from_desc(conn, section_slug, next)

    activity_types = Activities.activities_for_section()

    section_resource = Sections.get_section_resource(section.id, context.page.resource_id)

    numbered_revisions = Sections.get_revision_indexes(section.slug)

    render(conn, "advanced_delivery.html", %{
      app_params: %{
        activityTypes: activity_types,
        resourceId: context.page.resource_id,
        sectionSlug: section_slug,
        userId: context.user.id,
        userName: context.user.name,
        pageTitle: context.page.title,
        pageSlug: context.page.slug,
        graded: context.page.graded,
        content: build_page_content(context.page.content, conn.params["request_path"]),
        resourceAttemptState: resource_attempt.state,
        resourceAttemptGuid: resource_attempt.attempt_guid,
        currentServerTime: DateTime.utc_now() |> to_epoch,
        effectiveEndTime:
          Settings.determine_effective_deadline(
            resource_attempt,
            context.effective_settings
          )
          |> to_epoch,
        lateSubmit: context.effective_settings.late_submit,
        activityGuidMapping: context.activities,
        signoutUrl: ~p"/users/log_out",
        previousPageURL: previous_url,
        nextPageURL: next_url,
        previewMode: preview_mode,
        isInstructor: true,
        reviewMode: context.review_mode,
        overviewURL: ~p"/sections/#{section_slug}",
        finalizeGradedURL:
          Routes.page_lifecycle_path(
            conn,
            :transition
          ),
        screenIdleTimeOutInSeconds:
          String.to_integer(System.get_env("SCREEN_IDLE_TIMEOUT_IN_SECONDS", "1800"))
      },
      bib_app_params: %{
        bibReferences: context.bib_revisions
      },
      activity_type_slug_mapping: %{},
      activity_types: activity_types,
      additional_stylesheets: Map.get(context.page.content, "additionalStylesheets", []),
      graded: context.page.graded,
      latest_attempts: %{},
      next_page: next,
      current_page: current,
      numbered_revisions: numbered_revisions,
      page_number: section_resource.numbering_level,
      user_id: context.user.id,
      next_url: next_url,
      part_scripts: PartComponents.get_part_component_scripts(:delivery_script),
      preview_mode: preview_mode,
      previous_url: previous_url,
      previous_page: previous,
      resource_attempt_guid: resource_attempt.attempt_guid,
      resource_id: context.page.resource_id,
      section: section,
      page_link_url: &Routes.page_delivery_path(conn, :page, section_slug, &1),
      container_link_url: &Routes.page_delivery_path(conn, :container, section_slug, &1),
      revision: context.page,
      resource_slug: context.page.slug,
      section_slug: section_slug,
      slug: context.page.slug,
      scripts: Activities.get_activity_scripts(:delivery_script),
      title: context.page.title
    })
  end

  _docp = """
  In case there is a request path we add that path in the page content as 'backUrl'.
  This backUrl aims to return the student to the page they were on
  before they accessed the page we are building (i.e. the "Learn", "Home" or "Schedule" page)
  """

  defp build_page_content(content, nil), do: content
  defp build_page_content(content, request_path), do: Map.put(content, "backUrl", request_path)

  defp to_epoch(nil), do: nil

  defp to_epoch(date_time) do
    date_time
    |> DateTime.to_unix(:second)
    |> Kernel.*(1000)
  end

  # ----------------------------------------------------------
  # PREVIEW

  def index_preview(conn, %{"section_slug" => section_slug}) do
    current_user = conn.assigns.current_author || conn.assigns.current_user

    section =
      conn.assigns.section
      |> Oli.Repo.preload([:base_project, :root_section_resource])

    revision = DeliveryResolver.root_container(section_slug)

    effective_settings =
      Settings.get_combined_settings(
        revision,
        section.id,
        current_user.id
      )

    render(conn, "index.html",
      title: section.title,
      description: section.description,
      section_slug: section_slug,
      hierarchy: Sections.build_hierarchy(section),
      display_curriculum_item_numbering: section.display_curriculum_item_numbering,
      preview_mode: true,
      page_link_url: &Routes.page_delivery_path(conn, :page_preview, section_slug, &1),
      container_link_url: &Routes.page_delivery_path(conn, :container_preview, section_slug, &1),
      independent_learner: true,
      collab_space_config: effective_settings.collab_space_config,
      revision_slug: revision.slug,
      is_instructor: false,
      is_student: false,
      current_user_id: current_user.id,
      latest_visited_page: Sections.get_latest_visited_page(section_slug, current_user.id),
      scheduled_dates:
        Sections.get_resources_scheduled_dates_for_student(section_slug, current_user.id),
      context: conn.assigns[:ctx]
    )
  end

  def exploration_preview(conn, %{"section_slug" => section_slug}) do
    section =
      conn.assigns.section
      |> Oli.Repo.preload([:base_project, :root_section_resource])

    render(conn, "exploration.html",
      title: section.title,
      description: section.description,
      section_slug: section_slug,
      hierarchy: Sections.build_hierarchy(section),
      display_curriculum_item_numbering: section.display_curriculum_item_numbering,
      preview_mode: true,
      page_link_url: &Routes.page_delivery_path(conn, :page, section_slug, &1),
      container_link_url: &Routes.page_delivery_path(conn, :container, section_slug, &1)
    )
  end

  def deliberate_practice_preview(conn, %{"section_slug" => section_slug}) do
    section =
      conn.assigns.section
      |> Oli.Repo.preload([:base_project, :root_section_resource])

    render(conn, "deliberate_practice.html",
      title: section.title,
      description: section.description,
      section_slug: section_slug,
      hierarchy: Sections.build_hierarchy(section),
      display_curriculum_item_numbering: section.display_curriculum_item_numbering,
      preview_mode: true,
      page_link_url: &Routes.page_delivery_path(conn, :page, section_slug, &1),
      container_link_url: &Routes.page_delivery_path(conn, :container, section_slug, &1)
    )
  end

  def discussion_preview(conn, %{"section_slug" => section_slug}) do
    section =
      conn.assigns.section
      |> Oli.Repo.preload([:base_project, :root_section_resource])

    render(conn, "discussion.html",
      title: section.title,
      description: section.description,
      section_id: section.id,
      section_slug: section_slug,
      hierarchy: Sections.build_hierarchy(section),
      display_curriculum_item_numbering: section.display_curriculum_item_numbering,
      preview_mode: true,
      page_link_url: &Routes.page_delivery_path(conn, :page, section_slug, &1),
      container_link_url: &Routes.page_delivery_path(conn, :container, section_slug, &1),
      user: conn.assigns.current_user || conn.assigns.current_author
    )
  end

  def assignments_preview(conn, %{"section_slug" => section_slug}) do
    section = conn.assigns.section
    user = conn.assigns.current_user || conn.assigns.current_author

    render(
      conn,
      "assignments.html",
      title: section.title,
      assignments: Sections.get_graded_pages(section_slug, user.id),
      section_slug: section_slug,
      preview_mode: true,
      format_datetime_fn: format_datetime_fn(conn)
    )
  end

  def container_preview(conn, %{"section_slug" => section_slug, "revision_slug" => revision_slug}) do
    conn
    |> assign(:preview_mode, true)
    |> container(%{"section_slug" => section_slug, "revision_slug" => revision_slug})
  end

  def page_preview(
        conn,
        %{
          "section_slug" => section_slug,
          "revision_slug" => revision_slug
        }
      ) do
    case Resolver.from_revision_slug(section_slug, revision_slug) do
      %{content: %{"advancedDelivery" => true}} = revision ->
        case conn.assigns.current_user do
          nil ->
            # instructor preview and user is nil, simply render a "preview unsupported" message for now
            section = conn.assigns.section

            {:ok, {previous, next, current}, _} =
              PreviousNextIndex.retrieve(section, revision.resource_id)

            html =
              ~s|<div class="text-center"><em>Instructor preview of adaptive activities by admin accounts is not supported</em></div>|

            effective_settings =
              Settings.get_combined_settings(
                revision,
                section.id
              )

            numbered_revisions = Sections.get_revision_indexes(section.slug)

            conn
            |> put_root_layout({OliWeb.LayoutView, :delivery})
            |> put_layout(html: {OliWeb.Layouts, :page})
            |> render(
              "instructor_page_preview.html",
              %{
                user: nil,
                summary: %{title: section.title},
                section_slug: section_slug,
                scripts: [],
                preview_mode: true,
                previous_page: previous,
                next_page: next,
                page_number: 1,
                graded: false,
                review_mode: false,
                numbered_revisions: numbered_revisions,
                current_page: current,
                title: revision.title,
                html: html,
                objectives: [],
                section: section,
                revision: revision,
                page_link_url: &Routes.page_delivery_path(conn, :page_preview, section_slug, &1),
                container_link_url:
                  &Routes.page_delivery_path(conn, :container_preview, section_slug, &1),
                resource_slug: revision.slug,
                display_curriculum_item_numbering: section.display_curriculum_item_numbering,
                bib_app_params: %{
                  bibReferences: []
                },
                collab_space_config: effective_settings.collab_space_config,
                is_instructor: true,
                is_student: false
              }
            )

          user ->
            activity_types = Activities.activities_for_section()

            conn
            |> put_root_layout({OliWeb.LayoutView, "chromeless.html"})
            |> put_view(OliWeb.ResourceView)
            |> render("advanced_page_preview.html",
              user: user,
              additional_stylesheets: Map.get(revision.content, "additionalStylesheets", []),
              activity_types: activity_types,
              scripts: Activities.get_activity_scripts(:delivery_script),
              part_scripts: PartComponents.get_part_component_scripts(:delivery_script),
              user: user,
              project_slug: section_slug,
              title: revision.title,
              preview_mode: true,
              display_curriculum_item_numbering: true,
              app_params: %{
                activityTypes: activity_types,
                resourceId: revision.resource_id,
                sectionSlug: section_slug,
                userId: user.id,
                pageSlug: revision.slug,
                pageTitle: revision.title,
                content: revision.content,
                graded: revision.graded,
                resourceAttemptState: nil,
                resourceAttemptGuid: nil,
                activityGuidMapping: nil,
                previousPageURL: nil,
                nextPageURL: nil,
                previewMode: true,
                isInstructor: true
              }
            )
        end

      revision ->
        render_page_preview(conn, section_slug, revision)
    end
  end

  defp render_page_preview(conn, section_slug, revision) do
    section = conn.assigns.section

    {:ok, {previous, next, current}, _} =
      PreviousNextIndex.retrieve(section, revision.resource_id)

    type_by_id =
      Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn e, m -> Map.put(m, e.id, e) end)

    activity_ids =
      revision.content
      |> Oli.Resources.PageContent.flat_filter(fn item ->
        item["type"] == "activity-reference"
      end)
      |> Enum.map(fn %{"activity_id" => id} -> id end)

    activity_revisions = Resolver.from_resource_id(section_slug, activity_ids)

    activity_map =
      activity_revisions
      |> Enum.map(fn rev ->
        type = Map.get(type_by_id, rev.activity_type_id)

        %ActivitySummary{
          id: rev.resource_id,
          script: type.authoring_script,
          attempt_guid: nil,
          state: nil,
          lifecycle_state: :active,
          model: Jason.encode!(rev.content) |> Oli.Delivery.Page.ActivityContext.encode(),
          delivery_element: type.delivery_element,
          authoring_element: type.authoring_element,
          graded: revision.graded,
          bib_refs: Map.get(rev.content, "bibrefs", [])
        }
      end)
      |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.id, r) end)

    all_activities = Activities.list_activity_registrations()

    summaries = if activity_map != nil, do: Map.values(activity_map), else: []

    bib_entrys =
      revision.content
      |> BibUtils.assemble_bib_entries(
        summaries,
        fn r -> Map.get(r, :bib_refs, []) end,
        section_slug,
        Resolver
      )
      |> Enum.with_index(1)
      |> Enum.map(fn {summary, ordinal} -> BibUtils.serialize_revision(summary, ordinal) end)

    base_project_attributes = Sections.get_section_attributes(section)

    render_context = %Context{
      user: conn.assigns.current_user,
      section_slug: section_slug,
      revision_slug: revision.slug,
      mode: :instructor_preview,
      activity_map: activity_map,
      resource_summary_fn: &Resources.resource_summary(&1, section_slug, Resolver),
      alternatives_selector_fn: &Resources.Alternatives.select/2,
      extrinsic_read_section_fn: &Oli.Delivery.ExtrinsicState.read_section/3,
      activity_types_map: Enum.reduce(all_activities, %{}, fn a, m -> Map.put(m, a.id, a) end),
      bib_app_params: bib_entrys,
      learning_language: base_project_attributes.learning_language,
      submitted_surveys: %{}
    }

    html = Page.render(render_context, revision.content, Page.Html)

    effective_settings =
      case conn.assigns.current_user do
        nil -> Settings.get_combined_settings(revision, section.id)
        user -> Settings.get_combined_settings(revision, section.id, user.id)
      end

    section_resource = Sections.get_section_resource(section.id, revision.resource_id)

    numbered_revisions = Sections.get_revision_indexes(section.slug)

    objectives =
      ObjectivesRollup.rollup_objectives(revision, activity_revisions, Resolver, section_slug)

    conn
    |> put_root_layout(html: {OliWeb.LayoutView, :delivery})
    |> put_layout(html: {OliWeb.Layouts, :page})
    |> render(
      "instructor_page_preview.html",
      %{
        user:
          if is_nil(conn.assigns.current_user) do
            nil
          else
            conn.assigns.current_user
          end,
        summary: %{title: section.title},
        section_slug: section_slug,
        scripts: Enum.map(all_activities, fn a -> a.authoring_script end),
        preview_mode: true,
        previous_page: previous,
        next_page: next,
        numbered_revisions: numbered_revisions,
        current_page: current,
        page_number: section_resource.numbering_index,
        title: revision.title,
        graded: revision.graded,
        review_mode: false,
        html: html,
        objectives: objectives,
        section: section,
        revision: revision,
        page_link_url: &Routes.page_delivery_path(conn, :page_preview, section_slug, &1),
        container_link_url:
          &Routes.page_delivery_path(conn, :container_preview, section_slug, &1),
        resource_slug: revision.slug,
        display_curriculum_item_numbering: section.display_curriculum_item_numbering,
        bib_app_params: %{
          bibReferences: bib_entrys
        },
        collab_space_config: effective_settings.collab_space_config,
        is_instructor: true,
        is_student: false
      }
    )
  end

  # ----------------------------------------------------------
  # END PREVIEW

  def start_attempt_protected(conn, params) do
    start_attempt(conn, params)
  end

  def start_attempt(conn, %{"section_slug" => section_slug, "revision_slug" => revision_slug}) do
    user = conn.assigns.current_user
    section = conn.assigns.section
    password = Map.get(conn.body_params, "password", nil)

    if Sections.is_enrolled?(user.id, section_slug) do
      revision = Resolver.from_revision_slug(section_slug, revision_slug)

      effective_settings = Settings.get_combined_settings(revision, section.id, user.id)

      case check_settings_before_attempt(conn, effective_settings, password) do
        :ok ->
          do_start_attempt(conn, section, user, revision, effective_settings)

        {:error, error_message} ->
          conn
          |> put_flash(:error, error_message)
          |> redirect(to: Routes.page_delivery_path(conn, :page, section.slug, revision.slug))
      end
    else
      render(conn, "not_authorized.html")
    end
  end

  defp check_settings_before_attempt(conn, effective_settings, received_password) do
    with {:allowed} <- Settings.check_password(effective_settings, received_password),
         {:allowed} <- Settings.check_start_date(effective_settings) do
      :ok
    else
      {:invalid_password} ->
        {:error, "Incorrect password"}

      {:empty_password} ->
        {:error, "Empty password"}

      {:before_start_date} ->
        {:error, before_start_date_message(conn, effective_settings)}
    end
  end

  def do_start_attempt(conn, section, user, revision, effective_settings) do
    datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)
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
          {:ok, _} ->
            redirect(conn,
              to: Routes.page_delivery_path(conn, :page, section.slug, revision.slug)
            )

          {:error, {:end_date_passed}} ->
            redirect(conn,
              to: Routes.page_delivery_path(conn, :page, section.slug, revision.slug)
            )

          {:error, {:active_attempt_present}} ->
            redirect(conn,
              to: Routes.page_delivery_path(conn, :page, section.slug, revision.slug)
            )

          {:error, {:no_more_attempts}} ->
            redirect(conn,
              to: Routes.page_delivery_path(conn, :page, section.slug, revision.slug)
            )

          _ ->
            render(conn, "error.html")
        end

      _ ->
        # In the case where a gate exists we want to redirect to this page display, which will
        # then pick up the gate and show that feedback to the user
        redirect(conn, to: Routes.page_delivery_path(conn, :page, section.slug, revision.slug))
    end
  end

  def review_attempt(
        conn,
        %{
          "section_slug" => section_slug,
          "attempt_guid" => attempt_guid
        }
      ) do
    user = conn.assigns.current_user
    author = conn.assigns[:current_author]

    section = conn.assigns.section

    is_admin? = Accounts.at_least_content_admin?(author)

    if is_admin? or
         PageLifecycle.can_access_attempt?(attempt_guid, user, section) do
      page_context = PageContext.create_for_review(section_slug, attempt_guid, user, is_admin?)

      # enforce review_submission
      case {page_context.effective_settings.review_submission, page_context.is_instructor} do
        {_, true} -> render_page(page_context, conn, section_slug, false)
        {:allow, _} -> render_page(page_context, conn, section_slug, false)
        _ -> render(conn, "not_authorized.html")
      end
    else
      render(conn, "not_authorized.html")
    end
  end

  defp plural(num) do
    if num == 1 do
      ""
    else
      "s"
    end
  end

  def export_gradebook(conn, %{"section_slug" => section_slug}) do
    section = Sections.get_section_by(slug: section_slug)

    gradebook_csv = Grading.export_csv(section) |> Enum.join("")

    filename = "#{Slug.slugify(section.title)}-#{Timex.format!(Time.now(), "{YYYY}-{M}-{D}")}.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
    |> send_resp(200, gradebook_csv)
  end

  def export_enrollments(conn, %{"section_slug" => section_slug}) do
    section = Sections.get_section_by_slug(section_slug)

    enrollments_csv_text = build_enrollments_text(Sections.list_enrollments(section.slug))

    cost =
      case section do
        %Section{requires_payment: true, amount: amount} ->
          {:ok, m} = Money.to_string(amount)
          m

        _ ->
          "Free"
      end

    discount =
      case section do
        %Section{
          open_and_free: false,
          blueprint_id: blueprint_id,
          lti_1p3_deployment: lti_1p3_deployment
        } ->
          case Paywall.get_discount_by!(%{
                 section_id: blueprint_id,
                 institution_id: lti_1p3_deployment.institution.id
               }) do
            nil ->
              case Paywall.get_institution_wide_discount!(lti_1p3_deployment.institution.id) do
                nil -> "N/A"
                discount -> "By Institution: #{get_discount_string(discount)}"
              end

            discount ->
              "By Product-Institution: #{get_discount_string(discount)}"
          end

        _ ->
          "N/A"
      end

    csv_text = "Cost: #{cost}\r\nDiscount #{discount}\r\n\r\n" <> enrollments_csv_text

    filename =
      "Enrollments-#{Slug.slugify(section.title)}-#{Timex.format!(Time.now(), "{YYYY}-{M}-{D}")}.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
    |> send_resp(200, csv_text)
  end

  # This is for index based navigation between page
  def navigate_by_index(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user
    page_number = Map.get(conn.body_params, "page_number", nil) |> safe_to_integer()
    preview_mode = Map.get(conn.body_params, "preview_mode", "false") |> String.to_atom()

    if Sections.is_enrolled?(user.id, section_slug) do
      revision = Sections.get_revision_by_index(section_slug, page_number)

      case revision do
        nil ->
          case get_req_header(conn, "referer") do
            [] ->
              conn
              |> redirect(to: ~p"/sections/#{section_slug}")

            [origin_url] ->
              conn |> put_flash(:error, "Invalid page index") |> redirect(external: origin_url)
          end

        revision ->
          conn
          |> redirect(
            to:
              Routes.page_delivery_path(
                OliWeb.Endpoint,
                PageDeliveryView.action(preview_mode, revision),
                section_slug,
                revision.slug
              )
          )
      end
    else
      render(conn, "not_authorized.html")
    end
  end

  def navigate_by_index(conn, _) do
    render(conn, "not_authorized.html")
  end

  @spec safe_to_integer(String.t()) :: integer() | nil
  defp safe_to_integer(string) do
    case Integer.parse(string) do
      :error -> nil
      {integer, _} -> integer
    end
  end

  defp build_enrollments_text(enrollments) do
    ([["Student name", "Student email", "Enrolled on"]] ++
       Enum.map(enrollments, fn record ->
         [record.user.name, record.user.email, date(record.inserted_at)]
       end))
    |> CSV.encode()
    |> Enum.to_list()
    |> to_string()
  end

  defp get_discount_string(%Discount{type: :percentage, percentage: percentage}),
    do: "#{percentage}%"

  defp get_discount_string(%Discount{type: :fixed_amount, amount: amount}) do
    {:ok, m} = Money.to_string(amount)
    m
  end

  defp simulate_node(
         %{
           "level" => level_str,
           "index" => index_str,
           "title" => title,
           "id" => id_str,
           "type" => type,
           "graded" => graded,
           "slug" => slug
         },
         customizations
       ) do
    %Oli.Delivery.Hierarchy.HierarchyNode{
      uuid: UUID.uuid4(),
      numbering: %Oli.Resources.Numbering{
        level: String.to_integer(level_str),
        index: String.to_integer(index_str),
        labels: customizations
      },
      revision: %{
        slug: slug,
        title: title,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type(type),
        graded:
          if graded == "true" do
            true
          else
            false
          end
      },
      children: [],
      resource_id: String.to_integer(id_str)
    }
  end

  defp simulate_children_nodes(current, previous_next_index, customizations) do
    Enum.map(current["children"], fn s ->
      {:ok, {_, _, child}, _} =
        PreviousNextIndex.retrieve(previous_next_index, String.to_integer(s))

      child
    end)
    |> Enum.map(fn link_desc -> simulate_node(link_desc, customizations) end)
  end

  defp format_datetime_fn(conn) do
    fn datetime ->
      date(datetime, conn: conn, precision: :minutes)
    end
  end

  defp url_from_desc(_, _, nil), do: nil

  defp url_from_desc(conn, section_slug, %{"type" => "container", "slug" => slug}),
    do: Routes.page_delivery_path(conn, :container_preview, section_slug, slug)

  defp url_from_desc(conn, section_slug, %{"type" => "page", "slug" => slug}),
    do: Routes.page_delivery_path(conn, :page_preview, section_slug, slug)

  defp before_start_date_message(conn, effective_settings) do
    "This assessment is not yet available. It will be available on #{date(effective_settings.start_date, conn: conn, precision: :minutes)}."
  end
end
