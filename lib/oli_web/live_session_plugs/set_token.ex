defmodule OliWeb.LiveSessionPlugs.SetToken do
  @moduledoc """
  Set the client facing 'user_token' in the socket assigns.

  Not to be confused with the 'user_token' in the session which is used for server side
  authentication.
  """

  import Phoenix.Component, only: [assign: 2]

  alias Oli.Accounts.User

  def on_mount(:default, _params, _session, socket) do
    case {socket.assigns[:current_user], socket.assigns[:user_session]} do
      {%User{}, %{scope: scope}} when not is_nil(scope) ->
        {:cont, socket}

      {%User{sub: sub}, _} ->
        token = Phoenix.Token.sign(socket, "user socket", sub)

        {:cont, assign(socket, user_token: token)}

      _ ->
        {:cont, socket}
    end
  end
end
