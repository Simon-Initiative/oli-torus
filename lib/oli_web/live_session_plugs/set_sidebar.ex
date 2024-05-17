defmodule OliWeb.LiveSessionPlugs.SetSidebar do
  @moduledoc """
  This live session plug sets the hooks needed to handle the sidebar state (expanded or collapsed)
  by reading the `sidebar_expanded` parameter from the URL and setting it in the socket assigns.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      socket =
        socket
        |> attach_hook(:sidebar_hook, :handle_params, fn
          params, _uri, socket ->
            {:cont,
             assign(socket,
               sidebar_expanded: Oli.Utils.string_to_boolean(params["sidebar_expanded"] || "true")
             )}
        end)

      {:cont, socket}
    else
      {:cont,
       socket
       |> assign(sidebar_expanded: true)}
    end
  end
end
