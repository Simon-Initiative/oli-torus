defmodule Oli.Plugs.AuthorizeSectionPreview do
  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Accounts
  alias Oli.Delivery.Sections

  # We only allow access to preview mode if the user is logged in as an instructor
  # enrolled in the course section. If the user is enrolled as a student,
  # we redirect out of this mode to render the page in regular delivery mode.

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]
    author = conn.assigns[:current_author]
    section_slug = conn.path_params["section_slug"]

    cond do
      Sections.is_instructor?(user, section_slug) or Accounts.is_admin?(author) ->
        conn
        |> put_session(:preview_mode, true)

      not is_nil(user) and Sections.is_enrolled?(user.id, section_slug) ->
        redirect_path =
          conn
          |> current_path()
          |> String.replace(~r/\/preview\/?/, "/")

        conn
        |> redirect(to: redirect_path)
        |> halt()

      true ->
        conn
        |> put_view(OliWeb.PageDeliveryView)
        |> put_status(403)
        |> render("not_authorized.html")
        |> halt()
    end
  end
end
