defmodule OliWeb.PageDeliveryController do
  use OliWeb, :controller
  import OliWeb.ProjectPlugs
  alias Oli.Delivery.Student.OverviewDesc
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.Sections
  alias Oli.Rendering.Context
  alias Oli.Rendering.Page
  alias Oli.Activities
  alias Oli.Delivery.Attempts
  alias Oli.Grading
  alias Oli.Utils.Slug
  alias Oli.Utils.Time
  alias Oli.Delivery.Lti

  plug :ensure_context_id_matches

  def index(conn, %{"context_id" => context_id}) do

    user = conn.assigns.current_user

    if Sections.is_enrolled?(user.id, context_id) do

      case OverviewDesc.get_overview_desc(context_id, user) do
        {:ok, overview} -> render(conn, "index.html",
          context_id: context_id, pages: overview.pages, title: overview.title, description: overview.description)
        {:error, _} -> render(conn, "error.html")
      end
    else
      render(conn, "not_authorized.html")
    end

  end

  def page(conn, %{"context_id" => context_id, "revision_slug" => revision_slug}) do

    user = conn.assigns.current_user

    if Sections.is_enrolled?(user.id, context_id) do

      PageContext.create_page_context(context_id, revision_slug, user.id)
      |> render_page(conn, context_id, user)

    else
      render(conn, "not_authorized.html")
    end

  end


  defp render_page(%PageContext{progress_state: :not_started, page: page, resource_attempts: resource_attempts} = context,
    conn, context_id, _) do

    attempts_taken = length(resource_attempts)
    attempts_remaining = page.max_attempts - attempts_taken

    render(conn, "prologue.html", %{
      context_id: context_id,
      previous_page: context.previous_page,
      next_page: context.next_page,
      title: context.page.title,
      attempts_taken: attempts_taken,
      attempts_remaining: attempts_remaining,
      slug: context.page.slug
    })
  end

  defp render_page(%PageContext{progress_state: :error}, conn, _, _) do
    render(conn, "error.html")
  end

  # This case handles :in_progress and :revised progress states
  defp render_page(%PageContext{} = context, conn, context_id, user) do

    render_context = %Context{user: user, activity_map: context.activities}
    page_model = Map.get(context.page.content, "model")
    html = Page.render(render_context, page_model, Page.Html)

    render(conn, "page.html", %{
      context_id: context_id,
      scripts: get_scripts(),
      previous_page: context.previous_page,
      next_page: context.next_page,
      title: context.page.title,
      graded: context.page.graded,
      html: html,
      objectives: context.objectives,
      slug: context.page.slug,
      attempt_guid: hd(context.resource_attempts).attempt_guid
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
        {:error, {:not_found}} -> render(conn, "error.html")
      end

    else
      render(conn, "not_authorized.html")
    end

  end

  def finalize_attempt(conn, %{"revision_slug" => revision_slug, "attempt_guid" => attempt_guid}) do

    user = conn.assigns.current_user

    lti_params = Plug.Conn.get_session(conn, :lti_params)
    context_id = lti_params["context_id"]
    role = Oli.Delivery.Lti.parse_lti_role(lti_params["roles"])

    if Sections.is_enrolled?(user.id, context_id) do

      case Attempts.submit_graded_page(role, context_id, attempt_guid) do
        {:ok, _} -> after_finalized(conn, context_id, revision_slug, user.id)
        {:error, {:active_attempt_present}} -> redirect(conn, to: Routes.page_delivery_path(conn, :page, context_id, revision_slug))
        {:error, {:no_more_attempts}} -> redirect(conn, to: Routes.page_delivery_path(conn, :page, context_id, revision_slug))
        {:error, {:not_found}} -> render(conn, "error.html")
      end

    else
      render(conn, "not_authorized.html")
    end

  end

  def after_finalized(conn, context_id, revision_slug, user_id) do

    context = PageContext.create_page_context(context_id, revision_slug, user_id)

    attempts_taken = length(context.resource_attempts)
    attempts_remaining = context.page.max_attempts - attempts_taken

    render(conn, "after_finalized.html",
      context_id: context_id,
      previous_page: context.previous_page,
      next_page: context.next_page,
      title: context.page.title,
      attempts_taken: attempts_taken,
      attempts_remaining: attempts_remaining,
      slug: context.page.slug)

  end

  defp get_scripts() do
    Activities.list_activity_registrations()
      |> Enum.map(fn r -> Map.get(r, :authoring_script) end)
  end

  def export_gradebook(conn, %{"context_id" => context_id}) do
    user = conn.assigns.current_user
    case {Sections.is_enrolled?(user.id, context_id), Lti.parse_lti_role(user.roles)} do
      {true, role} when role == :administrator or role == :instructor ->
        section = Sections.get_section_by(context_id: context_id)

        gradebook_csv = Grading.export_csv(section) |> Enum.join("")
        filename = "#{Slug.slugify(section.title)}-#{Timex.format!(Time.now(), "{YYYY}-{M}-{D}")}.csv"

        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
        |> send_resp(200, gradebook_csv)

      _ ->
        render(conn, "not_authorized.html")
    end
  end

  def sync_gradebook(conn, %{"context_id" => context_id}) do
    user = conn.assigns.current_user
    case {Sections.is_enrolled?(user.id, context_id), Lti.parse_lti_role(user.roles)} do
      {true, role} when role == :administrator or role == :instructor ->
        section = Sections.get_section_by(context_id: context_id)

        # TODO case _ do handle error
        Grading.sync_grades(section)

        # conn
        # |> send_resp(200)

        redirect(conn, to: Routes.page_delivery_path(conn, :index, context_id))

      _ ->
        render(conn, "not_authorized.html")
    end
  end

end
