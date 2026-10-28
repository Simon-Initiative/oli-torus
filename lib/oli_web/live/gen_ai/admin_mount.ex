defmodule OliWeb.GenAI.AdminMount do
  @moduledoc "Rechecks GenAI administrative authorization when the LiveView socket mounts."
  import Phoenix.LiveView

  @doc "Only administrators may mount credential, model or transport administration."
  def on_mount(:default, _params, session, socket) do
    socket = OliWeb.AuthorAuth.mount_current_author(socket, session)

    case Oli.Accounts.is_admin?(socket.assigns.current_author) do
      true ->
        {:cont, socket}

      false ->
        {:halt, socket |> put_flash(:error, "Administrator access required") |> redirect(to: "/")}
    end
  end
end
