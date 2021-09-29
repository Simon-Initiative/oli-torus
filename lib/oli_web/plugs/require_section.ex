defmodule Oli.Plugs.RequireSection do
  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Delivery.Sections

  def init(opts), do: opts

  def call(conn, _opts) do
    # Get the current_user and the current section from the session

    # If the current section is not paywalled, do nothing, we are done

    # If it is paywalled, fetch the enrollment record

    # Check for payment

    # Then check for grace period

    # If both conditions have not been met, then fail

    case conn.path_params do
      %{"section_slug" => section_slug} ->
        case Sections.get_section_by_slug(section_slug) do
          nil ->
            section_not_found(conn)

          section ->
            conn
            |> assign(:section, section)
            |> put_session(:section_slug, section_slug)
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
