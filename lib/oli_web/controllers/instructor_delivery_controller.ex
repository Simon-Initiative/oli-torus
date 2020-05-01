defmodule OliWeb.InstructorDeliveryController do
  use OliWeb, :controller
  import OliWeb.ProjectPlugs
  alias Oli.Delivery.Instructor.OverviewDesc
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionRoles

  plug :ensure_context_id_matches

  def index(conn, %{"context_id" => context_id}) do

    user = conn.assigns.current_user

    if Sections.is_enrolled_as?(user.id, context_id, SectionRoles.get_by_type("instructor")) do
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

    if Sections.is_enrolled_as?(user.id, context_id, SectionRoles.get_by_type("instructor")) do
      context = PageContext.create_page_context(context_id, revision_slug)
      render(conn, "page.html", %{page: context.page, objectives: context.objectives})
    else
      render(conn, "not_authorized.html")
    end
  end



end
