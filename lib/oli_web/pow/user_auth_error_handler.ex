defmodule OliWeb.Pow.UserAuthErrorHandler do
  use OliWeb, :controller
  alias Plug.Conn

  @spec call(Conn.t(), atom()) :: Conn.t()
  def call(conn, :not_authenticated) do

    IO.inspect ":not_authenticated"

    conn
      |> put_view(OliWeb.DeliveryView)
      |> put_status(401)
      |> render("signin_required.html")
      |> halt()
  end

end
