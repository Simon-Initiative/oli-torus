defmodule OliWeb.StaticPageController do
  use OliWeb, :controller

  import Oli.Branding

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def unauthorized(conn, _params) do
    render(conn, "unauthorized.html")
  end

  def not_found(conn, _params) do
    render(conn, "not_found.html")
  end

  def keep_alive(conn, _params) do
    conn
    |> send_resp(200, "Ok")
  end

  def timezone(conn, %{"local_tz" => local_tz}) do
    conn
    |> put_session("local_tz", local_tz)
    |> send_resp(200, "Ok")
  end

  def site_webmanifest(conn, _params) do
    conn
    |> json(%{
      "name" => brand_name(),
      "short_name" => brand_name(),
      "icons" => [
        %{
          "src" => favicons("android-chrome-192x192.png"),
          "sizes" => "192x192",
          "type" => "image/png"
        },
        %{
          "src" => favicons("android-chrome-512x512.png"),
          "sizes" => "512x512",
          "type" => "image/png"
        }
      ],
      "theme_color" => "#ffffff",
      "background_color" => "#ffffff",
      "display" => "standalone"
    })
  end

  def set_session(conn, %{"dismissed_message" => message_id}) do
    dismissed_messages = get_session(conn, :dismissed_messages) || []
    id = String.to_integer(message_id)

    conn
    |> put_session(:dismissed_messages, [id | dismissed_messages])
    |> send_resp(200, "Ok")
  end
end
