defmodule OliWeb.ActivityBankController do
  use OliWeb, :controller

  alias Oli.Accounts
  alias OliWeb.Common.Breadcrumb

  import OliWeb.ProjectPlugs

  plug :fetch_project when action in [:edit]
  plug :authorize_project when action in [:edit]

  @doc false
  def index(conn, %{
        "project_id" => project_slug
      }) do
    author = conn.assigns[:current_author]
    is_admin? = Accounts.is_admin?(author)

    # full title, short title, link, action descriptions

    render(conn, "index.html",
      active: :bank,
      breadcrumbs: [Breadcrumb.new(%{full_title: "Activity Bank"})],
      project_slug: project_slug,
      is_admin?: is_admin?,
      scripts: Oli.Activities.get_activity_scripts()
    )
  end
end
