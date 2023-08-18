defmodule OliWeb.LiveSessionPlugs.SetCtx do
  import Phoenix.Component, only: [assign: 2]
  alias OliWeb.Common.SessionContext

  def on_mount(:default, _params, session, socket) do
    socket =
      assign(socket,
        ctx:
          SessionContext.init(socket, session,
            user: socket.assigns.current_user,
            is_liveview: true
          )
      )

    {:cont, socket}
  end
end
