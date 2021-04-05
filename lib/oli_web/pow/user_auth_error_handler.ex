defmodule OliWeb.Pow.UserAuthErrorHandler do
  use OliWeb, :controller
  alias Plug.Conn

  @spec call(Conn.t(), atom()) :: Conn.t()
  def call(conn, :not_authenticated) do
    conn
    |> put_view(OliWeb.DeliveryView)
    |> render("signin_required.html")
    |> halt()
  end
end
