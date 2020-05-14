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

  defp render_page(%PageContext{progress_state: :in_progress} = context, conn, context_id, user) do

    render_context = %Context{user: user, activity_map: context.activities}
    page_model = Map.get(context.page.content, "model")
    html = Page.render(render_context, page_model, Page.Html)

    render(conn, "page.html", %{
      context_id: context_id,
      scripts: get_scripts(),
      previous_page: context.previous_page,
      next_page: context.next_page,
      title: context.page.title,
      html: html,
      objectives: context.objectives
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

  defp get_scripts() do
    Activities.list_activity_registrations()
      |> Enum.map(fn r -> Map.get(r, :authoring_script) end)
  end


end
