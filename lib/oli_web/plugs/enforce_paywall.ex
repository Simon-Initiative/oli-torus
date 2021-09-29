defmodule Oli.Plugs.EnforcePaywall do
  import Plug.Conn
  import Phoenix.Controller

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Paywall

  def init(opts), do: opts

  def call(conn, _opts) do
    section = conn.assigns.section
    user = get_session(conn, :current_user)

    if Paywall.can_access?(user, section) do
      conn
    else
      conn
      |> redirect(to: Routes.payment_path(conn, :guard, section.slug))
      |> halt()
    end
  end
end
