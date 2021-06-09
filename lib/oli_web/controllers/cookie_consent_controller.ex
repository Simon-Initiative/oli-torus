defmodule OliWeb.CookieConsentController do
  use OliWeb, :controller
  require Logger

  alias Oli.Consent

  def persist_cookies(conn, params) do
    cookies = Map.get(params, "cookies")
    current_user = Map.get(conn.assigns, :current_user)

    if current_user != nil do
      Enum.each(cookies, fn cookie ->
        %{"expiresIso" => expiresIso, "name" => name, "value" => value} = cookie

        {:ok, expiration} = Timex.parse(expiresIso, "{ISO:Extended:Z}")
        expiration = DateTime.truncate(expiration, :second)

        Consent.insert_cookie(name, value, expiration, current_user.id)
      end)

      json(conn, %{"result" => "success", "info" => "cookies persisted"})
    else
      json(conn, %{"result" => "success", "info" => "user not found"})
    end
  end

  def retrieve(conn, _params) do
    current_user = Map.get(conn.assigns, :current_user)

    if current_user != nil do
      cookies = Consent.retrieve_cookies(current_user.id)
      json(conn, cookies)
    else
      json(conn, %{"result" => "no-op"})
    end
  end

end
