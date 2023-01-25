defmodule OliWeb.PageDeliveryController do
  use OliWeb, :controller

  import OliWeb.Common.FormatDateTime

  require Logger

  alias Oli.Accounts
  alias Oli.Activities
  alias Oli.Delivery.Attempts.{Core, PageLifecycle}
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.{Paywall, PreviousNextIndex, Sections}
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Paywall.Discount
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias Oli.Grading
  alias Oli.PartComponents
  alias Oli.Rendering.{Context, Page}
  alias Oli.Rendering.Activity.ActivitySummary
  alias Oli.Utils.{BibUtils, Slug, Time}
  alias Oli.Resources
  alias Oli.Resources.{Collaboration, PageContent, Revision}

  plug(Oli.Plugs.AuthorizeSection when action in [:export_enrollments, :export_gradebook])

  def index(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user
    section = conn.assigns.section

    if Sections.is_enrolled?(user.id, section_slug) do
      case section
           |> Oli.Repo.preload([:base_project, :root_section_resource]) do
        nil ->
          render(conn, "error.html")

        section ->
          render(conn, "index.html",
            title: section.title,
            description: section.description,
            section_slug: section_slug,
            hierarchy: build_hierarchy(section),
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

  def schedule(conn, %{"section_slug" => section_slug}) do
    section =
      conn.assigns.section
      |> Oli.Repo.preload([:base_project, :root_section_resource])

    render(conn, "schedule.html",
      title: section.title,
      context: %{
        # TODO: Deliver these dates in the correct timezone for the section
        start_date: section.start_date,
        end_date: section.end_date,
        title: section.title,
        description: section.description,
        section_slug: section_slug,
        hierarchy: build_hierarchy(section),
        display_curriculum_item_numbering: section.display_curriculum_item_numbering
      }
    )
  end

  def container(conn, %{"section_slug" => section_slug, "revision_slug" => revision_slug}) do
    user = conn.assigns.current_user
    author = conn.assigns.current_author
    section = conn.assigns.section

    if Accounts.is_admin?(author) or Sections.is_enrolled?(user.id, section_slug) do
      container_type_id = Oli.Resources.ResourceType.get_id_by_type("container")
      page_type_id = Oli.Resources.ResourceType.get_id_by_type("page")

      preview_mode = Map.get(conn.assigns, :preview_mode, false)

      conn = put_root_layout(conn, {OliWeb.LayoutView, "page.html"})

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

          render(conn, "container.html",
            scripts: [],
            section: section,
            title: title,
            children: simulate_children_nodes(current, previous_next_index),
            container: simulate_node(current),
            section_slug: section_slug,
            previous_page: previous,
            next_page: next,
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

  def page(conn, %{"section_slug" => section_slug, "revision_slug" => revision_slug}) do
    user = conn.assigns.current_user
    section = conn.assigns.section
    datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)

    if Sections.is_enrolled?(user.id, section_slug) do
      PageContext.create_for_visit(section, revision_slug, user, datashop_session_id)
      |> render_page(conn, section_slug, false)
    else
      render(conn, "not_authorized.html")
    end
  end

  defp render_page(
         %PageContext{
           progress_state: :not_started,
           page: page,
           user: user,
           resource_attempts: resource_attempts
         } = context,
         conn,
         section_slug,
         _
       ) do
    section = conn.assigns.section

    # Only consider graded attempts
    resource_attempts = Enum.filter(resource_attempts, fn a -> a.revision.graded == true end)

    attempts_taken = length(resource_attempts)

    preview_mode = Map.get(conn.assigns, :preview_mode, false)

    # The call to "max" here accounts for the possibility that a publication could reduce the
    # number of attempts after a student has exhausted all attempts
    attempts_remaining = max(page.max_attempts - attempts_taken, 0)

    # The Oli.Plugs.MaybeGatedResource plug sets the blocking_gates assign if there is a blocking
    # gate that prevents this learning from starting another attempt of this resource
    blocking_gates = Map.get(conn.assigns, :blocking_gates, [])
    allow_attempt? = (attempts_remaining > 0 or page.max_attempts == 0) and blocking_gates == []

    message =
      cond do
        blocking_gates != [] ->
          Oli.Delivery.Gating.details(blocking_gates,
            format_datetime: format_datetime_fn(conn)
          )

        page.max_attempts == 0 ->
          "You can take this scored page an unlimited number of times"

        true ->
          "You have #{attempts_remaining} attempt#{plural(attempts_remaining)} remaining out of #{page.max_attempts} total attempt#{plural(page.max_attempts)}."
      end

    conn = put_root_layout(conn, {OliWeb.LayoutView, "page.html"})

    resource_attempts =
      Enum.filter(resource_attempts, fn r -> r.date_submitted != nil end)
      |> Enum.sort(fn r1, r2 ->
        r1.date_submitted <= r2.date_submitted
      end)

    {:ok, {previous, next, current}, _} = PreviousNextIndex.retrieve(section, page.resource_id)

    resource_access = Core.get_resource_access(page.resource_id, section.slug, user.id)

    section_resource = Sections.get_section_resource(section.id, page.resource_id)

    render(conn, "prologue.html", %{
      resource_access: resource_access,
      section_slug: section_slug,
      scripts: Activities.get_activity_scripts(),
      preview_mode: preview_mode,
      resource_attempts: resource_attempts,
      previous_page: previous,
      next_page: next,
      current_page: current,
      page_number: section_resource.numbering_index,
      title: context.page.title,
      allow_attempt?: allow_attempt?,
      message: message,
      resource_id: page.resource_id,
      slug: context.page.slug,
      max_attempts: page.max_attempts,
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

  # Advanced / adaptive lesson page rendering
  defp render_page(
         %PageContext{user: user, page: %{content: %{"advancedDelivery" => true}}} = context,
         conn,
         section_slug,
         preview_mode
       ) do
    section = conn.assigns.section

    layout =
      case Map.get(context.page.content, "displayApplicationChrome", true) do
        true -> "page.html"
        false -> "chromeless.html"
      end

    conn = put_root_layout(conn, {OliWeb.LayoutView, layout})

    resource_attempt = Enum.at(context.resource_attempts, 0)

    {:ok, {previous, next, current}, _} =
      PreviousNextIndex.retrieve(section, context.page.resource_id)

    previous_url = url_from_desc(conn, section_slug, previous)
    next_url = url_from_desc(conn, section_slug, next)

    activity_types = Activities.activities_for_section()

    section_resource = Sections.get_section_resource(section.id, context.page.resource_id)

    render(conn, "advanced_delivery.html", %{
      app_params: %{
        activityTypes: activity_types,
        resourceId: context.page.resource_id,
        sectionSlug: section_slug,
        userId: user.id,
        userName: user.name,
        pageTitle: context.page.title,
        pageSlug: context.page.slug,
        graded: context.page.graded,
        content: context.page.content,
        resourceAttemptState: resource_attempt.state,
        resourceAttemptGuid: resource_attempt.attempt_guid,
        activityGuidMapping: context.activities,
        previousPageURL: previous_url,
        nextPageURL: next_url,
        previewMode: preview_mode,
        isInstructor: true,
        reviewMode: context.review_mode,
        overviewURL: Routes.page_delivery_path(conn, :index, section.slug),
        finalizeGradedURL:
          Routes.page_lifecycle_path(
            conn,
            :transition
          ),
        screenIdleTimeOutInSeconds: Application.fetch_env!(:oli, :screen_idle_timeout_in_seconds)
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
      page_number: section_resource.numbering_level,
      user_id: user.id,
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

  defp render_page(%PageContext{progress_state: :error}, conn, _, _) do
    render(conn, "error.html")
  end

  # This case handles :in_progress and :revised progress states, in addition to
  # handling review mode
  defp render_page(%PageContext{user: user} = context, conn, section_slug, _) do
    section = conn.assigns.section

    # get_section_resource
    section_resource = Sections.get_section_resource(section.id, context.page.resource_id)

    preview_mode = Map.get(conn.assigns, :preview_mode, false)

    base_project_attributes = Sections.get_section_attributes(section)

    submitted_surveys =
      PageContent.survey_activities(context.page.content)
      |> Enum.reduce(%{}, fn {survey_id, activity_ids}, acc ->
        survey_state =
          Enum.all?(activity_ids, fn id ->
            context.activities[id].lifecycle_state === :submitted ||
              context.activities[id].lifecycle_state === :evaluated
          end)

        Map.put(acc, survey_id, survey_state)
      end)

    render_context = %Context{
      # Allow admin authors to review student work
      user:
        if is_nil(user) do
          conn.assigns.current_author
        else
          user
        end,
      section_slug: section_slug,
      resource_attempt: hd(context.resource_attempts),
      mode:
        if context.review_mode do
          :review
        else
          :delivery
        end,
      activity_map: context.activities,
      resource_summary_fn: &Resources.resource_summary(&1, section_slug, Resolver),
      alternatives_groups_fn: &Resources.alternatives_groups(&1, Resolver),
      alternatives_selector_fn: &Resources.Alternatives.select/2,
      extrinsic_read_section_fn: &Oli.Delivery.ExtrinsicState.read_section/3,
      bib_app_params: context.bib_revisions,
      submitted_surveys: submitted_surveys,
      historical_attempts: context.historical_attempts,
      learning_language: base_project_attributes.learning_language
    }

    this_attempt = context.resource_attempts |> hd
    html = Page.render(render_context, this_attempt.content, Page.Html)

    conn = put_root_layout(conn, {OliWeb.LayoutView, "page.html"})

    all_activities = Activities.list_activity_registrations()

    {:ok, {previous, next, current}, _} =
      PreviousNextIndex.retrieve(section, context.page.resource_id)

    render(
      conn,
      "page.html",
      %{
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
        current_page: current,
        page_number: section_resource.numbering_index,
        title: context.page.title,
        graded: context.page.graded,
        activity_count: map_size(context.activities),
        html: html,
        objectives: context.objectives,
        slug: context.page.slug,
        resource_attempt: hd(context.resource_attempts),
        attempt_guid: hd(context.resource_attempts).attempt_guid,
        latest_attempts: context.latest_attempts,
        section: section,
        children: context.page.children,
        page_link_url: &Routes.page_delivery_path(conn, :page, section_slug, &1),
        container_link_url: &Routes.page_delivery_path(conn, :container, section_slug, &1),
        revision: context.page,
        resource_slug: context.page.slug,
        bib_app_params: %{
          bibReferences: context.bib_revisions
        },
        collab_space_config: context.collab_space_config
      }
    )
  end

  # ----------------------------------------------------------
  # PREVIEW

  def index_preview(conn, %{"section_slug" => section_slug}) do
    section =
      conn.assigns.section
      |> Oli.Repo.preload([:base_project, :root_section_resource])

    render(conn, "index.html",
      title: section.title,
      description: section.description,
      section_slug: section_slug,
      hierarchy: build_hierarchy(section),
      display_curriculum_item_numbering: section.display_curriculum_item_numbering,
      preview_mode: true,
      page_link_url: &Routes.page_delivery_path(conn, :page_preview, section_slug, &1),
      container_link_url: &Routes.page_delivery_path(conn, :container_preview, section_slug, &1)
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
              ~s|<div class="text-center"><em>Instructor preview of adaptive activities is not supported</em></div>|

            {:ok, collab_space_config} =
              Collaboration.get_collab_space_config_for_page_in_section(
                revision.slug,
                section_slug
              )

            conn
            |> put_root_layout({OliWeb.LayoutView, "page.html"})
            |> render(
              "instructor_preview.html",
              %{
                summary: %{title: section.title},
                section_slug: section_slug,
                scripts: [],
                preview_mode: true,
                previous_page: previous,
                next_page: next,
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
                collab_space_config: collab_space_config
              }
            )

          user ->
            activity_types = Activities.activities_for_section()

            conn
            |> put_root_layout({OliWeb.LayoutView, "chromeless.html"})
            |> put_view(OliWeb.ResourceView)
            |> render("advanced_page_preview.html",
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

    activity_map =
      section_slug
      |> Resolver.from_resource_id(activity_ids)
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

    {:ok, collab_space_config} =
      Collaboration.get_collab_space_config_for_page_in_section(revision.slug, section_slug)

    section_resource = Sections.get_section_resource(section.id, revision.resource_id)

    conn
    |> put_root_layout({OliWeb.LayoutView, "page.html"})
    |> render(
      "instructor_preview.html",
      %{
        summary: %{title: section.title},
        section_slug: section_slug,
        scripts: Enum.map(all_activities, fn a -> a.authoring_script end),
        preview_mode: true,
        previous_page: previous,
        next_page: next,
        current_page: current,
        page_number: section_resource.numbering_level,
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
          bibReferences: bib_entrys
        },
        collab_space_config: collab_space_config
      }
    )
  end

  # ----------------------------------------------------------
  # END PREVIEW

  def start_attempt(conn, %{"section_slug" => section_slug, "revision_slug" => revision_slug}) do
    user = conn.assigns.current_user
    section = conn.assigns.section
    datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)

    activity_provider = &Oli.Delivery.ActivityProvider.provide/4

    if Sections.is_enrolled?(user.id, section_slug) do
      # We must check gating conditions here to account for gates that activated after
      # the prologue page was rendered, and for malicous/deliberate attempts to start an attempt via
      # hitting this endpoint.
      revision = Resolver.from_revision_slug(section_slug, revision_slug)

      case Oli.Delivery.Gating.blocked_by(section, user, revision.resource_id) do
        [] ->
          case PageLifecycle.start(
                 revision_slug,
                 section_slug,
                 datashop_session_id,
                 user.id,
                 activity_provider
               ) do
            {:ok, _} ->
              redirect(conn,
                to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug)
              )

            {:error, {:active_attempt_present}} ->
              redirect(conn,
                to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug)
              )

            {:error, {:no_more_attempts}} ->
              redirect(conn,
                to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug)
              )

            _ ->
              render(conn, "error.html")
          end

        _ ->
          # In the case where a gate exists we want to redirect to this page display, which will
          # then pick up the gate and show that feedback to the user
          redirect(conn, to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug))
      end
    else
      render(conn, "not_authorized.html")
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

    if Oli.Accounts.is_admin?(author) or
         PageLifecycle.can_access_attempt?(attempt_guid, user, section) do
      PageContext.create_for_review(section_slug, attempt_guid, user)
      |> render_page(conn, section_slug, false)
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

  def is_admin?(conn) do
    case conn.assigns[:current_author] do
      nil -> false
      author -> Oli.Accounts.is_admin?(author)
    end
  end

  defp simulate_node(%{
         "level" => level_str,
         "index" => index_str,
         "title" => title,
         "id" => id_str,
         "type" => type,
         "graded" => graded,
         "slug" => slug
       }) do
    %Oli.Delivery.Hierarchy.HierarchyNode{
      uuid: UUID.uuid4(),
      numbering: %Oli.Resources.Numbering{
        level: String.to_integer(level_str),
        index: String.to_integer(index_str)
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

  defp simulate_children_nodes(current, previous_next_index) do
    Enum.map(current["children"], fn s ->
      {:ok, {_, _, child}, _} =
        PreviousNextIndex.retrieve(previous_next_index, String.to_integer(s))

      child
    end)
    |> Enum.map(fn link_desc -> simulate_node(link_desc) end)
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

  defp build_helper(id, previous_next_index) do
    node = Map.get(previous_next_index, id)

    Map.put(
      node,
      "children",
      Enum.map(node["children"], fn id ->
        build_helper(id, previous_next_index)
      end)
    )
  end

  def build_hierarchy_from_top_level(resource_ids, previous_next_index) do
    Enum.map(resource_ids, fn resource_id -> build_helper(resource_id, previous_next_index) end)
  end

  defp build_hierarchy(section) do
    {:ok, _, previous_next_index} =
      PreviousNextIndex.retrieve(section, section.root_section_resource.resource_id)

    # Retrieve the top level resource ids, and convert them to strings
    resource_ids =
      Oli.Delivery.Sections.map_section_resource_children_to_resource_ids(
        section.root_section_resource
      )
      |> Enum.map(fn integer_id -> Integer.to_string(integer_id) end)

    %{
      id: "hierarchy_built_with_previous_next_index",
      # Recursively build the map based hierarchy from the structure defined by previous_next_index
      children: build_hierarchy_from_top_level(resource_ids, previous_next_index)
    }
  end
end
