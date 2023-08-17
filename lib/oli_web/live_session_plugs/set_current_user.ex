defmodule Oli.LiveSessionPlugs.SetCurrentUser do
  import Phoenix.Component, only: [assign: 2]

  alias Oli.Accounts
  alias Oli.Accounts.User
  alias Oli.AccountLookupCache

  def on_mount(:with_preloads, _, %{"current_user_id" => current_user_id}, socket) do
    current_user = Accounts.get_user!(current_user_id, preload: [:platform_roles, :author])
    {:cont, assign(socket, current_user: current_user)}
  end

  def on_mount(:default, _, %{"current_user_id" => current_user_id}, socket) do
    {:ok, current_user} = get_user(current_user_id)
    {:cont, assign(socket, current_user: current_user)}
  end

  def on_mount(_, _params, _session, socket) do
    {:cont, socket}
  end

  defp get_user(user_id) do
    case AccountLookupCache.get("user_#{user_id}") do
      {:ok, %User{}} = response ->
        response

      _ ->
        case Accounts.get_user_with_roles(user_id) do
          nil ->
            {:error, :not_found}

          user ->
            AccountLookupCache.put("user_#{user_id}", user)

            {:ok, user}
        end
    end
  end
end
