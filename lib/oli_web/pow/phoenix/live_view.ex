# TODO: Remove when upstream Pow can handle LiveView/socket auth
defmodule OliWeb.Pow.Phoenix.LiveView do
  @moduledoc """
  This module provides a way to authenticate LiveView routes with Pow.
  It is a temporary solution until Pow adds official support for LiveView.

  See https://github.com/pow-auth/pow/issues/706#issuecomment-1699285080 for more details.
  """
  use OliWeb, :verified_routes

  def on_mount(:delivery_protected, _params, session, socket) do
    socket =
      mount_current_user(
        socket,
        session,
        :current_user,
        OliWeb.Pow.PowHelpers.get_pow_config(:user)
      )

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be logged in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  defp mount_current_user(socket, session, assign_key, pow_config) do
    Phoenix.Component.assign_new(socket, assign_key, fn ->
      {_conn, user} =
        %Plug.Conn{
          private: %{
            plug_session_fetch: :done,
            plug_session: session,
            pow_config: pow_config
          },
          owner: self(),
          remote_ip: {0, 0, 0, 0}
        }
        |> Map.put(:secret_key_base, OliWeb.Endpoint.config(:secret_key_base))
        |> Pow.Plug.Session.fetch(pow_config)

      user
    end)
  end
end
