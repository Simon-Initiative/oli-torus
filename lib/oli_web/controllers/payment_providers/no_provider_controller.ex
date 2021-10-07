defmodule OliWeb.PaymentProviders.NoProviderController do
  use OliWeb, :controller

  def show(conn, _, _, _) do
    conn
    # This is necessary since this controller has been delegated by PaymentController
    |> Phoenix.Controller.put_view(OliWeb.PaymentProviders.NoProviderView)
    |> render("index.html")
  end
end
