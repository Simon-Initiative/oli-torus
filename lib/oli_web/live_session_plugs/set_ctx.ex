defmodule OliWeb.LiveSessionPlugs.SetCtx do
  @moduledoc """
  This "live" plug is responsible for setting the session context in the socket assigns.
  It is generally used after OliWeb.LiveSessionPlugs.SetCurrentUser to guarantee there is already
  a current_user assigned to the socket.
  """

  import Phoenix.Component, only: [assign: 2]
  alias OliWeb.Common.SessionContext

  def on_mount(:default, _params, session, socket) do

    socket =
      assign(socket,
        ctx: SessionContext.init(socket, session, is_liveview: true)
      )

    {:cont, socket}
  end
end
