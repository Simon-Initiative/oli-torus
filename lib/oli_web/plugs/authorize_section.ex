defmodule Oli.Plugs.AuthorizeSection do
  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Accounts
  alias Oli.Delivery.Sections

  def init(opts), do: opts

  def call(conn, _opts) do
    if Accounts.is_admin?(conn.assigns[:current_author]) or is_instructor?(conn) do
      conn
    else
      conn
      |> put_view(OliWeb.PageDeliveryView)
      |> put_status(403)
      |> render("not_authorized.html")
      |> halt()
    end
  end

  defp is_instructor?(conn),
    do: Sections.is_instructor?(conn.assigns[:current_user], conn.path_params["section_slug"])
end
