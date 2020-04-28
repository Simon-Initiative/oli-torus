defmodule OliWeb.InstructorDeliveryController do
  use OliWeb, :controller
  import OliWeb.ProjectPlugs
  alias Oli.Delivery.Instructor.OverviewDesc

  plug :ensure_context_id_matches

  def index(conn, %{"context_id" => context_id}) do

    user = conn.assigns.current_user

    IO.inspect OverviewDesc.get_overview_desc(context_id, user)

    case OverviewDesc.get_overview_desc(context_id, user) do
      {:ok, overview} -> render(conn, "index.html", context_id: context_id, pages: overview.pages, title: overview.title, description: overview.description)
      {:error, _} -> render(conn, "error.html")
    end
  end

  def page(_conn, %{"context_id" => _context_id, "revision_slug" => _revision_slug}) do

  end



end
