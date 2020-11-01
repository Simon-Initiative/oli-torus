defmodule OliWeb.PageDeliveryController do
  use OliWeb, :controller
  import OliWeb.ProjectPlugs
  alias Oli.Delivery.Student.Summary
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.Sections
  alias Oli.Rendering.Context
  alias Oli.Rendering.Page
  alias Oli.Activities
  alias Oli.Delivery.Attempts
  alias Oli.Grading
  alias Oli.Utils.Slug
  alias Oli.Utils.Time
  alias Oli.Delivery.Sections
  alias Oli.Lti_1p3.ContextRoles
  alias Oli.Resources.ResourceType

  plug :ensure_context_id_matches when action not in [:link]

  def index(conn, %{"context_id" => context_id}) do

    user = conn.assigns.current_user

    if Sections.is_enrolled?(user.id, context_id) do

      case Summary.get_summary(context_id, user) do
        {:ok, summary} -> render(conn, "index.html", context_id: context_id, summary: summary)
        {:error, _} -> render(conn, "error.html")
      end
    else
      render conn, "not_authorized.html"
    end

  end

  def page(conn, %{"context_id" => context_id, "revision_slug" => revision_slug}) do

    user = conn.assigns.current_user

    if Sections.is_enrolled?(user.id, context_id) do

      PageContext.create_page_context(context_id, revision_slug, user)
      |> render_page(conn, context_id, user)

    else
      render conn, "not_authorized.html"
    end

  end

  # Handles in course page links, redirecting to
  # the appropriate section resource
  def link(conn, %{"revision_slug" => revision_slug}) do

    lti_params = conn.assigns.lti_params
    context_id = lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["id"]

    redirect(conn, to: Routes.page_delivery_path(conn, :page, context_id, revision_slug))
  end

  defp render_page(%PageContext{container_summary: container_summary, summary: summary, progress_state: :not_started, page: page, resource_attempts: resource_attempts} = context,
    conn, context_id, _) do

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
      context_id: context_id,
      scripts: Activities.get_activity_scripts(),
      summary: summary,
      container_summary: container_summary,
      previous_page: context.previous_page,
      next_page: context.next_page,
      title: context.page.title,
      allow_attempt?: allow_attempt?,
      message: message,
      slug: context.page.slug
    })
  end

  defp render_page(%PageContext{progress_state: :error}, conn, _, _) do
    render conn, "error.html"
  end

  # This case handles :in_progress and :revised progress states
  defp render_page(%PageContext{} = context, conn, context_id, user) do

    render_context = %Context{user: user, activity_map: context.activities}
    page_model = Map.get(context.page.content, "model")
    html = Page.render(render_context, page_model, Page.Html)

    conn = put_root_layout conn, {OliWeb.LayoutView, "page.html"}
    render(conn,
      if ResourceType.get_type_by_id(context.page.resource_type_id) == "container" do
        "container.html" else "page.html"
      end, %{
      page: context.page,
      context_id: context_id,
      scripts: Activities.get_activity_scripts(),
      container_summary: context.container_summary,
      summary: context.summary,
      previous_page: context.previous_page,
      next_page: context.next_page,
      title: context.page.title,
      graded: context.page.graded,
      activity_count: map_size(context.activities),
      html: html,
      objectives: context.objectives,
      slug: context.page.slug,
      attempt_guid: hd(context.resource_attempts).attempt_guid,
      numbering: context.numbering
    })
  end

  def start_attempt(conn, %{"context_id" => context_id, "revision_slug" => revision_slug}) do

    user = conn.assigns.current_user

    activity_provider = &Oli.Delivery.ActivityProvider.provide/2

    if Sections.is_enrolled?(user.id, context_id) do

      case Attempts.start_resource_attempt(revision_slug, context_id, user.id, activity_provider) do
        {:ok, _} -> redirect(conn, to: Routes.page_delivery_path(conn, :page, context_id, revision_slug))
        {:error, {:active_attempt_present}} -> redirect(conn, to: Routes.page_delivery_path(conn, :page, context_id, revision_slug))
        {:error, {:no_more_attempts}} -> redirect(conn, to: Routes.page_delivery_path(conn, :page, context_id, revision_slug))
        _ -> render(conn, "error.html")
      end

    else
      render conn, "not_authorized.html"
    end

  end

  def finalize_attempt(conn, %{"revision_slug" => revision_slug, "attempt_guid" => attempt_guid}) do

    user = conn.assigns.current_user

    lti_params = conn.assigns.lti_params
    context_id = lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["id"]

    if ContextRoles.has_role?(user, context_id, ContextRoles.get_role(:context_learner)) do

      case Attempts.submit_graded_page(context_id, attempt_guid) do
        {:ok, _} -> after_finalized(conn, context_id, revision_slug, user)
        {:error, {:not_all_answered}} ->
          put_flash(conn, :error, "You have not answered all questions")
          |> redirect(to: Routes.page_delivery_path(conn, :page, context_id, revision_slug))
        {:error, {:already_submitted}} -> redirect(conn, to: Routes.page_delivery_path(conn, :page, context_id, revision_slug))
        {:error, {:active_attempt_present}} -> redirect(conn, to: Routes.page_delivery_path(conn, :page, context_id, revision_slug))
        {:error, {:no_more_attempts}} -> redirect(conn, to: Routes.page_delivery_path(conn, :page, context_id, revision_slug))
        _ -> render(conn, "error.html")
      end

    else
      render conn, "not_authorized.html"
    end

  end

  def after_finalized(conn, context_id, revision_slug, user) do

    context = PageContext.create_page_context(context_id, revision_slug, user)

    message = if context.page.max_attempts == 0 do
      "You have an unlimited number of attempts remaining"
    else

      taken = length(context.resource_attempts)
      remaining = max(context.page.max_attempts - taken, 0)

      "You have taken #{taken} attempt#{plural(taken)} and have #{remaining} more attempt#{plural(remaining)} remaining"
    end

    conn = put_root_layout conn, {OliWeb.LayoutView, "page.html"}
    render(conn, "after_finalized.html",
      context_id: context_id,
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

  def export_gradebook(conn, %{"context_id" => context_id}) do
    user = conn.assigns.current_user

    if ContextRoles.has_role?(user, context_id, ContextRoles.get_role(:context_instructor)) do
      section = Sections.get_section_by(context_id: context_id)

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
