defmodule Oli.Plugs.RequireSection do
  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Delivery.Sections

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.path_params do
      %{"section_slug" => section_slug} ->
        case Sections.get_section_by_slug(section_slug) do
          nil ->
            section_not_found(conn)

          section ->
            assign(conn, :section, section)
        end

      _ ->
        section_not_found(conn)
    end
  end

  defp section_not_found(conn) do
    conn
    |> put_view(OliWeb.DeliveryView)
    |> put_status(404)
    |> render("section_not_found.html")
    |> halt()
  end
end
