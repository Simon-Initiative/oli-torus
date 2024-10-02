# TODO: Remove when upstream Pow can handle LiveView/socket auth
defmodule OliWeb.Pow.Phoenix.MountUser do
  @moduledoc """
  This module provides a way to authenticate LiveView mounts using Pow.
  It is a temporary solution until Pow adds official support for LiveView.

  See https://github.com/pow-auth/pow/issues/706#issuecomment-1699285080 for more details.
  """
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2, assign_new: 3]

  alias Oli.Accounts.{Author, User}

  def on_mount(:current_user, _params, session, socket) do
    socket =
      socket
      |> mount_pow_user(
        session,
        :current_user,
        OliWeb.Pow.PowHelpers.get_pow_config(:user)
      )
      |> maybe_mount_admin(session)
      |> assign(datashop_session_id: session[:datashop_session_id] || UUID.uuid4())
      |> set_user_token()

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be logged in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/session/new")

      {:halt, socket}
    end
  end

  def on_mount(:current_author, _params, session, socket) do
    socket =
      socket
      |> mount_pow_user(
        session,
        :current_author,
        OliWeb.Pow.PowHelpers.get_pow_config(:author)
      )
      |> maybe_mount_admin(session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be logged in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/authoring/session/new")

      {:halt, socket}
    end
  end

  defp mount_pow_user(socket, session, assign_key, pow_config) do
    assign_new(socket, assign_key, fn ->
      pow_fetch_user(session, pow_config)
    end)
  end

  defp maybe_mount_admin(socket, session) do
    pow_config = OliWeb.Pow.PowHelpers.get_pow_config(:author)

    with %Author{} = current_author <- pow_fetch_user(session, pow_config),
         true <- Oli.Accounts.has_admin_role?(current_author) do
      socket
      |> assign(is_system_admin: true)
      |> mount_pow_user(
        session,
        :current_author,
        OliWeb.Pow.PowHelpers.get_pow_config(:author)
      )
    else
      _ ->
        assign(socket, is_system_admin: false)
    end
  end

  defp pow_fetch_user(session, pow_config) do
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
  end

  defp set_user_token(socket) do
    case socket.assigns[:current_user] do
      %User{sub: sub} ->
        token = Phoenix.Token.sign(socket, "user socket", sub)
        assign(socket, user_token: token)

      _ ->
        socket
    end
  end
end
