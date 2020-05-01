defmodule OliWeb.StudentDeliveryController do
  use OliWeb, :controller
  import OliWeb.ProjectPlugs
  alias Oli.Delivery.Student.OverviewDesc
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionRoles
  alias Oli.Rendering.Context
  alias Oli.Rendering.Page
  alias Oli.Activities

  plug :ensure_context_id_matches

  def index(conn, %{"context_id" => context_id}) do

    user = conn.assigns.current_user

    if Sections.is_enrolled_as?(user.id, context_id, SectionRoles.get_by_type("student")) do

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

    if Sections.is_enrolled_as?(user.id, context_id, SectionRoles.get_by_type("student")) do

      context = PageContext.create_page_context(context_id, revision_slug)

      render_context = %Context{user: user, activity_map: context.activities}
      page_model = Map.get(context.page.content, "model")
      html = Page.render(render_context, page_model, Page.Html)

      render(conn, "page.html", %{scripts: get_scripts(), title: context.page.title, html: html, objectives: context.objectives})
    else
      render(conn, "not_authorized.html")
    end

  end

  defp get_scripts() do
    Activities.list_activity_registrations()
      |> Enum.map(fn r -> Map.get(r, :authoring_script) end)
  end


end
