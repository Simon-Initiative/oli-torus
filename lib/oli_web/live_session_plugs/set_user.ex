defmodule OliWeb.LiveSessionPlugs.SetUser do
  import Phoenix.Component, only: [assign: 2]
  use Appsignal.Instrumentation.Decorators
  alias Oli.Accounts
  alias Oli.Accounts.{User, Author}
  alias Oli.AccountLookupCache

  @decorate transaction_event("SetUser")
  def on_mount(:with_preloads, _, session, socket) do
    {:cont,
     socket
     |> set_author(session)
     |> set_user(session, preload: [:platform_roles, :author])
     |> set_user_token
     |> update_ctx(session)}
  end

  @decorate transaction_event("SetUser")
  def on_mount(_default, _, session, socket) do
    {:cont,
     socket
     |> set_author(session)
     |> set_user(session)
     |> set_user_token
     |> update_ctx(session)}
  end

  def set_author(socket, %{"current_author_id" => current_author_id})
      when not is_nil(current_author_id) do
    case AccountLookupCache.get_author(current_author_id) do
      {:ok, current_author} ->
        case current_author do
          %Author{} ->
            socket
            |> assign(
              current_author: current_author,
              is_system_admin: Oli.Accounts.is_system_admin?(current_author),
              has_admin_role: Oli.Accounts.has_admin_role?(current_author)
            )

          _ ->
            assign(socket, is_system_admin: false, has_admin_role: false)
        end

      _ ->
        assign(socket, is_system_admin: false, has_admin_role: false)
    end
  end

  def set_author(socket, _session),
    do: assign(socket, is_system_admin: false, has_admin_role: false)

  def set_user(socket, session, opts \\ [])

  def set_user(socket, %{"masquerading_as" => user_id} = session, _opts) do
    with true <- socket.assigns.is_system_admin,
         user <- Accounts.get_user(user_id, preload: [:platform_roles, :author]) do
      socket
      |> assign(current_user: user)
      |> assign(masquerading_as: user)
      |> assign(datashop_session_id: nil)
      |> set_user_token
      |> update_ctx(session)
    else
      false ->
        socket
        |> Phoenix.LiveView.put_flash(
          :error,
          "You do not have permission to masquerade as another user."
        )

      _ ->
        socket
        |> Phoenix.LiveView.put_flash(:error, "User not found.")
    end
  end

  def set_user(socket, %{"current_user_id" => current_user_id} = session, opts)
      when not is_nil(current_user_id) do
    {:ok, current_user} =
      case opts[:preload] do
        nil ->
          AccountLookupCache.get_user(current_user_id)

        preload ->
          Accounts.get_user(current_user_id, preload: preload)
      end

    socket
    |> assign(
      current_user: current_user,
      datashop_session_id: session[:datashop_session_id] || UUID.uuid4()
    )
  end

  def set_user(socket, _session, _opts), do: socket

  defp set_user_token(socket) do
    case socket.assigns[:current_user] do
      %User{sub: sub} ->
        token = Phoenix.Token.sign(socket, "user socket", sub)
        assign(socket, user_token: token)

      _ ->
        socket
    end
  end

  defp update_ctx(socket, session) do
    socket
    |> assign(ctx: OliWeb.Common.SessionContext.init(socket, session))
  end
end
