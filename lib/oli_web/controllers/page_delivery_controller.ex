defmodule OliWeb.PageDeliveryController do
  use OliWeb, :controller

  alias Oli.Delivery.Student.Summary
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.Sections
  alias Oli.Rendering.Context
  alias Oli.Rendering.Page
  alias Oli.Activities
  alias Oli.Delivery.Attempts
  alias Oli.Utils.Slug
  alias Oli.Utils.Time
  alias Oli.Delivery.Sections
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Resources.ResourceType
  alias Oli.Grading

  def index(conn, %{"section_slug" => section_slug}) do

    user = conn.assigns.current_user

    if Sections.is_enrolled?(user.id, section_slug) do

      case Summary.get_summary(section_slug, user) do
        {:ok, summary} -> render(conn, "index.html", section_slug: section_slug, summary: summary)
        {:error, _} -> render(conn, "error.html")
      end
    else
      render conn, "not_authorized.html"
    end

  end

  def page(conn, %{"section_slug" => section_slug, "revision_slug" => revision_slug}) do

    user = conn.assigns.current_user

    if Sections.is_enrolled?(user.id, section_slug) do

      PageContext.create_page_context(section_slug, revision_slug, user)
      |> render_page(conn, section_slug, user)

    else
      render conn, "not_authorized.html"
    end

  end

  defp render_page(%PageContext{summary: summary, progress_state: :not_started, page: page, resource_attempts: resource_attempts} = context,
    conn, section_slug, _) do

    # Only consider graded attempts
    resource_attempts = Enum.filter(resource_attempts, fn a -> a.revision.graded == true end)

    attempts_taken = length(resource_attempts)

    # The call to "max" here accounts for the possibility that a publication could reduce the
    # number of attempts after a student has exhausted all attempts
    attempts_remaining = max(page.max_attempts - attempts_taken, 0)

    allow_attempt? = attempts_remaining > 0 or page.max_attempts == 0
    message = if page.max_attempts == 0 do
      "You can take this assessment an unlimited number of times"
    else

      "You have #{attempts_remaining} attempt#{plural(attempts_remaining)} remaining out of #{page.max_attempts} total attempt#{plural(page.max_attempts)}."
    end

    conn = put_root_layout conn, {OliWeb.LayoutView, "page.html"}
    render(conn, "prologue.html", %{
      section_slug: section_slug,
      scripts: Activities.get_activity_scripts(),
      resource_attempts: Enum.filter(resource_attempts, fn r -> r.date_evaluated != nil end),
      summary: summary,
      previous_page: context.previous_page,
      next_page: context.next_page,
      title: context.page.title,
      allow_attempt?: allow_attempt?,
      message: message,
      resource_id: page.resource_id,
      slug: context.page.slug,
      max_attempts: page.max_attempts
    })
  end

  defp render_page(%PageContext{progress_state: :error}, conn, _, _) do
    render conn, "error.html"
  end

  # This case handles :in_progress and :revised progress states
  defp render_page(%PageContext{} = context, conn, section_slug, user) do

    render_context = %Context{user: user, section_slug: section_slug, progress_state: context.progress_state, activity_map: context.activities}
    page_model = Map.get(context.page.content, "model")
    html = Page.render(render_context, page_model, Page.Html)

    conn = put_root_layout conn, {OliWeb.LayoutView, "page.html"}
    render(conn,
      if ResourceType.get_type_by_id(context.page.resource_type_id) == "container" do
        "container.html" else "page.html"
      end, %{
      page: context.page,
      progress_state: context.progress_state,
      section_slug: section_slug,
      scripts: Activities.get_activity_scripts(),
      summary: context.summary,
      previous_page: context.previous_page,
      next_page: context.next_page,
      title: context.page.title,
      graded: context.page.graded,
      activity_count: map_size(context.activities),
      html: html,
      objectives: context.objectives,
      slug: context.page.slug,
      resource_attempt: hd(context.resource_attempts),
      attempt_guid: hd(context.resource_attempts).attempt_guid,
    })
  end

  def start_attempt(conn, %{"section_slug" => section_slug, "revision_slug" => revision_slug}) do

    user = conn.assigns.current_user

    activity_provider = &Oli.Delivery.ActivityProvider.provide/2

    if Sections.is_enrolled?(user.id, section_slug) do

      case Attempts.start_resource_attempt(revision_slug, section_slug, user.id, activity_provider) do
        {:ok, _} -> redirect(conn, to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug))
        {:error, {:active_attempt_present}} -> redirect(conn, to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug))
        {:error, {:no_more_attempts}} -> redirect(conn, to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug))
        _ -> render(conn, "error.html")
      end

    else
      render conn, "not_authorized.html"
    end

  end

  def review_attempt(conn, %{"section_slug" => section_slug, "revision_slug" => revision_slug, "attempt_guid" => attempt_guid}) do

    user = conn.assigns.current_user

    if Sections.is_enrolled?(user.id, section_slug) do

      case Attempts.review_resource_attempt(attempt_guid) do
        {:ok, _} -> PageContext.create_page_context(section_slug, revision_slug, attempt_guid, user)
                    |> render_page(conn, section_slug, user)
        _ -> render(conn, "error.html")
      end

    else
      render conn, "not_authorized.html"
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
    Oli.Grading.send_score_to_lms(section, user, resource_access, access_token_provider(section))
  end

  def finalize_attempt(conn, %{"section_slug" => section_slug, "revision_slug" => revision_slug, "attempt_guid" => attempt_guid}) do
    user = conn.assigns.current_user
    section = conn.assigns.section

    case Attempts.submit_graded_page(section_slug, attempt_guid) do
      {:ok, resource_access} ->

        grade_sync_result = send_one_grade(section, user, resource_access)
        after_finalized(conn, section_slug, revision_slug, attempt_guid, user, grade_sync_result)

      {:error, {:not_all_answered}} ->
        put_flash(conn, :error, "You have not answered all questions")
        |> redirect(to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug))
      {:error, {:already_submitted}} -> redirect(conn, to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug))
      {:error, {:active_attempt_present}} -> redirect(conn, to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug))
      {:error, {:no_more_attempts}} -> redirect(conn, to: Routes.page_delivery_path(conn, :page, section_slug, revision_slug))
      _ -> render(conn, "error.html")
    end

  end

  def after_finalized(conn, section_slug, revision_slug, attempt_guid, user, grade_sync_result) do
    context = PageContext.create_page_context(section_slug, revision_slug, user)

    message = if context.page.max_attempts == 0 do
      "You have an unlimited number of attempts remaining"
    else

      taken = length(context.resource_attempts)
      remaining = max(context.page.max_attempts - taken, 0)

      "You have taken #{taken} attempt#{plural(taken)} and have #{remaining} more attempt#{plural(remaining)} remaining"
    end

    grade_message = case grade_sync_result do
      {:ok, :synced} -> "Your grade has been updated in your LMS"
      {:error, _} -> "There was a problem updating your grade in your LMS"
      _ -> ""
    end


    conn = put_root_layout conn, {OliWeb.LayoutView, "page.html"}
    render(conn, "after_finalized.html",
      grade_message: grade_message,
      section_slug: section_slug,
      attempt_guid: attempt_guid,
      scripts: Activities.get_activity_scripts(),
      summary: context.summary,
      previous_page: context.previous_page,
      next_page: context.next_page,
      title: context.page.title,
      message: message,
      slug: context.page.slug)

  end

  defp plural(num) do
    if num == 1 do "" else "s" end
  end


  def export_gradebook(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user

    if ContextRoles.has_role?(user, section_slug, ContextRoles.get_role(:context_instructor)) do
      section = Sections.get_section_by(slug: section_slug)

      gradebook_csv = Grading.export_csv(section) |> Enum.join("")
      filename = "#{Slug.slugify(section.title)}-#{Timex.format!(Time.now(), "{YYYY}-{M}-{D}")}.csv"

      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
      |> send_resp(200, gradebook_csv)
    else
        render conn, "not_authorized.html"
    end
  end

end
