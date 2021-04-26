defmodule OliWeb.CookieConsentController do
  use OliWeb, :controller
  require Logger

  alias Oli.Repo
  alias Oli.Consent

  def persist_cookies(conn, params) do
    cookies = Map.get(params, "_json")
    current_user = Map.get(conn.assigns, :current_user)
    if current_user != nil do
      Enum.each(cookies, fn cookie ->
        %{"expires" => expires, "name" => name, "value" => value, "duration" => _duration} = cookie

        {:ok, expiration} = Timex.parse(expires, "{ISO:Extended:Z}")
        expiration = DateTime.truncate(expiration, :second)

        Consent.insert_cookie(name, value, expiration, current_user.id)
      end)
    end

    json(conn, %{"result" => "success", "info" => "cookie persist processed"})
  end

  def retrieve(conn, _params) do
    current_user = Map.get(conn.assigns, :current_user)
    if current_user != nil do
      cookies = Consent.retrieve_cookies(current_user.id)
      json(conn, cookies)
    else
      error(conn, 404, "No cookies")
    end
  end

  defp error(conn, code, reason) do
    conn
    |> Plug.Conn.send_resp(code, reason)
    |> Plug.Conn.halt()
  end

end
