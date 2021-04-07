defmodule OliWeb.StaticPageController do
  use OliWeb, :controller

  def index(conn, _params) do
#    my_cookie = fetch_cookies(conn)
    IO.inspect "request cookies #{inspect(conn.req_cookies["_cky_opt_in"])}"
#    if(my_cookie === nil)do

#      put_resp_cookie(conn, "_consent_opt_in", Jason.encode!(%{awaiting_consent: true}))
      render(conn, "index.html")
#    end


  end

  def keep_alive(conn, _pararms) do
    conn
    |> send_resp(200, "Ok")
  end
end
