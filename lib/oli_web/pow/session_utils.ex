defmodule OliWeb.Pow.SessionUtils do
  @moduledoc """
  A set of helper functions for managing user session data.

  This module provides utilities for handling various aspects of user sessions,
  such as signing out, clearing session data, and managing cached session information.
  It is designed to be flexible for future additions related to session management.
  """

  @shared_session_data_to_delete [:dismissed_messages]

  import OliWeb.Pow.PowHelpers
  import Plug.Conn, only: [delete_session: 2]

  alias Oli.AccountLookupCache

  @doc """
  Performs the sign-out process for a user.

  This function handles the logic required to sign out a user by:
    - Deleting session-related cache entries.
    - Removing user data from the session.
    - Clearing specific session keys like `completed_section_surveys` and `visited_sections`.

  It takes the connection (`conn`) and the user type (`type`) as arguments.

  ## Parameters
    - `conn`: The connection struct (`Plug.Conn`) representing the current user session.
    - `type`: A string representing the type of user session (e.g., "author", "user").

  ## Examples

      iex> perform_signout(conn, "user")
      %Plug.Conn{...}

  """
  @spec perform_signout(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def perform_signout(conn, type) do
    conn
    |> delete_cache_entry(type)
    |> delete_pow_user(String.to_atom(type))
    |> delete_session_data(type)
    |> delete_session("completed_section_surveys")
    |> delete_session("visited_sections")
  end

  defp delete_session_data(conn, type) do
    Enum.reduce(session_data_to_delete(type), conn, fn field, acc_conn ->
      delete_session(acc_conn, field)
    end)
  end

  defp session_data_to_delete(type),
    do: [String.to_atom("current_#{type}_id") | @shared_session_data_to_delete]

  defp delete_cache_entry(conn, type) do
    id =
      conn.assigns
      |> Map.get(String.to_existing_atom("current_#{type}"))
      |> Map.get(:id)

    AccountLookupCache.delete("#{type}_#{id}")

    conn
  end
end
