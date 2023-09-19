defmodule Oli.Plugs.RedirectIfIsAdmin do
  import Phoenix.Controller
  alias OliWeb.Router.Helpers, as: Routes

  def init(_params) do
  end

  def call(conn, _params) do
    %{current_author: current_author, current_user: current_user, section: section} = conn.assigns

    if not is_nil(current_author) and is_nil(current_user),
      do:
        redirect(conn,
          to: Routes.page_delivery_path(OliWeb.Endpoint, :index_preview, section.slug)
        ),
      else: conn
  end
end
