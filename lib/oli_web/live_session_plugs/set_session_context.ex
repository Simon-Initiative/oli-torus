defmodule OliWeb.LiveSessionPlugs.SetSessionContext do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  alias OliWeb.Common.SessionContext

  def on_mount(:default, _params, session, socket) do
    {:cont, assign(socket, ctx: SessionContext.init(socket, session))}
  end
end
