defmodule Oli.Plugs.EnforcePaywall do
  import Plug.Conn
  import Phoenix.Controller

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Paywall.AccessSummary

  def init(opts), do: opts

  # show guard when paywall is required and user has not paid
  def call(conn, _opts) do
    section = conn.assigns.section
    user = conn.assigns.current_user

    summary = Paywall.summarize_access(user, section)

    case summary do
      %AccessSummary{available: true} ->
        conn
        |> Plug.Conn.assign(:paywall_summary, summary)

      %AccessSummary{available: false, reason: :not_enrolled} ->
        conn
        |> put_view(OliWeb.PageDeliveryView)
        |> render("not_authorized.html")
        |> halt()

      _ ->
        conn
        |> redirect(to: Routes.payment_path(conn, :guard, section.slug))
        |> halt()
    end
  end
end
