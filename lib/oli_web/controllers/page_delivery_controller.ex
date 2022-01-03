defmodule OliWeb.PageDeliveryController do
  use OliWeb, :controller

  import OliWeb.ViewHelpers,
    only: [
      is_section_instructor_or_admin?: 2
    ]

  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.Sections
  alias Oli.Rendering.Context
  alias Oli.Rendering.Page
  alias Oli.Activities
  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Utils.Slug
  alias Oli.Utils.Time
  alias Oli.Delivery.Sections
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Resources.ResourceType
  alias Oli.Grading
  alias Oli.PartComponents
  alias Oli.Rendering.Activity.ActivitySummary

  def index_preview(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user
    current_author = conn.assigns.current_author
    is_admin? = Oli.Accounts.is_admin?(current_author)

    # We only allow access to preview mode if the user is logged in as an author admin, or
    # is an instructor enrolled in the course section.  If the user is enrolled as a student,
    # we want to redirect out of this mode to render the page in regular delivery mode.

    if is_admin? or Sections.is_enrolled?(user.id, section_slug) do
      if is_admin? or Sections.has_instructor_role?(user, section_slug) do
        case Sections.get_section_by(slug: section_slug)
             |> Oli.Repo.preload([:base_project, :root_section_resource]) do
          nil ->
            render(conn, "error.html")

          section ->
            hierarchy = Oli.Publishing.DeliveryResolver.full_hierarchy(section.slug)

            render(conn, "index.html",
              title: section.title,
              description: section.description,
              section_slug: section_slug,
              hierarchy: hierarchy,
              preview_mode: true
            )
        end
      else
        # Any attempt by a student to enter preview mode is simply ignored and redirect back to
        # regular delivery mode
        redirect(conn, to: Routes.page_delivery_path(conn, :index, section_slug))
      end
    else
      render(conn, "not_authorized.html")
    end
  end

  def index(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user

    if Sections.is_enrolled?(user.id, section_slug) do
      case Sections.get_section_by(slug: section_slug)
           |> Oli.Repo.preload([:base_project, :root_section_resource]) do
        nil ->
          render(conn, "error.html")

        section ->
          hierarchy = Oli.Publishing.DeliveryResolver.full_hierarchy(section.slug)

          render(conn, "index.html",
            title: section.title,
            description: section.description,
            section_slug: section_slug,
            hierarchy: hierarchy,
            preview_mode: false
          )
      end
    else
      render(conn, "not_authorized.html")
    end
  end

  def updates(conn, %{"section_slug" => section_slug}) do
    current_user = conn.assigns.current_user
    current_author = conn.assigns.current_author

    if Oli.Accounts.is_admin?(current_author) or
         is_section_instructor_or_admin?(section_slug, current_user) do
      section = Sections.get_section_by(slug: section_slug)

      render(conn, "updates.html", section: section, title: "Manage Updates")
    else
      render(conn, "not_authorized.html")
    end
  end

  def page_preview(conn, %{
        "section_slug" => section_slug,
        "revision_slug" => revision_slug
      }) do
    user = conn.assigns.current_user
    current_author = conn.assigns.current_author
    is_admin? = Oli.Accounts.is_admin?(current_author)

    # We only allow access to preview mode if the user is logged in as an author admin, or
    # is an instructor enrolled in the course section.  If the user is enrolled as a student,
    # we want to redirect out of this mode to render the page in regular delivery mode.

    if is_admin? or Sections.is_enrolled?(user.id, section_slug) do
      if is_admin? or Sections.has_instructor_role?(user, section_slug) do
        revision = Oli.Publishing.DeliveryResolver.from_revision_slug(section_slug, revision_slug)
        render_preview_mode(conn, section_slug, revision)
      else
        # Any attempt by a student to enter preview mode is simply ignored and redirect back to
        # regular delivery mode
        redirect(conn, to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug))
      end
    else
      render(conn, "not_authorized.html")
    end
  end

  def page(conn, %{"section_slug" => section_slug, "revision_slug" => revision_slug}) do
    user = conn.assigns.current_user

    if Sections.is_enrolled?(user.id, section_slug) do
      PageContext.create_for_visit(section_slug, revision_slug, user)
      |> render_page(conn, section_slug, user, false)
    else
      render(conn, "not_authorized.html")
    end
  end

  defp render_preview_mode(
         conn,
         section_slug,
         %{content: %{"advancedDelivery" => true}} = revision
       ) do
    user = conn.assigns.current_user

    if Sections.is_instructor?(user, section_slug) do
      PageContext.create_for_visit(section_slug, revision.slug, user)
      |> render_page(conn, section_slug, user, true)
    else
      render(conn, "not_authorized.html")
    end
  end

  defp render_preview_mode(conn, section_slug, revision) do
    section = conn.assigns.section

    page_model = Map.get(revision.content, "model")

    type_by_id =
      Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn e, m -> Map.put(m, e.id, e) end)

    activity_ids =
      Oli.Resources.PageContent.flat_filter(revision.content, fn item ->
        item["type"] == "activity-reference"
      end)
      |> Enum.map(fn %{"activity_id" => id} -> id end)

    {:ok, {previous, next}} =
      Oli.Delivery.PreviousNextIndex.retrieve(section, revision.resource_id)

    activity_map =
      Oli.Publishing.DeliveryResolver.from_resource_id(section_slug, activity_ids)
      |> Enum.map(fn rev ->
        type = Map.get(type_by_id, rev.activity_type_id)

        %ActivitySummary{
          id: rev.resource_id,
          script: type.authoring_script,
          attempt_guid: nil,
          state: nil,
          model: Jason.encode!(rev.content) |> Oli.Delivery.Page.ActivityContext.encode(),
          delivery_element: type.delivery_element,
          authoring_element: type.authoring_element,
          graded: revision.graded
        }
      end)
      |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.id, r) end)

    all_activities = Activities.list_activity_registrations()

    render_context = %Context{
      user: conn.assigns.current_user,
      section_slug: section_slug,
      revision_slug: revision.slug,
      mode: :instructor_preview,
      activity_map: activity_map,
      activity_types_map: Enum.reduce(all_activities, %{}, fn a, m -> Map.put(m, a.id, a) end)
    }

    html = Page.render(render_context, page_model, Page.Html)

    conn = put_root_layout(conn, {OliWeb.LayoutView, "page.html"})

    render(
      conn,
      "instructor_preview.html",
      %{
        summary: %{title: section.title},
        section_slug: section_slug,
        scripts: Enum.map(all_activities, fn a -> a.authoring_script end),
        preview_mode: true,
        previous_page: previous,
        next_page: next,
        title: revision.title,
        html: html,
        objectives: [],
        section: section
      }
    )
  end

  defp render_page(
         %PageContext{
           progress_state: :not_started,
           page: page,
           resource_attempts: resource_attempts
         } = context,
         conn,
         section_slug,
         _,
         _
       ) do
    section = conn.assigns.section

    # Only consider graded attempts
    resource_attempts = Enum.filter(resource_attempts, fn a -> a.revision.graded == true end)

    attempts_taken = length(resource_attempts)

    # The call to "max" here accounts for the possibility that a publication could reduce the
    # number of attempts after a student has exhausted all attempts
    attempts_remaining = max(page.max_attempts - attempts_taken, 0)

    allow_attempt? = attempts_remaining > 0 or page.max_attempts == 0

    message =
      if page.max_attempts == 0 do
        "You can take this assessment an unlimited number of times"
      else
        "You have #{attempts_remaining} attempt#{plural(attempts_remaining)} remaining out of #{page.max_attempts} total attempt#{plural(page.max_attempts)}."
      end

    conn = put_root_layout(conn, {OliWeb.LayoutView, "page.html"})

    resource_attempts =
      Enum.filter(resource_attempts, fn r -> r.date_evaluated != nil end)
      |> Enum.sort(fn r1, r2 ->
        r1.date_evaluated <= r2.date_evaluated
      end)

    {:ok, {previous, next}} = Oli.Delivery.PreviousNextIndex.retrieve(section, page.resource_id)

    {:ok, summary} =
      Oli.Delivery.Student.Summary.get_summary(section_slug, conn.assigns.current_user)

    render(conn, "prologue.html", %{
      summary: summary,
      section_slug: section_slug,
      scripts: Activities.get_activity_scripts(),
      resource_attempts: resource_attempts,
      previous_page: previous,
      next_page: next,
      title: context.page.title,
      allow_attempt?: allow_attempt?,
      message: message,
      resource_id: page.resource_id,
      slug: context.page.slug,
      max_attempts: page.max_attempts,
      section: section
    })
  end

  defp render_page(
         %PageContext{page: %{content: %{"advancedDelivery" => true}}} = context,
         conn,
         section_slug,
         _,
         preview_mode
       ) do
    section = conn.assigns.section

    layout =
      case Map.get(context.page.content, "displayApplicationChrome", true) do
        true -> "page.html"
        false -> "chromeless.html"
      end

    conn = put_root_layout(conn, {OliWeb.LayoutView, layout})
    user = conn.assigns.current_user

    resource_attempt = Enum.at(context.resource_attempts, 0)
    {:ok, resource_attempt_state} = Jason.encode(resource_attempt.state)

    {:ok, activity_guid_mapping} =
      Oli.Delivery.Page.ActivityContext.to_thin_context_map(context.activities)
      |> Jason.encode()

    {:ok, {previous, next}} =
      Oli.Delivery.PreviousNextIndex.retrieve(section, context.page.resource_id)

    render(conn, "advanced_delivery.html", %{
      review_mode: context.review_mode,
      graded: context.page.graded,
      additional_stylesheets: Map.get(context.page.content, "additionalStylesheets", []),
      resource_attempt_guid: resource_attempt.attempt_guid,
      resource_attempt_state: resource_attempt_state,
      activity_guid_mapping: activity_guid_mapping,
      content: Jason.encode!(context.page.content),
      activity_types: Activities.activities_for_section(),
      scripts: Activities.get_activity_scripts(:delivery_script),
      part_scripts: PartComponents.get_part_component_scripts(:delivery_script),
      section_slug: section_slug,
      title: context.page.title,
      resource_id: context.page.resource_id,
      slug: context.page.slug,
      previous_page: previous,
      next_page: next,
      user_id: user.id,
      preview_mode: preview_mode,
      section: section
    })
  end

  defp render_page(%PageContext{progress_state: :error}, conn, _, _, _) do
    render(conn, "error.html")
  end

  # This case handles :in_progress and :revised progress states
  defp render_page(%PageContext{} = context, conn, section_slug, user, _) do
    section = conn.assigns.section

    render_context = %Context{
      user: user,
      section_slug: section_slug,
      mode:
        if context.review_mode do
          :review
        else
          :delivery
        end,
      activity_map: context.activities
    }

    this_attempt = context.resource_attempts |> hd
    page_model = Map.get(this_attempt.content, "model")
    html = Page.render(render_context, page_model, Page.Html)

    conn = put_root_layout(conn, {OliWeb.LayoutView, "page.html"})

    all_activities = Activities.list_activity_registrations()

    {:ok, {previous, next}} =
      Oli.Delivery.PreviousNextIndex.retrieve(section, context.page.resource_id)

    render(
      conn,
      if ResourceType.get_type_by_id(context.page.resource_type_id) == "container" do
        "container.html"
      else
        "page.html"
      end,
      %{
        page: context.page,
        review_mode: context.review_mode,
        progress_state: context.progress_state,
        section_slug: section_slug,
        scripts: Enum.map(all_activities, fn a -> a.delivery_script end),
        activity_type_slug_mapping:
          Enum.reduce(all_activities, %{}, fn a, m -> Map.put(m, a.id, a.slug) end),
        previous_page: previous,
        next_page: next,
        title: context.page.title,
        graded: context.page.graded,
        activity_count: map_size(context.activities),
        html: html,
        objectives: context.objectives,
        slug: context.page.slug,
        resource_attempt: hd(context.resource_attempts),
        attempt_guid: hd(context.resource_attempts).attempt_guid,
        latest_attempts: context.latest_attempts,
        section: section
      }
    )
  end

  def start_attempt(conn, %{"section_slug" => section_slug, "revision_slug" => revision_slug}) do
    user = conn.assigns.current_user

    activity_provider = &Oli.Delivery.ActivityProvider.provide/3

    if Sections.is_enrolled?(user.id, section_slug) do
      case PageLifecycle.start(
             revision_slug,
             section_slug,
             user.id,
             activity_provider
           ) do
        {:ok, _} ->
          redirect(conn, to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug))

        {:error, {:active_attempt_present}} ->
          redirect(conn, to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug))

        {:error, {:no_more_attempts}} ->
          redirect(conn, to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug))

        _ ->
          render(conn, "error.html")
      end
    else
      render(conn, "not_authorized.html")
    end
  end

  def review_attempt(conn, %{
        "section_slug" => section_slug,
        "attempt_guid" => attempt_guid
      }) do
    user = conn.assigns.current_user

    if Sections.is_enrolled?(user.id, section_slug) do
      PageContext.create_for_review(section_slug, attempt_guid, user)
      |> render_page(conn, section_slug, user, false)
    else
      render(conn, "not_authorized.html")
    end
  end

  defp host() do
    Application.get_env(:oli, OliWeb.Endpoint)
    |> Keyword.get(:url)
    |> Keyword.get(:host)
  end

  defp access_token_provider(section) do
    fn ->
      {_deployment, registration} = Sections.get_deployment_registration_from_section(section)
      Lti_1p3.Tool.AccessToken.fetch_access_token(registration, Oli.Grading.ags_scopes(), host())
    end
  end

  def send_one_grade(section, user, resource_access) do
    case Oli.Grading.send_score_to_lms(
           section,
           user,
           resource_access,
           access_token_provider(section)
         ) do
      {:error, e} ->
        Oli.Utils.Appsignal.capture_error(e)
        {:error, e}

      success ->
        success
    end
  end

  def finalize_attempt(conn, %{
        "section_slug" => section_slug,
        "revision_slug" => revision_slug,
        "attempt_guid" => attempt_guid
      }) do
    user = conn.assigns.current_user
    section = conn.assigns.section

    case PageLifecycle.finalize(section_slug, attempt_guid) do
      {:ok, resource_access} ->
        grade_sync_result = send_one_grade(section, user, resource_access)
        after_finalized(conn, section_slug, revision_slug, attempt_guid, user, grade_sync_result)

      {:error, {:already_submitted}} ->
        redirect(conn, to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug))

      {:error, {:active_attempt_present}} ->
        redirect(conn, to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug))

      {:error, {:no_more_attempts}} ->
        redirect(conn, to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug))

      _ ->
        render(conn, "error.html")
    end
  end

  def after_finalized(conn, section_slug, revision_slug, attempt_guid, user, grade_sync_result) do
    section = conn.assigns.section
    context = PageContext.create_for_visit(section_slug, revision_slug, user)

    message =
      if context.page.max_attempts == 0 do
        "You have an unlimited number of attempts remaining"
      else
        taken = length(context.resource_attempts)
        remaining = max(context.page.max_attempts - taken, 0)

        "You have taken #{taken} attempt#{plural(taken)} and have #{remaining} more attempt#{plural(remaining)} remaining"
      end

    grade_message =
      case grade_sync_result do
        {:ok, :synced} -> "Your grade has been updated in your LMS"
        {:error, _} -> "There was a problem updating your grade in your LMS"
        _ -> ""
      end

    conn = put_root_layout(conn, {OliWeb.LayoutView, "page.html"})

    {:ok, {previous, next}} =
      Oli.Delivery.PreviousNextIndex.retrieve(section, context.page.resource_id)

    render(conn, "after_finalized.html",
      grade_message: grade_message,
      section_slug: section_slug,
      attempt_guid: attempt_guid,
      scripts: Activities.get_activity_scripts(),
      previous_page: previous,
      next_page: next,
      title: context.page.title,
      message: message,
      slug: context.page.slug,
      section: section
    )
  end

  defp plural(num) do
    if num == 1 do
      ""
    else
      "s"
    end
  end

  def export_gradebook(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user

    if is_admin?(conn) or
         ContextRoles.has_role?(user, section_slug, ContextRoles.get_role(:context_instructor)) do
      section = Sections.get_section_by(slug: section_slug)

      gradebook_csv = Grading.export_csv(section) |> Enum.join("")

      filename =
        "#{Slug.slugify(section.title)}-#{Timex.format!(Time.now(), "{YYYY}-{M}-{D}")}.csv"

      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
      |> send_resp(200, gradebook_csv)
    else
      render(conn, "not_authorized.html")
    end
  end

  def is_admin?(conn) do
    case conn.assigns.current_author do
      nil -> false
      author -> Oli.Accounts.is_admin?(author)
    end
  end
end
